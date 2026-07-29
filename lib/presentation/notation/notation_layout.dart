import 'dart:math';

import '../../domain/model/exercise.dart';
import '../../domain/model/note_token.dart';
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

  /// How many measures each exercise occupies — 1 in the common case, but
  /// 2+ for rudiments that don't fit a single measure (design doc §23).
  /// Uniform across a session; must divide [measuresPerRow] or vice versa
  /// so a multi-measure exercise never straddles two rows.
  final int measuresPerExercise;

  /// Explicit notation beam-grouping, in numerator-beat units (e.g. [2, 2,
  /// 3] for 7/8's "2+2+3" phrasing) — null lets beam grouping derive
  /// automatically from [TimeSignature.isCompound] (design doc §26).
  final List<int>? beatGroupPattern;

  /// Space between a barline and the first beat of the measure.
  final double leadingPad;

  /// Space after the last beat before the next barline.
  final double trailingPad;

  NotationLayout({
    required this.timeSignature,
    required this.measureWidth,
    required this.rowHeight,
    required this.measureCount,
    this.measuresPerExercise = 1,
    this.beatGroupPattern,
  })  : assert(measuresPerRow % measuresPerExercise == 0 ||
            measuresPerExercise % measuresPerRow == 0),
        leadingPad = measureWidth * 0.12,
        trailingPad = measureWidth * 0.06;

  int get rowCount => (measureCount / measuresPerRow).ceil();

  double get pageHeight => rowCount * rowHeight;

  int rowOf(int measure) => measure ~/ measuresPerRow;

  int colOf(int measure) => measure % measuresPerRow;

  double measureX(int measure) => colOf(measure) * measureWidth;

  double rowY(int row) => row * rowHeight;

  /// Y of the staff line inside a row (single-line percussion staff).
  double staffY(int row) => rowY(row) + rowHeight * 0.48;

  /// The (0-based, no count-in offset) measure where [exercise] starts.
  int baseMeasureOfExercise(int exercise) => exercise * measuresPerExercise;

  double get _beatSpacing =>
      (measureWidth - leadingPad - trailingPad) / timeSignature.beats;

  /// X of a (possibly fractional) beat inside a measure.
  double beatX(int measure, double beat) =>
      measureX(measure) + leadingPad + beat * _beatSpacing;

  /// Note placements for one exercise (rests excluded — see [restsOf]).
  /// Consecutive eighth AND/OR sixteenth notes with no gap between them are
  /// grouped under one beam ([NotePlacement.beamed] +
  /// [NotePlacement.beamGroupEnd] mark each group) instead of drawing
  /// separate flags. The group size is per-beat by default (design doc
  /// §17) — standard engraving — but widens to per-half-measure whenever
  /// the run contains an accented note (rudiments like the single
  /// paradiddle, "the standard paradiddle in groups of four", design doc
  /// §20). Within a group, any contiguous sub-run of sixteenth notes also
  /// gets a second (inner) beam ([NotePlacement.secondaryBeamed] +
  /// [NotePlacement.secondaryBeamGroupEnd]) — standard engraving for mixed
  /// eighth/sixteenth figures like "two sixteenths + an eighth" (design
  /// doc §21).
  List<NotePlacement> notesOf(Exercise e) {
    final baseMeasure = baseMeasureOfExercise(e.index);
    final raw = <(double x, int row, double beatStart, NoteDuration duration, String sticking, bool isDotted, bool isAccented, bool isTied, bool isTriplet, bool isDuplet, String? countingLabel)>[];
    var beat = 0.0;
    var noteIdx = 0;
    for (var tokenIdx = 0; tokenIdx < e.rhythm.length; tokenIdx++) {
      final token = e.rhythm[tokenIdx];
      if (!token.isRest) {
        final measureWithinExercise = (beat / timeSignature.beats).floor();
        final beatWithinMeasure = beat - measureWithinExercise * timeSignature.beats;
        final globalMeasure = baseMeasure + measureWithinExercise;
        raw.add((
          beatX(globalMeasure, beatWithinMeasure),
          rowOf(globalMeasure),
          beat,
          token.duration,
          token.isStruck ? e.sticking[noteIdx].label : '',
          token.isDotted,
          token.isAccented,
          token.isTied,
          token.isTriplet,
          token.isDuplet,
          e.countingLabels?[tokenIdx],
        ));
        if (token.isStruck) noteIdx++;
      }
      beat += token.lengthInBeats(timeSignature.beatUnit);
    }

    bool isBeamable(NoteDuration d) =>
        d == NoteDuration.eighth ||
        d == NoteDuration.sixteenth ||
        d == NoteDuration.thirtySecond;

    // How many beams a duration needs on its own (eighth=1, sixteenth=2,
    // 32nd=3) — drives how many inner sub-beam levels get computed below.
    int beamLevel(NoteDuration d) => switch (d) {
          NoteDuration.eighth => 1,
          NoteDuration.sixteenth => 2,
          NoteDuration.thirtySecond => 3,
          _ => 0,
        };
    double lengthOf(int idx) {
      final base = timeSignature.beatUnit / raw[idx].$4.denominator;
      final dotted = raw[idx].$6 ? base * 1.5 : base;
      if (raw[idx].$9) return dotted * 2 / 3;
      if (raw[idx].$10) return dotted * 3 / 2;
      return dotted;
    }

    // Triplet bracket/"3" grouping (design doc §27) — independent of beam
    // grouping (a triplet of quarters never beams; a triplet of eighths
    // beams AND gets the "3" mark). Always consumed in fixed groups of 3.
    final tripletGroupEnd = List<bool>.filled(raw.length, false);
    var ti = 0;
    while (ti < raw.length) {
      if (!raw[ti].$9) {
        ti++;
        continue;
      }
      var tEnd = ti;
      while (tEnd + 1 < raw.length && raw[tEnd + 1].$9) {
        tEnd++;
      }
      for (var k = ti; k <= tEnd; k++) {
        if ((k - ti) % 3 == 2) tripletGroupEnd[k] = true;
      }
      ti = tEnd + 1;
    }

    // Duplet bracket/"2" grouping — the triplet grouping's mirror image,
    // consumed in fixed groups of 2 (a duplet pair fills one compound
    // pulse, replacing the natural 3-way split — Vic Firth WebRhythms
    // Lesson 15).
    final dupletGroupEnd = List<bool>.filled(raw.length, false);
    var di = 0;
    while (di < raw.length) {
      if (!raw[di].$10) {
        di++;
        continue;
      }
      var dEnd = di;
      while (dEnd + 1 < raw.length && raw[dEnd + 1].$10) {
        dEnd++;
      }
      for (var k = di; k <= dEnd; k++) {
        if ((k - di) % 2 == 1) dupletGroupEnd[k] = true;
      }
      di = dEnd + 1;
    }

    final beamed = List<bool>.filled(raw.length, false);
    final groupEnd = List<bool>.filled(raw.length, false);
    final secondaryBeamed = List<bool>.filled(raw.length, false);
    final secondaryGroupEnd = List<bool>.filled(raw.length, false);
    final tertiaryBeamed = List<bool>.filled(raw.length, false);
    final tertiaryGroupEnd = List<bool>.filled(raw.length, false);

    // Inner sub-beam pass: contiguous notes needing at least [level] beams
    // (e.g. level 2 = sixteenth-or-shorter, level 3 = 32nd-only) get an
    // extra stacked beam alongside the primary one — standard engraving
    // for mixed-duration figures (design doc §21; 32nd notes need two
    // extra levels, generalizing the same rule).
    void closeSubGroup(int start, int end, int level,
        List<bool> beamedOut, List<bool> groupEndOut) {
      var subStart = start;
      for (var m = start; m <= end; m++) {
        final needsLevel = m < end && beamLevel(raw[m].$4) >= level;
        if (!needsLevel) {
          if (m - subStart >= 2) {
            for (var n = subStart; n < m; n++) {
              beamedOut[n] = true;
            }
            groupEndOut[m - 1] = true;
          }
          subStart = m + 1;
        }
      }
    }

    void closeGroup(int start, int end) {
      // end is exclusive; a group needs >= 2 notes to warrant a beam.
      if (end - start < 2) return;
      for (var m = start; m < end; m++) {
        beamed[m] = true;
      }
      groupEnd[end - 1] = true;

      closeSubGroup(start, end, 2, secondaryBeamed, secondaryGroupEnd);
      closeSubGroup(start, end, 3, tertiaryBeamed, tertiaryGroupEnd);
    }

    var i = 0;
    while (i < raw.length) {
      if (!isBeamable(raw[i].$4)) {
        i++;
        continue;
      }
      // Find the maximal run of back-to-back beamable notes starting at i.
      var j = i;
      while (j + 1 < raw.length &&
          isBeamable(raw[j + 1].$4) &&
          (raw[j + 1].$3 - raw[j].$3 - lengthOf(j)).abs() < 1e-9) {
        j++;
      }
      final hasAccent = raw.sublist(i, j + 1).any((r) => r.$7);
      var groupStart = i;
      final pattern = beatGroupPattern;
      if (pattern != null) {
        // Asymmetric meters (7/8's "2+2+3" etc) have no single derivable
        // grouping — the beams themselves convey the phrasing, so content
        // says which one is in use (design doc §26). Boundaries are
        // absolute beat positions, tiled every measure in case a run ever
        // spans more than one.
        final measureLen = pattern.fold<int>(0, (a, b) => a + b);
        final boundaries = <double>{};
        var base = 0.0;
        while (base < raw[j].$3 + 1) {
          var pos = base;
          for (final g in pattern) {
            pos += g;
            boundaries.add(pos);
          }
          base += measureLen;
        }
        for (var k = i + 1; k <= j; k++) {
          if (boundaries.any((b) => (raw[k].$3 - b).abs() < 1e-9)) {
            closeGroup(groupStart, k);
            groupStart = k;
          }
        }
      } else {
        // Compound meters (6/8, 9/8...) always beam by the 3-numerator-beat
        // compound pulse, accented or not — that's the real grouping unit
        // there, not the numerator's own 1-beat "slots" (which for 6/8 are
        // single eighth notes and would leave everything unbeamed). This
        // also correctly covers 6/8 rudiments like the Double Paradiddle,
        // whose 6-stroke cell matches the compound pulse exactly (design
        // doc §25) — simple-meter accented rudiment runs still beam by
        // "groups of 4 strokes" (2 beats for eighths, design doc §20; no
        // widening for sixteenths, already 1 beat, design doc §22).
        final groupBeats = timeSignature.isCompound
            ? 3.0
            : (hasAccent ? 4 * lengthOf(i) : 1.0);
        for (var k = i + 1; k <= j; k++) {
          if (raw[k].$3 % groupBeats < 1e-9) {
            closeGroup(groupStart, k);
            groupStart = k;
          }
        }
      }
      closeGroup(groupStart, j + 1);
      i = j + 1;
    }

    return [
      for (var i = 0; i < raw.length; i++)
        NotePlacement(
          x: raw[i].$1,
          row: raw[i].$2,
          sticking: raw[i].$5,
          duration: raw[i].$4,
          beamed: beamed[i],
          isDotted: raw[i].$6,
          isAccented: raw[i].$7,
          isTied: raw[i].$8,
          isTriplet: raw[i].$9,
          isDuplet: raw[i].$10,
          beamGroupEnd: groupEnd[i],
          secondaryBeamed: secondaryBeamed[i],
          secondaryBeamGroupEnd: secondaryGroupEnd[i],
          tertiaryBeamed: tertiaryBeamed[i],
          tertiaryBeamGroupEnd: tertiaryGroupEnd[i],
          tripletGroupEnd: tripletGroupEnd[i],
          dupletGroupEnd: dupletGroupEnd[i],
          countingLabel: raw[i].$11,
        ),
    ];
  }

  /// Rest placements for one exercise (Skill 2 onward makes these central,
  /// not decorative — a proper rest glyph is drawn at each position).
  List<RestPlacement> restsOf(Exercise e) {
    final baseMeasure = baseMeasureOfExercise(e.index);
    final placements = <RestPlacement>[];
    var beat = 0.0;
    for (var tokenIdx = 0; tokenIdx < e.rhythm.length; tokenIdx++) {
      final token = e.rhythm[tokenIdx];
      if (token.isRest) {
        final measureWithinExercise = (beat / timeSignature.beats).floor();
        final beatWithinMeasure = beat - measureWithinExercise * timeSignature.beats;
        final globalMeasure = baseMeasure + measureWithinExercise;
        placements.add(RestPlacement(
          x: beatX(globalMeasure, beatWithinMeasure),
          row: rowOf(globalMeasure),
          duration: token.duration,
          countingLabel: e.countingLabels?[tokenIdx],
        ));
      }
      beat += token.lengthInBeats(timeSignature.beatUnit);
    }
    return placements;
  }

  /// Top visible row for a given current exercise, clamped so the viewport
  /// always shows [visibleRows] full rows.
  int topRow(int currentExercise) {
    final maxTop = max(0, rowCount - visibleRows);
    final measure = baseMeasureOfExercise(currentExercise)
        .clamp(0, measureCount - 1);
    return rowOf(measure).clamp(0, maxTop);
  }

  /// Vertical page offset (positive, to be subtracted) for the viewport.
  double scrollY(int currentExercise) => rowY(topRow(currentExercise));

  /// Playhead x for a musical position inside [exercise] — [beatWithFraction]
  /// is relative to [measureWithinExercise] (0-based, see
  /// [TimelinePosition.measureWithinExercise]), not cumulative across the
  /// exercise's measures.
  double playheadX(int exercise, int measureWithinExercise, double beatWithFraction) =>
      beatX(baseMeasureOfExercise(exercise) + measureWithinExercise, beatWithFraction);
}

