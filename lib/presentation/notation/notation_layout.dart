import 'dart:math';

import '../../domain/model/exercise.dart';
import '../../domain/model/time_signature.dart';

/// Pure layout math for the page-style notation view. No Flutter imports —
/// unit-testable on its own.
///
/// Exercises are laid out as rows of [measuresPerRow] measures, like a score
/// page. The active row is always the TOP visible row; when it completes, the
/// whole page scrolls up smoothly by one row and the next row takes its place
/// (reference behavior chosen by the user, 2026-07-13). With two rows of two
/// measures visible, spec §7's "four consecutive exercises" holds.
class NotationLayout {
  static const measuresPerRow = 2;
  static const visibleRows = 2;

  final TimeSignature timeSignature;
  final double measureWidth;
  final double rowHeight;
  final int measureCount;

  /// Space between a barline and the first beat of the measure.
  final double leadingPad;

  /// Space after the last beat before the next barline.
  final double trailingPad;

  NotationLayout({
    required this.timeSignature,
    required this.measureWidth,
    required this.rowHeight,
    required this.measureCount,
  })  : leadingPad = measureWidth * 0.12,
        trailingPad = measureWidth * 0.06;

  int get rowCount => (measureCount / measuresPerRow).ceil();

  double get pageHeight => rowCount * rowHeight;

  int rowOf(int measure) => measure ~/ measuresPerRow;

  int colOf(int measure) => measure % measuresPerRow;

  double measureX(int measure) => colOf(measure) * measureWidth;

  double rowY(int row) => row * rowHeight;

  /// Y of the staff line inside a row (single-line percussion staff).
  double staffY(int row) => rowY(row) + rowHeight * 0.48;

  double get _beatSpacing =>
      (measureWidth - leadingPad - trailingPad) / timeSignature.beats;

  /// X of a (possibly fractional) beat inside a measure.
  double beatX(int measure, double beat) =>
      measureX(measure) + leadingPad + beat * _beatSpacing;

  /// Note placements for one exercise; rests take horizontal space but draw
  /// nothing in v1 (rest glyphs arrive with future skills).
  List<NotePlacement> notesOf(Exercise e) {
    final placements = <NotePlacement>[];
    var beat = 0.0;
    var noteIdx = 0;
    for (final token in e.rhythm) {
      if (!token.isRest) {
        placements.add(NotePlacement(
          x: beatX(e.index, beat),
          row: rowOf(e.index),
          sticking: e.sticking[noteIdx].label,
        ));
        noteIdx++;
      }
      beat += token.lengthInBeats(timeSignature.beatUnit);
    }
    return placements;
  }

  /// Top visible row for a given current exercise, clamped so the viewport
  /// always shows [visibleRows] full rows.
  int topRow(int currentExercise) {
    final maxTop = max(0, rowCount - visibleRows);
    return rowOf(currentExercise.clamp(0, measureCount - 1)).clamp(0, maxTop);
  }

  /// Vertical page offset (positive, to be subtracted) for the viewport.
  double scrollY(int currentExercise) => rowY(topRow(currentExercise));

  /// Playhead x for a musical position inside [exercise].
  double playheadX(int exercise, double beatWithFraction) =>
      beatX(exercise, beatWithFraction);
}

class NotePlacement {
  final double x;
  final int row;
  final String sticking;

  const NotePlacement({
    required this.x,
    required this.row,
    required this.sticking,
  });
}
