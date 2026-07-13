import 'package:flutter/material.dart';

import '../../application/session_flow/practice_flow_controller.dart';
import 'practice_screen.dart';

/// Results: v1 skeleton. Recording/analysis summaries land here in M3-M4;
/// content of this screen is an open product decision (design doc §12).
class ResultsScreen extends StatelessWidget {
  final PracticeFlowController controller;

  const ResultsScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final session = controller.session!;
    return Scaffold(
      appBar: AppBar(title: const Text('Session Complete')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.check_circle_outline,
                    size: 72,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  'Nice work!',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  '${session.exercises.length} exercises · ${session.bpm} BPM',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(MaterialPageRoute(
                      builder: (_) => PracticeScreen(controller: controller),
                    ));
                  },
                  icon: const Icon(Icons.replay),
                  label: const Text('Practice Again'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.of(context).popUntil((r) => r.isFirst),
                  icon: const Icon(Icons.home_outlined),
                  label: const Text('Home'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
