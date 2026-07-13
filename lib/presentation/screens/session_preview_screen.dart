import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../application/session_flow/practice_flow_controller.dart';
import '../../domain/timeline/timeline_map.dart';
import '../notation/notation_view.dart';
import 'practice_screen.dart';

/// Session Preview (spec §5): listen to the generated session with metronome
/// and optional reference pad hits. Never recorded or analyzed.
class SessionPreviewScreen extends StatefulWidget {
  final PracticeFlowController controller;

  const SessionPreviewScreen({super.key, required this.controller});

  @override
  State<SessionPreviewScreen> createState() => _SessionPreviewScreenState();
}

class _SessionPreviewScreenState extends State<SessionPreviewScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  TimelinePosition? _pos;

  PracticeFlowController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) {
      final pos = controller.poll();
      setState(() {
        _pos = pos;
        if (controller.stage == FlowStage.idle) _ticker.stop();
      });
    });
  }

  Future<void> _togglePreview() async {
    if (controller.stage == FlowStage.previewing) {
      await controller.stop();
      _ticker.stop();
      setState(() => _pos = null);
    } else {
      await controller.startPreview();
      _ticker.start();
    }
  }

  Future<void> _beginPractice() async {
    _ticker.stop();
    await controller.stop();
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => PracticeScreen(controller: controller),
    ));
  }

  @override
  void dispose() {
    _ticker.dispose();
    // Leaving the screen by back button must not keep audio running.
    if (controller.stage == FlowStage.previewing) controller.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = controller.session!;
    final previewing = controller.stage == FlowStage.previewing;

    return Scaffold(
      appBar: AppBar(title: const Text('Session Preview')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${session.exercises.length} exercises · ${session.bpm} BPM',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Expanded(
              child: NotationView(session: session, position: _pos),
            ),
            SwitchListTile(
              title: const Text('Reference hits'),
              subtitle: const Text('Hear the pad strokes during preview'),
              value: controller.referenceHits,
              onChanged: previewing
                  ? null
                  : (v) => setState(() => controller.referenceHits = v),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _togglePreview,
                    icon: Icon(previewing ? Icons.stop : Icons.hearing),
                    label: Text(previewing ? 'Stop' : 'Preview'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: _beginPractice,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Begin'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
