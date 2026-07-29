import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_pad/application/session_flow/practice_flow_controller.dart';
import 'package:one_pad/domain/content/content_loader.dart';
import 'package:one_pad/domain/model/skill.dart';
import 'package:one_pad/infrastructure/audio/audio_engine.dart';
import 'package:one_pad/infrastructure/audio/audio_recorder.dart';
import 'package:one_pad/infrastructure/audio/click_sounds.dart';

class FakeAudioEngine implements AudioEngine {
  bool initialized = false;
  bool playing = false;
  int loadCount = 0;
  Uint8List? lastWav;
  Duration fakePosition = Duration.zero;

  @override
  Future<void> init() async => initialized = true;

  @override
  Future<void> loadSession(Uint8List wavBytes) async {
    loadCount++;
    lastWav = wavBytes;
  }

  @override
  Future<void> play() async => playing = true;

  @override
  Future<void> stop() async => playing = false;

  @override
  Duration get position => fakePosition;

  @override
  bool get isPlaying => playing;

  @override
  Future<void> dispose() async {}
}

class FakeAudioRecorder implements AudioRecorder {
  bool initialized = false;
  bool recording = false;
  bool disposed = false;
  List<String> startedPaths = [];
  int stopCount = 0;

  @override
  Future<void> init() async => initialized = true;

  @override
  void startRecording(String filePath) {
    recording = true;
    startedPaths.add(filePath);
  }

  @override
  void stopRecording() {
    recording = false;
    stopCount++;
  }

  @override
  void dispose() => disposed = true;
}

void main() {
  late Skill skill;
  late FakeAudioEngine engine;
  late FakeAudioRecorder recorder;
  late PracticeFlowController controller;

  setUpAll(() {
    skill = ContentLoader().loadSkill(
        File('content/skills/quarter_note_pulse.json').readAsStringSync());
  });

  setUp(() {
    engine = FakeAudioEngine();
    recorder = FakeAudioRecorder();
    controller = PracticeFlowController(
      engine: engine,
      recorder: recorder,
      sounds: ClickSounds(sampleRate: PracticeFlowController.sampleRate),
      seed: 7,
    );
    controller.generateSession(skill: skill, level: 1);
  });

  Duration afterCountIn() {
    final samples = controller.map!.countInSamples + 100;
    return Duration(
        microseconds:
            samples * 1000000 ~/ PracticeFlowController.sampleRate);
  }

  test('generateSession resets to idle with a 16-exercise session', () {
    expect(controller.stage, FlowStage.idle);
    expect(controller.session!.exercises, hasLength(16));
    expect(controller.map, isNotNull);
  });

  test('preview: renders with reference-hit option, plays, ends back at idle',
      () async {
    controller.referenceHits = true;
    await controller.startPreview();
    expect(controller.stage, FlowStage.previewing);
    expect(engine.playing, isTrue);
    expect(engine.loadCount, 1);

    // stream ends
    engine.playing = false;
    controller.poll();
    expect(controller.stage, FlowStage.idle);
  });

  test('practice: countIn until the timeline crosses into exercise 0',
      () async {
    await controller.startPractice();
    expect(controller.stage, FlowStage.countIn);

    engine.fakePosition = Duration.zero;
    controller.poll();
    expect(controller.stage, FlowStage.countIn);

    engine.fakePosition = afterCountIn();
    final pos = controller.poll();
    expect(controller.stage, FlowStage.practicing);
    expect(pos!.exercise, 0);
  });

  test('practice completion flips to finished', () async {
    await controller.startPractice();
    engine.fakePosition = afterCountIn();
    controller.poll();
    engine.playing = false;
    controller.poll();
    expect(controller.stage, FlowStage.finished);
  });

  test('practice completion fires onSessionCompleted exactly once', () async {
    var callCount = 0;
    controller.onSessionCompleted = (_) => callCount++;

    await controller.startPractice();
    engine.fakePosition = afterCountIn();
    controller.poll();
    engine.playing = false;
    controller.poll();
    controller.poll(); // idempotent: already finished, no further callback
    expect(callCount, 1);
  });

  test('preview completion does NOT fire onSessionCompleted', () async {
    var callCount = 0;
    controller.onSessionCompleted = (_) => callCount++;

    await controller.startPreview();
    engine.playing = false;
    controller.poll();
    expect(controller.stage, FlowStage.idle);
    expect(callCount, 0);
  });

  test('changeBpm clamps to the skill bpm range', () async {
    controller.changeBpm(skill.bpmMax + 50);
    expect(controller.session!.bpm, skill.bpmMax);

    controller.changeBpm(skill.bpmMin - 50);
    expect(controller.session!.bpm, skill.bpmMin);
  });

  test('changeBpm keeps the session content, re-maps the timeline (spec §4)',
      () async {
    final before =
        controller.session!.exercises.map((e) => e.templateId).toList();
    final mapBefore = controller.map!.samplesPerBeat;

    controller.changeBpm(100);

    expect(controller.session!.bpm, 100);
    expect(controller.session!.exercises.map((e) => e.templateId), before);
    expect(controller.map!.samplesPerBeat, isNot(mapBefore));
  });

  test('stop returns to idle from any playback stage', () async {
    await controller.startPractice();
    await controller.stop();
    expect(controller.stage, FlowStage.idle);
    expect(engine.playing, isFalse);
  });

  test('startRecording forces reference hits off and starts the mic',
      () async {
    controller.referenceHits = true;
    await controller.startRecording(filePath: 'take.wav');

    expect(controller.stage, FlowStage.countIn);
    expect(controller.isRecording, isTrue);
    expect(controller.recordingPath, 'take.wav');
    expect(recorder.recording, isTrue);
    expect(recorder.startedPaths, ['take.wav']);
  });

  test('recording stops the mic exactly once when the session finishes',
      () async {
    await controller.startRecording(filePath: 'take.wav');
    engine.fakePosition = afterCountIn();
    controller.poll();
    engine.playing = false;
    controller.poll();

    expect(controller.stage, FlowStage.finished);
    expect(controller.isRecording, isFalse);
    expect(recorder.stopCount, 1);
    // recordingPath survives into the Results screen.
    expect(controller.recordingPath, 'take.wav');
  });

  test('aborting a recording via stop() also stops the mic', () async {
    await controller.startRecording(filePath: 'take.wav');
    await controller.stop();

    expect(controller.stage, FlowStage.idle);
    expect(controller.isRecording, isFalse);
    expect(recorder.stopCount, 1);
  });

  test('a plain practice run never touches the recorder and clears any '
      'stale recordingPath', () async {
    await controller.startRecording(filePath: 'take.wav');
    engine.fakePosition = afterCountIn();
    controller.poll();
    engine.playing = false;
    controller.poll();
    expect(controller.recordingPath, isNotNull);

    await controller.startPractice();

    expect(controller.isRecording, isFalse);
    expect(controller.recordingPath, isNull);
    expect(recorder.stopCount, 1); // unchanged: no new recorder activity
  });

  test('generateSession resets recordingPath', () async {
    await controller.startRecording(filePath: 'take.wav');
    engine.fakePosition = afterCountIn();
    controller.poll();
    engine.playing = false;
    controller.poll();
    expect(controller.recordingPath, isNotNull);

    controller.generateSession(skill: skill, level: 1);
    expect(controller.recordingPath, isNull);
  });
}
