import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'application/session_flow/practice_flow_controller.dart';
import 'domain/content/content_loader.dart';
import 'domain/model/skill.dart';
import 'infrastructure/audio/audio_engine.dart';
import 'infrastructure/audio/audio_recorder.dart';
import 'infrastructure/audio/click_sounds.dart';
import 'infrastructure/storage/app_database.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/theme/app_theme.dart';

void main() {
  runApp(const OnePadApp());
}

class OnePadApp extends StatefulWidget {
  const OnePadApp({super.key});

  @override
  State<OnePadApp> createState() => _OnePadAppState();
}

class _OnePadAppState extends State<OnePadApp> {
  static const _skillAssets = [
    'content/skills/quarter_note_pulse.json',
    'content/skills/quarter_note_rests.json',
    'content/skills/eighth_notes.json',
    'content/skills/offbeat_eighth_notes.json',
    'content/skills/dotted_quarter_eighth.json',
    'content/skills/paradiddle_eighth_notes.json',
    'content/skills/sixteenth_notes.json',
    'content/skills/paradiddle_sixteenth_notes.json',
    'content/skills/thirty_second_notes.json',
    'content/skills/syncopation_ties.json',
    'content/skills/alternate_meters_34.json',
    'content/skills/alternate_meters_68.json',
    'content/skills/odd_meters_54.json',
    'content/skills/odd_meters_78.json',
    'content/skills/triplets.json',
    'content/skills/roll_rudiments.json',
    'content/skills/performance_foundations.json',
    'content/skills/performance_syncopated_feel.json',
    'content/skills/performance_fast_subdivision.json',
    'content/skills/performance_rudiment_workout.json',
  ];

  late final PracticeFlowController _controller;
  late final AppDatabase _db;
  late final Future<List<Skill>> _bootstrap;

  @override
  void initState() {
    super.initState();
    _controller = PracticeFlowController(
      engine: SoloudAudioEngine(),
      recorder: FlutterRecorderAudioRecorder(),
      sounds: ClickSounds(sampleRate: PracticeFlowController.sampleRate),
    );
    _db = AppDatabase();
    _controller.onSessionCompleted = (session) => _db.recordCompleted(
          skillId: session.skillId,
          level: session.level,
          bpm: session.bpm,
        );
    _bootstrap = _init();
  }

  Future<List<Skill>> _init() async {
    await _controller.init();
    final loader = ContentLoader();
    final skills = <Skill>[];
    for (final asset in _skillAssets) {
      final jsonString = await rootBundle.loadString(asset);
      skills.add(loader.loadSkill(jsonString));
    }
    return skills;
  }

  @override
  void dispose() {
    _controller.dispose();
    _db.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stick Trainer',
      theme: AppTheme.light(),
      home: FutureBuilder<List<Skill>>(
        future: _bootstrap,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Scaffold(
              body: Center(child: Text('Startup error: ${snapshot.error}')),
            );
          }
          if (!snapshot.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return HomeScreen(
            controller: _controller,
            skills: snapshot.data!,
            db: _db,
          );
        },
      ),
    );
  }
}
