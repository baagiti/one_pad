import 'dart:math';

import 'package:flutter/material.dart';

import '../../domain/model/exercise.dart';
import '../../domain/model/note_token.dart';
import 'notation_layout.dart';

/// Draws the page-style notation: rows of measures on single-line percussion
/// staves, notes and rests as Bravura (SMuFL) glyphs, sticking letters under
/// each note, the current-measure highlight frame and the playhead
/// (spec §7). The page is translated by [scrollY] (animated upstream) so
/// completed rows glide out of the top of the viewport.
///
/// Notes/rests were originally hand-drawn vector shapes (v1 content was
/// quarter-notes only). Switched to Bravura once rests became pedagogically
/// central (Skill 2) and upcoming skills need beams/flags that are brittle
/// to hand-roll — one glyph source now covers every duration correctly.
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

/// SMuFL codepoints (Bravura), combined notehead+stem-up glyphs and matching
/// rests. Covers every duration in [NoteDuration] so future skills (eighth/
/// sixteenth notes) render correctly with no painter changes.
const _noteGlyphs = {
  NoteDuration.whole: '',
  NoteDuration.half: '',
  NoteDuration.quarter: '',
  NoteDuration.eighth: '',
  NoteDuration.sixteenth: '',
  NoteDuration.thirtySecond: '',
};

const _restGlyphs = {
  NoteDuration.whole: '',
  NoteDuration.half: '',
  NoteDuration.quarter: '',
  NoteDuration.eighth: '',
  NoteDuration.sixteenth: '',
  NoteDuration.thirtySecond: '',
};

/// Bravura noteheadBlack — used alone (no baked-in flag/stem) for beamed
/// eighth notes, whose stem and beam are drawn manually (see [_paintBeam]).
const _noteheadGlyph = '\u{E0A4}';

/// Bravura augmentationDot — drawn after a dotted note's glyph (Skill 5,
/// dotted quarter + eighth).
const _augmentationDotGlyph = '\u{E1E7}';

/// Bravura articAccentAbove — drawn above an accented note's glyph (Skill 6,
/// paradiddle lead-stroke accents).
const _accentGlyph = '\u{E4A0}';

class NotationPainter extends CustomPainter {
  final List<Exercise> exercises;
  final NotationLayout layout;
  final NotationStyle style;

  /// Vertical page translation in pixels (already animated upstream).
  final double scrollY;

  /// Current exercise index, -1 during count-in / idle.
  final int currentExercise;

  /// Which of the current exercise's measures the playhead is in (0-based;
  /// always 0 for a single-measure exercise, design doc §23).
  final int currentMeasureWithinExercise;

  /// Playhead beat position (beat + fraction) inside the current MEASURE
  /// (see [currentMeasureWithinExercise]), null hides the playhead
  /// (count-in has none, spec §6).
  final double? playheadBeat;

  NotationPainter({
    required this.exercises,
    required this.layout,
    required this.style,
    required this.scrollY,
    required this.currentExercise,
    this.currentMeasureWithinExercise = 0,
    required this.playheadBeat,
  });

  static const _glyphFontSize = 40.0;

