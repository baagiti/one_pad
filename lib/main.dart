import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'application/session_flow/practice_flow_controller.dart';
import 'domain/content/content_loader.dart';
import 'domain/model/skill.dart';
import 'infrastructure/audio/audio_engine.dart';
import 'infrastructure/audio/click_sounds.dart';
import 'presentation/screens/home_screen.dart';

void main() {
  runApp(const OnePadApp());
}

class OnePadApp extends StatefulWidget {
  const OnePadApp({super.key});

  @override
  State<OnePadApp> createState() => _OnePadAppState();
}

class _OnePadAppState extends State<OnePadApp> {
  late final PracticeFlowController _controller;
  late final Future<Skill> _bootstrap;

  @override
  void initState() {
    super.initState();
    _controller = PracticeFlowController(
      engine: SoloudAudioEngine(),
      sounds: ClickSounds(sampleRate: PracticeFlowController.sampleRate),
    );
    _bootstrap = _init();
  }

  Future<Skill> _init() async {
    await _controller.init();
    final jsonString =
        await rootBundle.loadString('content/skills/quarter_note_pulse.json');
    return ContentLoader().loadSkill(jsonString);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'One Pad',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
      ),
      home: FutureBuilder<Skill>(
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
          return HomeScreen(controller: _controller, skill: snapshot.data!);
        },
      ),
    );
  }
}
