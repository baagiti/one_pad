import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../application/session_flow/practice_flow_controller.dart';
import '../../application/tempo/tap_tempo_calculator.dart';
import '../../domain/timeline/timeline_map.dart';
import '../../infrastructure/audio/recording_paths.dart';
import '../../infrastructure/storage/app_database.dart';
import '../notation/notation_view.dart';
import '../theme/app_theme.dart';
import '../widgets/drum_head_background.dart';
import 'practice_screen.dart';

/// Session Preview (spec §5): listen to the generated session with metronome
/// and optional reference pad hits. Never recorded or analyzed.
class SessionPreviewScreen extends StatefulWidget {
  final PracticeFlowController controller;
  final AppDatabase db;

  /// This level's practice tip (`Level.note`), if it has one — shown as a
  /// small hint above the action buttons.
  final String? levelNote;

  const SessionPreviewScreen({
    super.key,
    required this.controller,
    required this.db,
    this.levelNote,
  });

  @override
  State<SessionPreviewScreen> createState() => _SessionPreviewScreenState();
}

class _SessionPreviewScreenState extends State<SessionPreviewScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  TimelinePosition? _pos;
  final _tapTempo = TapTempoCalculator();

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

  void _nudgeBpm(int delta) {
    setState(() => controller.changeBpm(controller.session!.bpm + delta));
  }

  void _onTapTempo() {
    final bpm = _tapTempo.tap(DateTime.now());
    if (bpm != null) {
      setState(() => controller.changeBpm(bpm));
    }
  }

  Future<void> _beginPractice() async {
    _ticker.stop();
    await controller.stop();
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PracticeScreen(controller: controller, db: widget.db),
      ),
    );
  }

  Future<void> _beginRecording() async {
    _ticker.stop();
    await controller.stop();

    final filePath = await newRecordingFilePath(
      skillId: controller.session!.skillId,
    );
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PracticeScreen(
          controller: controller,
          db: widget.db,
          recordingFilePath: filePath,
        ),
      ),
    );
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
      body: Stack(
        children: [
          const Positioned.fill(child: DrumHeadBackground()),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTempoRow(context, session.bpm, previewing),
                if (widget.levelNote != null) ...[
                  const SizedBox(height: 8),
                  _buildLevelNote(context, widget.levelNote!),
                ],
                const SizedBox(height: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.outline),
                    ),
                    child: NotationView(session: session, position: _pos),
                  ),
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
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: previewing ? null : _beginRecording,
                  icon: const Icon(
                    Icons.fiber_manual_record,
                    color: AppColors.error,
                  ),
                  label: const Text('Record'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelNote(BuildContext context, String note) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.lightbulb_outline,
          size: 16,
          color: AppColors.secondary,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            note,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildTempoRow(BuildContext context, int bpm, bool previewing) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: previewing ? null : () => _nudgeBpm(-1),
              icon: const Icon(Icons.chevron_left),
            ),
            SizedBox(
              width: 90,
              child: Text(
                '♩ = $bpm',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              onPressed: previewing ? null : () => _nudgeBpm(1),
              icon: const Icon(Icons.chevron_right),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: previewing ? null : _onTapTempo,
              child: const Text('TAP TEMPO'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${controller.session!.exercises.length} exercises',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }
}
