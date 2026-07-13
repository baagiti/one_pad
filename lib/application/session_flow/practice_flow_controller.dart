import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../domain/generation/session_generator.dart';
import '../../domain/model/session.dart';
import '../../domain/model/skill.dart';
import '../../domain/timeline/timeline_map.dart';
import '../../infrastructure/audio/audio_engine.dart';
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
  final ClickSounds sounds;
  final Random _rng;

  PracticeFlowController({
    required this.engine,
    required this.sounds,
    int? seed,
  }) : _rng = Random(seed);

  FlowStage _stage = FlowStage.idle;
  FlowStage get stage => _stage;

  Session? _session;
  Session? get session => _session;

  TimelineMap? _map;
  TimelineMap? get map => _map;

  /// Preview option (spec §5). Practice playback never includes them.
  bool referenceHits = true;

  Future<void> init() => engine.init();

  /// Generates a fresh session from the skill/level. Resets the flow.
  void generateSession({
    required Skill skill,
    required int level,
    int? bpm,
  }) {
    _session = SessionGenerator(seed: _rng.nextInt(1 << 31))
        .generate(skill: skill, levelNumber: level, bpm: bpm);
    _map = TimelineMap.forSession(_session!, sampleRate: sampleRate);
    _setStage(FlowStage.idle);
  }

  /// Changing BPM re-renders audio only; the session is never regenerated
  /// (spec §4).
  void changeBpm(int bpm) {
    final s = _session;
    if (s == null) return;
    _session = s.withBpm(bpm);
    _map = TimelineMap.forSession(_session!, sampleRate: sampleRate);
    notifyListeners();
  }

  /// Preview playback: metronome + optional reference hits (spec §5).
  Future<void> startPreview() async {
    await _load(includeReferenceHits: referenceHits);
    await engine.play();
    _setStage(FlowStage.previewing);
  }

  /// Practice playback: metronome only. Starts with the count-in measure;
  /// [poll] flips countIn → practicing when the timeline crosses into
  /// exercise 0.
  Future<void> startPractice() async {
    await _load(includeReferenceHits: false);
    await engine.play();
    _setStage(FlowStage.countIn);
  }

  Future<void> stop() async {
    await engine.stop();
    _setStage(FlowStage.idle);
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
      _setStage(_stage == FlowStage.previewing
          ? FlowStage.idle
          : FlowStage.finished);
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
    super.dispose();
  }
}
