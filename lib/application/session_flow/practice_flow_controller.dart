import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../domain/generation/session_generator.dart';
import '../../domain/model/session.dart';
import '../../domain/model/skill.dart';
import '../../domain/timeline/timeline_map.dart';
import '../../infrastructure/audio/audio_engine.dart';
import '../../infrastructure/audio/audio_recorder.dart';
import '../../infrastructure/audio/click_sounds.dart';
import '../../infrastructure/audio/session_audio_renderer.dart';
import '../../infrastructure/audio/wav_codec.dart';

/// The session flow state machine (design doc §7):
///
///   idle → previewing → countIn → practicing → finished
///
/// Owns the generated session and drives the audio engine. UI screens only
/// call the intents below and poll [poll] from their frame ticker; stage
/// transitions during playback (count-in ending, session finishing) are
/// derived from the master timeline, never from timers.
enum FlowStage { idle, previewing, countIn, practicing, finished }

class PracticeFlowController extends ChangeNotifier {
  static const sampleRate = 44100;

  final AudioEngine engine;
  final AudioRecorder recorder;
  final ClickSounds sounds;
  final Random _rng;

  PracticeFlowController({
    required this.engine,
    required this.recorder,
    required this.sounds,
    int? seed,
  }) : _rng = Random(seed);

  FlowStage _stage = FlowStage.idle;
  FlowStage get stage => _stage;

  Session? _session;
  Session? get session => _session;

  TimelineMap? _map;
  TimelineMap? get map => _map;

  int _bpmMin = 40;
  int _bpmMax = 240;
  int get bpmMin => _bpmMin;
  int get bpmMax => _bpmMax;

  /// Preview option (spec §5). Practice playback never includes them.
  bool referenceHits = true;

  /// Premium-only Practice option (2026-07-30): when the timeline runs out
  /// during [FlowStage.practicing], restart from a fresh count-in instead
  /// of finishing — same restart path [startPractice] always uses, so the
  /// count-in the user hears at the very start of any practice run also
  /// plays again before every loop rep, exactly the cue that makes the
  /// brief reload gap feel like a normal restart rather than a stutter.
  /// Never applies to Record mode — a recorded take must have one definite
  /// end to score. Each completed loop rep still fires
  /// [onSessionCompleted] (user decision, 2026-07-30) — looping is a
  /// legitimate way to rack up genuine reps of a lesson, so it counts
  /// toward the Home screen's rep-count tier badges exactly like any other
  /// completed session would.
  bool loopPractice = false;
  bool _restartingLoop = false;

  bool _isRecording = false;
  bool get isRecording => _isRecording;

  String? _recordingPath;
  String? get recordingPath => _recordingPath;

  /// Fired every time a practice session completes (spec §4: all 16
  /// exercises played through) — once per pass, so a looped practice run
  /// ([loopPractice]) fires this once per rep, not just once for the whole
  /// run. The UI layer wires this to persistence (Home screen progress,
  /// design doc §14) — kept as a callback so the state machine itself stays
  /// storage-agnostic.
  void Function(Session session)? onSessionCompleted;

  /// Only initializes [engine] here — [recorder] is lazily initialized on
  /// the first actual [startRecording] call instead (2026-07-30). Both
  /// flutter_soloud and flutter_recorder are built on the same miniaudio
  /// native library; eagerly initializing both at app startup crashed real
  /// iOS hardware ("RecorderInitializeFailedException: ... already inited?
  /// on the C++ side") even though it never reproduced on Windows. Record
  /// mode is also Premium-only, so most sessions never need the recorder at
  /// all.
  Future<void> init() async {
    await engine.init();
  }

  /// Generates a fresh session from the skill/level. Resets the flow.
  void generateSession({
    required Skill skill,
    required int level,
    int? bpm,
  }) {
    _bpmMin = skill.bpmMin;
    _bpmMax = skill.bpmMax;
    _session = SessionGenerator(seed: _rng.nextInt(1 << 31))
        .generate(skill: skill, levelNumber: level, bpm: bpm);
    _map = TimelineMap.forSession(_session!, sampleRate: sampleRate);
    _recordingPath = null;
    _setStage(FlowStage.idle);
  }

