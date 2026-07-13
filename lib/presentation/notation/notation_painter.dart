import 'dart:math';

import 'package:flutter/material.dart';

import '../../domain/model/exercise.dart';
import 'notation_layout.dart';

/// Draws the page-style notation: rows of measures on single-line percussion
/// staves, quarter notes as vector shapes, sticking letters under each note,
/// the current-measure highlight frame and the playhead (spec §7). The page
/// is translated by [scrollY] (animated upstream) so completed rows glide
/// out of the top of the viewport.
///
/// Visual *design* (colors, weights, styling) is an open product decision —
/// everything here reads from [NotationStyle] so restyling is data, not code.
class NotationStyle {
  final Color staffColor;
  final Color noteColor;
  final Color stickingColor;
  final Color highlightFill;
  final Color highlightBorder;
  final Color playheadColor;
  final double staffThickness;
  final double barlineThickness;

  const NotationStyle({
    required this.staffColor,
    required this.noteColor,
    required this.stickingColor,
    required this.highlightFill,
    required this.highlightBorder,
    required this.playheadColor,
    this.staffThickness = 1.4,
    this.barlineThickness = 1.4,
  });

  factory NotationStyle.fromTheme(ThemeData theme) {
    final cs = theme.colorScheme;
    return NotationStyle(
      staffColor: cs.onSurface.withValues(alpha: 0.7),
      noteColor: cs.onSurface,
      stickingColor: cs.onSurfaceVariant,
      highlightFill: cs.primaryContainer.withValues(alpha: 0.25),
      highlightBorder: cs.primary,
      playheadColor: cs.tertiary,
    );
  }
}

class NotationPainter extends CustomPainter {
  final List<Exercise> exercises;
  final NotationLayout layout;
  final NotationStyle style;

  /// Vertical page translation in pixels (already animated upstream).
  final double scrollY;

  /// Current exercise index, -1 during count-in / idle.
  final int currentExercise;

  /// Playhead beat position (beat + fraction) inside the current exercise,
  /// null hides the playhead (count-in has none, spec §6).
  final double? playheadBeat;

  NotationPainter({
    required this.exercises,
    required this.layout,
    required this.style,
    required this.scrollY,
    required this.currentExercise,
    required this.playheadBeat,
  });

  static const _noteheadRx = 6.5;
  static const _noteheadRy = 4.8;
  static const _stemHeight = 34.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(0, -scrollY);

    final firstRow = max(0, (scrollY / layout.rowHeight).floor());
    final lastRow = min(layout.rowCount - 1,
        ((scrollY + size.height) / layout.rowHeight).ceil());

    _paintHighlight(canvas);

    for (var row = firstRow; row <= lastRow; row++) {
      _paintRow(canvas, row);
    }

    _paintPlayhead(canvas);
    canvas.restore();
  }

  void _paintRow(Canvas canvas, int row) {
    final staffY = layout.staffY(row);
    final staff = Paint()
      ..color = style.staffColor
      ..strokeWidth = style.staffThickness;
    final barline = Paint()
      ..color = style.staffColor
      ..strokeWidth = style.barlineThickness;

    final firstMeasure = row * NotationLayout.measuresPerRow;
    final measuresInRow = min(
        NotationLayout.measuresPerRow, exercises.length - firstMeasure);
    final rowWidth = measuresInRow * layout.measureWidth;

    canvas.drawLine(Offset(0, staffY), Offset(rowWidth, staffY), staff);

    for (var c = 0; c <= measuresInRow; c++) {
      final x = c * layout.measureWidth;
      canvas.drawLine(
          Offset(x, staffY - 18), Offset(x, staffY + 18), barline);
    }
    // Final double barline after the very last measure of the session.
    if (firstMeasure + measuresInRow == exercises.length) {
      canvas.drawLine(
        Offset(rowWidth - 4, staffY - 18),
        Offset(rowWidth - 4, staffY + 18),
        Paint()
          ..color = style.staffColor
          ..strokeWidth = style.barlineThickness * 2,
      );
    }

    for (var c = 0; c < measuresInRow; c++) {
      _paintMeasure(canvas, exercises[firstMeasure + c], staffY);
    }
  }

  void _paintHighlight(Canvas canvas) {
    if (currentExercise < 0 || currentExercise >= exercises.length) return;
    final staffY = layout.staffY(layout.rowOf(currentExercise));
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        layout.measureX(currentExercise) + 2,
        staffY - _stemHeight - 14,
        layout.measureWidth - 4,
        _stemHeight + 14 + 44,
      ),
      const Radius.circular(8),
    );
    canvas.drawRRect(rect, Paint()..color = style.highlightFill);
    canvas.drawRRect(
      rect,
      Paint()
        ..color = style.highlightBorder
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
  }

  void _paintMeasure(Canvas canvas, Exercise e, double staffY) {
    final notePaint = Paint()..color = style.noteColor;

    for (final n in layout.notesOf(e)) {
      // Notehead: filled ellipse, slightly rotated like engraved notation.
      canvas.save();
      canvas.translate(n.x, staffY);
      canvas.rotate(-0.35);
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset.zero,
            width: _noteheadRx * 2,
            height: _noteheadRy * 2),
        notePaint,
      );
      canvas.restore();

      // Stem: up, from the right edge of the notehead.
      final stemX = n.x + _noteheadRx - 0.6;
      canvas.drawLine(
        Offset(stemX, staffY - 2),
        Offset(stemX, staffY - _stemHeight),
        Paint()
          ..color = style.noteColor
          ..strokeWidth = 1.8,
      );

      // Sticking letter under the note (first skill's core curriculum —
      // always rendered, never optional).
      final tp = TextPainter(
        text: TextSpan(
          text: n.sticking,
          style: TextStyle(
            color: style.stickingColor,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(n.x - tp.width / 2, staffY + 18));
    }
  }

  void _paintPlayhead(Canvas canvas) {
    final beat = playheadBeat;
    if (beat == null || currentExercise < 0) return;
    final staffY = layout.staffY(layout.rowOf(currentExercise));
    final x = layout.playheadX(currentExercise, beat);
    canvas.drawLine(
      Offset(x, staffY - _stemHeight - 12),
      Offset(x, staffY + 40),
      Paint()
        ..color = style.playheadColor
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(NotationPainter old) =>
      old.scrollY != scrollY ||
      old.currentExercise != currentExercise ||
      old.playheadBeat != playheadBeat ||
      old.exercises != exercises;
}
