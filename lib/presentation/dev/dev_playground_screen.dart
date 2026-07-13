import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../domain/content/content_loader.dart';
import '../../domain/generation/session_generator.dart';
import '../../domain/model/session.dart';
import '../../domain/model/skill.dart';
import '../../domain/timeline/timeline_map.dart';
import '../../infrastructure/audio/audio_engine.dart';
import '../../infrastructure/audio/click_sounds.dart';
import '../../infrastructure/audio/session_audio_renderer.dart';
import '../../infrastructure/audio/wav_codec.dart';
import '../notation/notation_view.dart';

/// TEMPORARY developer screen: proves the full generation → render → playback
/// → master-timeline loop end to end on desktop. This is NOT product UI —
/// real screens are designed with the user (see design doc §7, §12).
class DevPlaygroundScreen extends StatefulWidget {
  const DevPlaygroundScreen({super.key});

  @override
  State<DevPlaygroundScreen> createState() => _DevPlaygroundScreenState();
}

class _DevPlaygroundScreenState extends State<DevPlaygroundScreen>
    with SingleTickerProviderStateMixin {
  static const sampleRate = 44100;

  final _engine = SoloudAudioEngine();
  final _sounds = ClickSounds(sampleRate: sampleRate);
  late final Ticker _ticker;

  Skill? _skill;
  Session? _session;
  TimelineMap? _map;
  TimelinePosition? _pos;

  int _level = 1;
  int _bpm = 70;
  bool _referenceHits = true;
  bool _playing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      await _engine.init();
      final jsonString =
          await rootBundle.loadString('content/skills/quarter_note_pulse.json');
      setState(() {
        _skill = ContentLoader().loadSkill(jsonString);
        _bpm = _skill!.bpmDefault;
      });
    } catch (e) {
      setState(() => _error = '$e');
    }
  }

  void _onTick(Duration _) {
    final map = _map;
    if (map == null) return;
    final samples =
        _engine.position.inMicroseconds * sampleRate ~/ 1000000;
    final pos = map.positionAt(samples);
    final stillPlaying = _engine.isPlaying;
    setState(() {
      _pos = pos;
      if (!stillPlaying) {
        _playing = false;
        _ticker.stop();
      }
    });
  }

  Future<void> _generateAndPlay() async {
    final skill = _skill;
    if (skill == null) return;
    await _stop();

    final session = SessionGenerator(seed: Random().nextInt(1 << 31))
        .generate(skill: skill, levelNumber: _level, bpm: _bpm);
    final map = TimelineMap.forSession(session, sampleRate: sampleRate);
    final pcm = SessionAudioRenderer(sounds: _sounds).render(
      map: map,
      exercises: session.exercises,
      includeReferenceHits: _referenceHits,
    );
    final wav = pcm16ToWav(pcm, sampleRate: sampleRate);

    await _engine.loadSession(Uint8List.fromList(wav));
    await _engine.play();

    setState(() {
      _session = session;
      _map = map;
      _playing = true;
      _pos = map.positionAt(0);
    });
    _ticker.start();
  }

  Future<void> _stop() async {
    _ticker.stop();
    await _engine.stop();
    if (mounted) setState(() => _playing = false);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _engine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skill = _skill;
    return Scaffold(
      appBar: AppBar(title: const Text('One Pad — Dev Playground')),
      body: _error != null
          ? Center(child: Text('Error: $_error'))
          : skill == null
              ? const Center(child: CircularProgressIndicator())
              : _buildBody(skill),
    );
  }

  Widget _buildBody(Skill skill) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('${skill.name} — Level:'),
              const SizedBox(width: 12),
              SegmentedButton<int>(
                segments: [
                  for (final l in skill.levels)
                    ButtonSegment(value: l.level, label: Text('${l.level}')),
                ],
                selected: {_level},
                onSelectionChanged: (s) =>
                    setState(() => _level = s.first),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('BPM'),
              Expanded(
                child: Slider(
                  min: skill.bpmMin.toDouble(),
                  max: skill.bpmMax.toDouble(),
                  divisions: skill.bpmMax - skill.bpmMin,
                  value: _bpm.toDouble(),
                  label: '$_bpm',
                  onChanged: (v) => setState(() => _bpm = v.round()),
                ),
              ),
              Text('$_bpm'),
              const SizedBox(width: 24),
              const Text('Reference hits'),
              Switch(
                value: _referenceHits,
                onChanged: (v) => setState(() => _referenceHits = v),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              FilledButton.icon(
                onPressed: _generateAndPlay,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Generate & Play'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _playing ? _stop : null,
                icon: const Icon(Icons.stop),
                label: const Text('Stop'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildPositionPanel(),
          const SizedBox(height: 16),
          if (_session != null)
            SizedBox(
              height: 240,
              child: NotationView(session: _session!, position: _pos),
            ),
          const SizedBox(height: 12),
          Expanded(child: _buildExerciseList()),
        ],
      ),
    );
  }

  Widget _buildPositionPanel() {
    final pos = _pos;
    final map = _map;
    if (pos == null || map == null) {
      return const Text('No session playing.');
    }
    final label = pos.isCountIn
        ? 'COUNT-IN — beat ${pos.beat + 1}/${map.timeSignature.beats}'
        : pos.isFinished
            ? 'Finished'
            : 'Exercise ${pos.exercise + 1}/16 — beat ${pos.beat + 1}/${map.timeSignature.beats}';
    final progress = pos.isCountIn || pos.isFinished
        ? 0.0
        : (pos.exercise + (pos.beat + pos.beatFraction) / map.timeSignature.beats) /
            map.exerciseCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: progress.clamp(0.0, 1.0)),
      ],
    );
  }

  Widget _buildExerciseList() {
    final session = _session;
    if (session == null) return const SizedBox.shrink();
    final current = (_pos?.isCountIn ?? true) ? -1 : (_pos?.exercise ?? -1);
    return ListView.builder(
      itemCount: session.exercises.length,
      itemBuilder: (context, i) {
        final e = session.exercises[i];
        final sticking = e.sticking.map((h) => h.label).join(' ');
        final active = i == current && _playing;
        return Container(
          color: active
              ? Theme.of(context).colorScheme.primaryContainer
              : null,
          child: ListTile(
            dense: true,
            leading: Text('${i + 1}'),
            title: Text(sticking,
                style: const TextStyle(
                    fontFamily: 'monospace', letterSpacing: 4)),
            trailing: Text(e.templateId),
          ),
        );
      },
    );
  }
}