  /// Changing BPM re-renders audio only; the session is never regenerated
  /// (spec §4). Clamped to the source skill's bpm range.
  void changeBpm(int bpm) {
    final s = _session;
    if (s == null) return;
    _session = s.withBpm(bpm.clamp(_bpmMin, _bpmMax));
    _map = TimelineMap.forSession(_session!, sampleRate: sampleRate);
    notifyListeners();
  }

  /// Preview playback: metronome + optional reference hits (spec §5).
  Future<void> startPreview() async {
    await _load(includeReferenceHits: referenceHits);
    await engine.play();
    _setStage(FlowStage.previewing);
  }

  /// Practice playback: metronome + per-note reference pad hits (spec §8's
  /// unrecorded "Practice" mode — audible reference is fine because nothing
  /// is captured). Starts with the count-in measure; [poll] flips
  /// countIn → practicing when the timeline crosses into exercise 0.
  ///
  /// M3's "Record" mode must call this with reference hits OFF instead:
  /// once a microphone is capturing, an audible reference risks bleeding
  /// into the recording and corrupting M4's onset detection.
  Future<void> startPractice() async {
    _recordingPath = null;
    await _load(includeReferenceHits: true);
    await engine.play();
    _setStage(FlowStage.countIn);
  }

  /// Record mode (design doc §9's M3): identical timeline to practice, but
  /// reference hits are always off and the microphone captures the take to
  /// [filePath] for later playback (and, in M4, onset scoring).
  Future<void> startRecording({required String filePath}) async {
    await recorder.init();
    await _load(includeReferenceHits: false);
    _recordingPath = filePath;
    _isRecording = true;
    // Starts capture first so the mic is already running when the count-in
    // click fires — recorded takes should never miss their own first beat.
    recorder.startRecording(filePath);
    await engine.play();
    _setStage(FlowStage.countIn);
  }

  Future<void> stop() async {
    await engine.stop();
    _stopRecordingIfActive();
    _setStage(FlowStage.idle);
  }

  void _stopRecordingIfActive() {
    if (_isRecording) {
      recorder.stopRecording();
      _isRecording = false;
    }
  }

  /// Called from the UI frame ticker. Returns the current musical position
  /// and advances the stage machine when the timeline crosses a boundary.
  TimelinePosition? poll() {
    final map = _map;
    if (map == null || _stage == FlowStage.idle || _stage == FlowStage.finished) {
      return null;
    }

    final samples =
        engine.position.inMicroseconds * sampleRate ~/ 1000000;
    final pos = map.positionAt(samples);

    if (!engine.isPlaying) {
      // Stream ran out: preview returns to idle, practice completes.
      final wasPracticing = _stage == FlowStage.practicing;
      final wasRecording = _isRecording;
      _stopRecordingIfActive();
      if (wasPracticing && !wasRecording && loopPractice && !_restartingLoop) {
        _restartingLoop = true;
        onSessionCompleted?.call(_session!);
        // Fire-and-forget: poll() can't await. Stage is left as-is (still
        // "practicing") for the brief reload gap; _restartingLoop guards
        // against poll() re-entering this branch on every tick until
        // startPractice() flips the stage back to countIn itself.
        unawaited(startPractice().then((_) => _restartingLoop = false));
        return pos;
      }
      _setStage(_stage == FlowStage.previewing
          ? FlowStage.idle
          : FlowStage.finished);
      if (wasPracticing) onSessionCompleted?.call(_session!);
      return pos;
    }

    if (_stage == FlowStage.countIn && !pos.isCountIn) {
      _setStage(FlowStage.practicing);
    }
    return pos;
  }

  Future<void> _load({required bool includeReferenceHits}) async {
    final session = _session;
    final map = _map;
    if (session == null || map == null) {
      throw StateError('No session generated');
    }
    await engine.stop();
    final pcm = SessionAudioRenderer(sounds: sounds).render(
      map: map,
      exercises: session.exercises,
      includeReferenceHits: includeReferenceHits,
    );
    await engine.loadSession(
        Uint8List.fromList(pcm16ToWav(pcm, sampleRate: sampleRate)));
  }

  void _setStage(FlowStage s) {
    if (_stage == s) return;
    _stage = s;
    notifyListeners();
  }

  @override
  void dispose() {
    engine.dispose();
    recorder.dispose();
    super.dispose();
  }
}