class NotePlacement {
  final double x;
  final int row;
  final String sticking;
  final NoteDuration duration;

  /// True if this note is part of a beam group — the painter draws a
  /// notehead + manual stem + connecting beam instead of the flagged
  /// combined glyph.
  final bool beamed;

  /// True on the last note of a beam group — tells the painter where to
  /// close the beam it started drawing from the group's first note.
  final bool beamGroupEnd;

  /// True if this note is also part of a contiguous sixteenth-note
  /// sub-run within its beam group — the painter draws a second (inner)
  /// beam alongside the primary one, standard engraving for mixed
  /// eighth/sixteenth figures (design doc §21).
  final bool secondaryBeamed;

  /// True on the last note of a secondary-beam sub-run.
  final bool secondaryBeamGroupEnd;

  /// True if this note is also part of a contiguous 32nd-note sub-run
  /// within its beam group — a third (innermost) beam, stacked below the
  /// secondary one (32nd notes need 3 beams total, design doc §9.3's
  /// "32nd Notes" skill, 2026-07-27).
  final bool tertiaryBeamed;

  /// True on the last note of a tertiary-beam sub-run.
  final bool tertiaryBeamGroupEnd;

  /// True for a dotted note (e.g. dotted quarter) — the painter draws an
  /// augmentation dot glyph after the notehead (design doc §19).
  final bool isDotted;

