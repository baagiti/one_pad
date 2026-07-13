import 'package:flutter/material.dart';

import '../../application/session_flow/practice_flow_controller.dart';
import '../../domain/model/skill.dart';
import 'session_preview_screen.dart';

/// Home (spec §3): Start Practice, Skills, Performance.
/// Visual design is deliberately placeholder — structure follows the spec,
/// styling is an open product decision.
class HomeScreen extends StatefulWidget {
  final PracticeFlowController controller;
  final Skill skill;

  const HomeScreen({super.key, required this.controller, required this.skill});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _level = 1;

  Future<void> _startPractice() async {
    widget.controller.generateSession(skill: widget.skill, level: _level);
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SessionPreviewScreen(controller: widget.controller),
    ));
  }

  void _openSkills() {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(widget.skill.name,
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            for (final level in widget.skill.levels)
              ListTile(
                leading: Icon(level.level == _level
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off),
                title: Text('Level ${level.level} — ${level.name}'),
                onTap: () {
                  setState(() => _level = level.level);
                  Navigator.of(context).pop();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final level = widget.skill.level(_level);
    return Scaffold(
      appBar: AppBar(title: const Text('One Pad')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Current Practice',
                            style: Theme.of(context).textTheme.labelMedium),
                        const SizedBox(height: 4),
                        Text(widget.skill.name,
                            style: Theme.of(context).textTheme.titleLarge),
                        Text('Level $_level — ${level.name}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _startPractice,
                  icon: const Icon(Icons.play_arrow),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Start Practice'),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _openSkills,
                  icon: const Icon(Icons.school_outlined),
                  label: const Text('Skills'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: null, // Performance arrives with Premium (M5)
                  icon: const Icon(Icons.stars_outlined),
                  label: const Text('Performance'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
