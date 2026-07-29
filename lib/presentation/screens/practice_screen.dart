import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../application/session_flow/practice_flow_controller.dart';
import '../../domain/timeline/timeline_map.dart';
import '../../infrastructure/storage/app_database.dart';
import '../notation/notation_view.dart';
import '../theme/app_theme.dart';
import 'results_screen.dart';

/// Practice (spec §7): notation, playhead, BPM, metronome, session progress —
/// and nothing else. Beat numbers are never displayed.
class PracticeScreen extends StatefulWidget {
  final PracticeFlowController controller;
  final AppDatabase db;

  /// When set, this run is a Record-mode take (design doc §9, M3): the
  /// microphone captures to this path instead of the pad's reference hits
  /// playing back audibly.
  final String? recordingFilePath;

  const PracticeScreen({
    super.key,
    required this.controller,
    required this.db,
    this.recordingFilePath,
  });

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
    if (widget.recordingFilePath != null) {
      // Deferred to after the first frame so the dialog has a BuildContext
      // to show against; recording itself only starts once it's dismissed,
      // giving the user a moment to actually move the pad into place.
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _showRecordingWarning());
    } else {
      _start();
    }
  }

  Future<void> _showRecordingWarning() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Before you record'),
        content: const Text(
          'Keep your pad close to the device — it makes it much easier for '
          'the microphone to hear each hit clearly.\n\n'
          "Wear headphones if you can. Without them, the metronome click "
          "can bleed into the recording and throw off your score.",
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Start Recording'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    _start();
  }

  Future<void> _start() async {
    final path = widget.recordingFilePath;
    if (path != null) {
      await controller.startRecording(filePath: path);
    } else {
      await controller.startPractice();
    }
    _ticker.start();
  }

  void _onTick(Duration _) {
    final pos = controller.poll();
    setState(() => _pos = pos);
    if (controller.stage == FlowStage.finished) {
      _ticker.stop();
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => ResultsScreen(controller: controller, db: widget.db),
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

    final measuresPerExercise = session.exercises.first.measureCount;
    final progress = (pos == null || pos.isCountIn)
        ? 0.0
        : ((pos.exercise +
                    (pos.measureWithinExercise +
                            (pos.beat + pos.beatFraction) /
                                map.timeSignature.beats) /
                        measuresPerExercise) /
                session.exercises.length)
            .clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (controller.isRecording) ...[
              const Icon(Icons.fiber_manual_record,
                  color: AppColors.error, size: 16),
              const SizedBox(width: 6),
            ],
            Text('${session.bpm} BPM'),
          ],
        ),
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