  /// True for an accented note (e.g. the lead stroke of a paradiddle group)
  /// — the painter draws an accent mark above the notehead (design doc §20).
  final bool isAccented;

  /// True for a note tied FROM the previous note — no new attack, so no
  /// sticking label is drawn; the painter instead draws a curved tie line
  /// back to the previous note (design doc §24).
  final bool isTied;

  /// True for a triplet note — the painter draws a "3" above the group
  /// (plus a bracket when it's not also beamed, e.g. quarter-note
  /// triplets, design doc §27).
  final bool isTriplet;

  /// True on the last note of a triplet group (always a group of 3).
  final bool tripletGroupEnd;

  /// True for a duplet note — the painter draws a "2" above the group
  /// (plus a bracket when it's not also beamed) — the triplet mark's
  /// mirror image, for 2 notes filling one compound pulse instead of 3.
  final bool isDuplet;

  /// True on the last note of a duplet group (always a group of 2).
  final bool dupletGroupEnd;

  /// A counting-syllable label ("1", "&", "e", "trip", ...) to show INSTEAD
  /// of [sticking] — only set on a "How to Count" intro level's exercises
  /// (see [Exercise.countingLabels]). Null everywhere else.
  final String? countingLabel;

  const NotePlacement({
    required this.x,
    required this.row,
    required this.sticking,
    required this.duration,
    this.beamed = false,
    this.beamGroupEnd = false,
    this.secondaryBeamed = false,
    this.secondaryBeamGroupEnd = false,
    this.tertiaryBeamed = false,
    this.tertiaryBeamGroupEnd = false,
    this.isDotted = false,
    this.isAccented = false,
    this.isTied = false,
    this.isTriplet = false,
    this.tripletGroupEnd = false,
    this.isDuplet = false,
    this.dupletGroupEnd = false,
    this.countingLabel,
  });
}

class RestPlacement {
  final double x;
  final int row;
  final NoteDuration duration;

  /// See [NotePlacement.countingLabel] — the silent count under a rest,
  /// only set on a "How to Count" intro level (e.g. Quarter Note Rests').
  final String? countingLabel;

  const RestPlacement({
    required this.x,
    required this.row,
    required this.duration,
    this.countingLabel,
  });
}
