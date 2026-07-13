import 'package:flutter/material.dart';

import '../../domain/model/session.dart';
import '../../domain/timeline/timeline_map.dart';
import 'notation_layout.dart';
import 'notation_painter.dart';

/// The practice notation widget: page-style rows (2 measures per row, 2 rows
/// visible = four consecutive exercises, spec §7). The active row is always
/// the top row; when it completes the page glides up one row height, so the
/// eye never chases the music — the music comes to the eye.
class NotationView extends StatelessWidget {
  final Session session;
  final TimelinePosition? position;

  const NotationView({
    super.key,
    required this.session,
    required this.position,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = NotationLayout(
          timeSignature: session.timeSignature,
          measureWidth:
              constraints.maxWidth / NotationLayout.measuresPerRow,
          rowHeight: constraints.maxHeight / NotationLayout.visibleRows,
          measureCount: session.exercises.length,
        );

        final pos = position;
        final isCountIn = pos?.isCountIn ?? true;
        final current =
            (pos == null || isCountIn || pos.isFinished) ? -1 : pos.exercise;
        final targetScroll = current < 0 ? 0.0 : layout.scrollY(current);
        final playheadBeat = (pos != null && !isCountIn && !pos.isFinished)
            ? pos.beat + pos.beatFraction
            : null;

        return TweenAnimationBuilder<double>(
          tween: Tween(end: targetScroll),
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeInOutCubic,
          builder: (context, scrollY, _) {
            return CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: NotationPainter(
                exercises: session.exercises,
                layout: layout,
                style: NotationStyle.fromTheme(Theme.of(context)),
                scrollY: scrollY,
                currentExercise: current,
                playheadBeat: playheadBeat,
              ),
            );
          },
        );
      },
    );
  }
}
