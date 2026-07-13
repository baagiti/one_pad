import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../application/session_flow/practice_flow_controller.dart';
import '../../domain/timeline/timeline_map.dart';
import '../notation/notation_view.dart';
import 'results_screen.dart';

/// Practice (spec §7): notation, playhead, BPM, metronome, session progress —
/// and nothing else. Beat numbers are never displayed.
class PracticeScreen extends StatefulWidget {
  final PracticeFlowController controller;

  const PracticeScreen({super.key, required this.controller});

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  TimelinePosition? _pos;

  PracticeFlowController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _start();
  }

  Future<void> _start() async {
    await controller.startPractice();
    _ticker.start();
  }

  void _onTick(Duration _) {
    final pos = controller.poll();
    setState(() => _pos = pos);
    if (controller.stage == FlowStage.finished) {
      _ticker.stop();
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => ResultsScreen(controller: controller),
      ));
    }
  }

  Future<void> _abort() async {
    _ticker.stop();
    await controller.stop();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _ticker.dispose();
    if (controller.stage == FlowStage.countIn ||
        controller.stage == FlowStage.practicing) {
      controller.stop();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = controller.session!;
    final map = controller.map!;
    final pos = _pos;
    final isCountIn = controller.stage == FlowStage.countIn;

    final progress = (pos == null || pos.isCountIn)
        ? 0.0
        : ((pos.exercise + (pos.beat + pos.beatFraction) / map.timeSignature.beats) /
                session.exercises.length)
            .clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: Text('${session.bpm} BPM'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _abort,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 16),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: NotationView(session: session, position: pos),
                  ),
                  if (isCountIn)
                    Positioned.fill(
                      child: ColoredBox(
                        color: Theme.of(context)
                            .colorScheme
                            .surface
                            .withValues(alpha: 0.55),
                        child: Center(
                          child: Text(
                            // Count downwards: 4/4 shows 4, 3, 2, 1.
                            '${map.timeSignature.beats - (pos?.beat ?? 0)}',
                            style: Theme.of(context)
                                .textTheme
                                .displayLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