  /// Approximate on-staff footprint of a note glyph, used for the highlight
  /// box and playhead extents (independent of the exact glyph metrics).
  static const _noteVisualHeight = 34.0;

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
        NotationLayout.measuresPerRow, layout.measureCount - firstMeasure);
    final rowWidth = measuresInRow * layout.measureWidth;

    canvas.drawLine(Offset(0, staffY), Offset(rowWidth, staffY), staff);

    for (var c = 0; c <= measuresInRow; c++) {
      final x = c * layout.measureWidth;
      canvas.drawLine(
          Offset(x, staffY - 18), Offset(x, staffY + 18), barline);
    }
    // Final double barline after the very last measure of the session.
    if (firstMeasure + measuresInRow == layout.measureCount) {
      canvas.drawLine(
        Offset(rowWidth - 4, staffY - 18),
        Offset(rowWidth - 4, staffY + 18),
        Paint()
          ..color = style.staffColor
          ..strokeWidth = style.barlineThickness * 2,
      );
    }

    // An exercise's content is painted ONCE, from its first measure column
    // — its own notes/rests already carry the correct global row/x for
    // every measure it spans (design doc §23), so painting on every column
    // it touches would draw it multiple times.
    for (var c = 0; c < measuresInRow; c++) {
      final globalMeasure = firstMeasure + c;
      final exerciseIndex = globalMeasure ~/ layout.measuresPerExercise;
      if (exerciseIndex >= exercises.length) continue;
      if (globalMeasure == layout.baseMeasureOfExercise(exerciseIndex)) {
        _paintExercise(canvas, exercises[exerciseIndex]);
      }
    }
  }

  void _paintHighlight(Canvas canvas) {
    if (currentExercise < 0 || currentExercise >= exercises.length) return;
    final baseMeasure = layout.baseMeasureOfExercise(currentExercise);
    final staffY = layout.staffY(layout.rowOf(baseMeasure));
    final width = layout.measureWidth * layout.measuresPerExercise;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        layout.measureX(baseMeasure) + 2,
        staffY - _noteVisualHeight - 14,
        width - 4,
        _noteVisualHeight + 14 + 44,
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

  /// Paints one exercise's full notation — every note/rest already carries
  /// its own correct global [NotePlacement.row] (so `layout.staffY(n.row)`
  /// is used per-note rather than a single shared staffY), since an
  /// exercise can span more than one measure/row's worth of content
  /// (design doc §23).
  void _paintExercise(Canvas canvas, Exercise e) {
    final notes = layout.notesOf(e);

    for (final n in notes) {
      final staffY = layout.staffY(n.row);
      final width = n.beamed
          ? _paintBeamedNotehead(canvas, n.x, staffY)
          : _paintGlyph(canvas, _noteGlyphs[n.duration]!, Offset(n.x, staffY),
              style.noteColor);

      if (n.isDotted) {
        _paintGlyph(canvas, _augmentationDotGlyph,
            Offset(n.x + width / 2 + 6, staffY), style.noteColor);
      }

      if (n.isAccented) {
        _paintGlyph(canvas, _accentGlyph,
            Offset(n.x, staffY - _noteVisualHeight - 14), style.noteColor);
      }

      // Counting-syllable label ("1", "&", "e", "trip"...) on a "How to
      // Count" intro level REPLACES the sticking letter entirely — the
      // whole point of that level is reading/saying the count, and
      // showing both at once is clutter, not help. Otherwise the usual
      // sticking letter, skipped on a tied note (no new attack to label,
      // design doc §24).
      final label = n.countingLabel;
      if (label != null || !n.isTied) {
        final tp = TextPainter(
          text: TextSpan(
            text: label ?? n.sticking,
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

    // Tie curve from each tied note back to the note it continues — the
    // reader sees two noteheads (so the beat grid stays visible, e.g. beat
    // 3 in 4/4) but only one attack (design doc §24).
    NotePlacement? prev;
    for (final n in notes) {
      if (n.isTied && prev != null && prev.row == n.row) {
        _paintTie(canvas, prev.x, n.x, layout.staffY(n.row));
      }
      prev = n;
    }

    // One beam per group ([NotePlacement.beamGroupEnd] marks where each
    // group closes) — usually a same-beat pair (design doc §17), but a
    // single beam spanning a whole rudiment group (e.g. the paradiddle's 4
    // notes, design doc §20) when NotationLayout widened it. A group never
    // crosses a measure boundary, so every note in it shares one row/staffY.
    double? groupStartX;
    for (final n in notes) {
      if (!n.beamed) continue;
      groupStartX ??= n.x;
      if (n.beamGroupEnd) {
        _paintBeam(canvas, groupStartX, n.x, layout.staffY(n.row));
        groupStartX = null;
      }
    }

    // Inner beam for contiguous sixteenth-note (or shorter) sub-runs (e.g.
    // the "two sixteenths" half of "two sixteenths + an eighth", design
    // doc §21) — drawn alongside the primary beam, standard mixed-duration
    // engraving.
    double? secondaryStartX;
    for (final n in notes) {
      if (!n.secondaryBeamed) continue;
      secondaryStartX ??= n.x;
      if (n.secondaryBeamGroupEnd) {
        _paintBeam(canvas, secondaryStartX, n.x, layout.staffY(n.row),
            yOffset: 5.5);
        secondaryStartX = null;
      }
    }

    // Third (innermost) beam for contiguous 32nd-note sub-runs — same
    // stacking idea one level deeper (design doc §9.3).
    double? tertiaryStartX;
    for (final n in notes) {
      if (!n.tertiaryBeamed) continue;
      tertiaryStartX ??= n.x;
      if (n.tertiaryBeamGroupEnd) {
        _paintBeam(canvas, tertiaryStartX, n.x, layout.staffY(n.row),
            yOffset: 11.0);
        tertiaryStartX = null;
      }
    }

    // Triplet "3" mark (plus a bracket when the group isn't also beamed,
    // e.g. quarter-note triplets — eighth-note triplets already have a
    // beam to sit above, design doc §27).
    double? tripletStartX;
    var tripletStartBeamed = false;
    for (final n in notes) {
      if (!n.isTriplet) continue;
      if (tripletStartX == null) {
        tripletStartX = n.x;
        tripletStartBeamed = n.beamed;
      }
      if (n.tripletGroupEnd) {
        _paintGroupNumeralMark(canvas, tripletStartX, n.x,
            layout.staffY(n.row), tripletStartBeamed, '3');
        tripletStartX = null;
      }
    }

    // Duplet "2" mark — the triplet mark's mirror image, for 2 notes
    // filling one compound pulse instead of 3.
    double? dupletStartX;
    var dupletStartBeamed = false;
    for (final n in notes) {
      if (!n.isDuplet) continue;
      if (dupletStartX == null) {
        dupletStartX = n.x;
        dupletStartBeamed = n.beamed;
      }
      if (n.dupletGroupEnd) {
        _paintGroupNumeralMark(canvas, dupletStartX, n.x, layout.staffY(n.row),
            dupletStartBeamed, '2');
        dupletStartX = null;
      }
    }

    for (final r in layout.restsOf(e)) {
      _paintGlyph(canvas, _restGlyphs[r.duration]!,
          Offset(r.x, layout.staffY(r.row)), style.noteColor);

      // "How to Count" intro levels show the silent count under a rest too
      // — parenthesized, since nothing is struck there (e.g. "(2)").
      final label = r.countingLabel;
      if (label != null) {
        final tp = TextPainter(
          text: TextSpan(
            text: '($label)',
            style: TextStyle(
              color: style.stickingColor.withValues(alpha: 0.6),
              fontSize: 15,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas,
            Offset(r.x - tp.width / 2, layout.staffY(r.row) + 18));
      }
    }
  }

  /// A small italic numeral (triplet "3" or duplet "2") centered above
  /// [xA]..[xB] — when [beamed] is false (e.g. quarter-note triplets,
  /// which never beam) a horizontal bracket with short downward ticks is
  /// drawn first, since there's no beam for the numeral to sit above
  /// (design doc §27; duplets are its mirror image).
  void _paintGroupNumeralMark(Canvas canvas, double xA, double xB,
      double staffY, bool beamed, String numeral) {
    final midX = (xA + xB) / 2;
    final y = staffY - _noteVisualHeight - (beamed ? 20 : 24);
    if (!beamed) {
      final paint = Paint()
        ..color = style.noteColor
        ..strokeWidth = 1.2;
      canvas.drawLine(Offset(xA, y), Offset(xB, y), paint);
      canvas.drawLine(Offset(xA, y), Offset(xA, y + 5), paint);
      canvas.drawLine(Offset(xB, y), Offset(xB, y + 5), paint);
    }
    final tp = TextPainter(
      text: TextSpan(
        text: numeral,
        style: TextStyle(
          color: style.noteColor,
          fontSize: 13,
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(midX - tp.width / 2, y - tp.height - 1));
  }

  /// A shallow curve from [xA] to [xB], below the noteheads (opposite the
  /// stems, which point up) — standard tie engraving (design doc §24).
  void _paintTie(Canvas canvas, double xA, double xB, double staffY) {
    final path = Path()
      ..moveTo(xA, staffY + 8)
      ..quadraticBezierTo((xA + xB) / 2, staffY + 16, xB, staffY + 8);
    canvas.drawPath(
      path,
      Paint()
        ..color = style.noteColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
  }

  /// Notehead-only glyph + a manually drawn stem (no flag) — the flag is
  /// replaced by [_paintBeam] once its pair partner is also painted.
  /// Returns the notehead glyph width (used for stem/dot placement).
  double _paintBeamedNotehead(Canvas canvas, double x, double staffY) {
    final width = _paintGlyph(
        canvas, _noteheadGlyph, Offset(x, staffY), style.noteColor);
    final stemX = x + width / 2 - 1.0;
    canvas.drawLine(
      Offset(stemX, staffY - 1),
      Offset(stemX, staffY - _noteVisualHeight),
      Paint()
        ..color = style.noteColor
        ..strokeWidth = 1.8,
    );
    return width;
  }

  /// [yOffset] shifts a secondary (inner) beam down toward the noteheads,
  /// stacked below the primary beam — standard engraving for the
  /// sixteenth-note portion of a mixed eighth/sixteenth group (§21).
  void _paintBeam(Canvas canvas, double xA, double xB, double staffY,
      {double yOffset = 0}) {
    // Matches the stem placement in _paintBeamedNotehead (right edge of a
    // notehead of the same glyph/font size).
    final headWidth = _measureGlyphWidth(_noteheadGlyph);
    final stemXA = xA + headWidth / 2 - 1.0;
    final stemXB = xB + headWidth / 2 - 1.0;
    final topY = staffY - _noteVisualHeight + yOffset;
    canvas.drawRect(
      Rect.fromLTRB(stemXA, topY, stemXB, topY + 3.2),
      Paint()..color = style.noteColor,
    );
  }

  double _measureGlyphWidth(String glyph) {
    final tp = TextPainter(
      text: TextSpan(
        text: glyph,
        style: const TextStyle(fontFamily: 'Bravura', fontSize: _glyphFontSize),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    return tp.width;
  }

  /// SMuFL glyphs are designed so a note/rest's staff-reference point is the
  /// text *baseline* — aligning on the baseline (rather than a guessed
  /// fraction of the font's ascent box) is what puts notes and rests on the
  /// same line regardless of how much empty space the font reserves above
  /// or below the glyph's ink.
  double _paintGlyph(Canvas canvas, String glyph, Offset anchor, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: glyph,
        style: TextStyle(
          fontFamily: 'Bravura',
          fontSize: _glyphFontSize,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final baseline = tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    tp.paint(
      canvas,
      Offset(anchor.dx - tp.width / 2, anchor.dy - baseline),
    );
    return tp.width;
  }

  void _paintPlayhead(Canvas canvas) {
    final beat = playheadBeat;
    if (beat == null || currentExercise < 0) return;
    final globalMeasure = layout.baseMeasureOfExercise(currentExercise) +
        currentMeasureWithinExercise;
    final staffY = layout.staffY(layout.rowOf(globalMeasure));
    final x = layout.playheadX(
        currentExercise, currentMeasureWithinExercise, beat);
    canvas.drawLine(
      Offset(x, staffY - _noteVisualHeight - 12),
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
      old.currentMeasureWithinExercise != currentMeasureWithinExercise ||
      old.playheadBeat != playheadBeat ||
      old.exercises != exercises;
}
