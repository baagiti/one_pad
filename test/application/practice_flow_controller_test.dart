import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_pad/application/session_flow/practice_flow_controller.dart';
import 'package:one_pad/domain/content/content_loader.dart';
import 'package:one_pad/domain/model/skill.dart';
import 'package:one_pad/infrastructure/audio/audio_engine.dart';
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

void main() {
  late Skill skill;
  late FakeAudioEngine engine;
  late PracticeFlowController controller;

  setUpAll(() {
    skill = ContentLoader().loadSkill(
        File('content/skills/quarter_note_pulse.json').readAsStringSync());
  });

  setUp(() {
    engine = FakeAudioEngine();
    controller = PracticeFlowController(
      engine: engine,
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
}
