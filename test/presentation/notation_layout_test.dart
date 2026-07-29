import 'package:flutter_test/flutter_test.dart';
import 'package:one_pad/domain/model/exercise.dart';
import 'package:one_pad/domain/model/note_token.dart';
import 'package:one_pad/domain/model/sticking.dart';
import 'package:one_pad/domain/model/time_signature.dart';
import 'package:one_pad/presentation/notation/notation_layout.dart';

void main() {
  // 16 measures, 2 per row -> 8 rows; viewport shows 2 rows.
  final layout = NotationLayout(
    timeSignature: TimeSignature.fourFour,
    measureWidth: 200,
    rowHeight: 100,
    measureCount: 16,
  );

  Exercise exercise(int index,
          {List<String>? rhythm,
          List<Hand>? sticking,
          List<String>? countingLabels}) =>
      Exercise(
        templateId: 't',
        rhythm: (rhythm ?? ['q', 'q', 'q', 'q']).map(NoteToken.parse).toList(),
        sticking: sticking ??
            const [Hand.right, Hand.left, Hand.right, Hand.left],
        index: index,
        countingLabels: countingLabels,
      );

  test('grid: 16 measures form 8 rows of 2', () {
    expect(layout.rowCount, 8);
    expect(layout.rowOf(0), 0);
    expect(layout.colOf(0), 0);
    expect(layout.rowOf(1), 0);
    expect(layout.colOf(1), 1);
    expect(layout.rowOf(15), 7);
    expect(layout.colOf(15), 1);
    expect(layout.measureX(2), 0); // new row starts at left edge
    expect(layout.measureX(3), 200);
  });

  test('four quarter notes are evenly spaced inside the measure', () {
    final notes = layout.notesOf(exercise(0));
    expect(notes, hasLength(4));
    final gaps = [
      for (var i = 1; i < 4; i++) notes[i].x - notes[i - 1].x,
    ];
    expect(gaps.toSet(), hasLength(1)); // equal spacing
    expect(notes.first.x, greaterThan(0));
    expect(notes.last.x, lessThan(200));
  });

  test('same column in different rows lands on identical x positions', () {
    final m0 = layout.notesOf(exercise(0)); // row 0, col 0
    final m4 = layout.notesOf(exercise(4)); // row 2, col 0
    for (var i = 0; i < 4; i++) {
      expect(m4[i].x, closeTo(m0[i].x, 1e-9));
      expect(m4[i].row, 2);
    }
  });

  test('sticking labels follow the exercise', () {
    final notes = layout.notesOf(exercise(0,
        sticking: const [Hand.right, Hand.right, Hand.right, Hand.left]));
    expect(notes.map((n) => n.sticking), ['R', 'R', 'R', 'L']);
  });

  test('rests occupy time but produce no note placement', () {
    final notes = layout.notesOf(exercise(0,
        rhythm: ['q', 'rq', 'q', 'rq'],
        sticking: const [Hand.right, Hand.left]));
    expect(notes, hasLength(2));
    // second note lands on beat 2 (third beat)
    expect(notes[1].x, closeTo(layout.beatX(0, 2), 1e-9));
  });

  test('restsOf places a rest glyph at each rest position', () {
    final rests = layout.restsOf(exercise(0,
        rhythm: ['q', 'rq', 'q', 'rq'],
        sticking: const [Hand.right, Hand.left]));
    expect(rests, hasLength(2));
    expect(rests[0].x, closeTo(layout.beatX(0, 1), 1e-9));
    expect(rests[1].x, closeTo(layout.beatX(0, 3), 1e-9));
    expect(rests.every((r) => r.duration == NoteDuration.quarter), isTrue);
  });

  test('notesOf carries the note duration through', () {
    final notes = layout.notesOf(exercise(0));
    expect(notes.every((n) => n.duration == NoteDuration.quarter), isTrue);
  });

  test('an eighth-note pair within one beat is marked beamed', () {
    // beat1 = two eighths, beats 2-4 = quarters (Skill 3 Level 1 shape).
    final notes = layout.notesOf(exercise(0,
        rhythm: ['e', 'e', 'q', 'q', 'q'],
        sticking: const [
          Hand.right,
          Hand.left,
          Hand.right,
          Hand.right,
          Hand.right
        ]));
    expect(notes, hasLength(5));
    expect(notes[0].beamed, isTrue);
    expect(notes[1].beamed, isTrue);
    expect(notes.skip(2).every((n) => !n.beamed), isTrue,
        reason: 'plain quarters never beam');
  });

  test(
      'an offbeat note (rest then single eighth) is NOT beamed — its rest '
      'partner is filtered out, so it renders as a lone flagged note',
      () {
    final notes = layout.notesOf(exercise(0,
        rhythm: ['re', 'e', 'e', 'e', 'q', 'q'],
        sticking: const [
          Hand.right,
          Hand.left,
          Hand.right,
          Hand.left,
          Hand.right
        ]));
    expect(notes[0].beamed, isFalse, reason: 'the "and" note of beat 1');
    expect(notes[1].beamed, isTrue); // beat 2's plain pair still beams
    expect(notes[2].beamed, isTrue);
  });

  test('eighth-note pairs split across two beats do NOT beam together', () {
    // beat2's second eighth and beat3's first eighth are adjacent in time
    // but belong to different beats — no beam across the beat boundary.
    final notes = layout.notesOf(exercise(0,
        rhythm: ['q', 'e', 'e', 'e', 'e', 'q'],
        sticking: const [
          Hand.right,
          Hand.left,
          Hand.right,
          Hand.left,
          Hand.right,
          Hand.right
        ]));
    // notes: [Q, E(beat2,a), E(beat2,b), E(beat3,a), E(beat3,b), Q]
    expect(notes[0].beamed, isFalse); // quarter
    expect(notes[1].beamed, isTrue); // beat2 pair
    expect(notes[2].beamed, isTrue);
    expect(notes[3].beamed, isTrue); // beat3 pair
    expect(notes[4].beamed, isTrue);
    expect(notes[5].beamed, isFalse); // quarter
  });

  test('notesOf carries isDotted through (Skill 5: dotted quarter + eighth)',
      () {
    final notes = layout.notesOf(exercise(0,
        rhythm: ['q.', 'e', 'q', 'q'],
        sticking: const [
          Hand.right,
          Hand.left,
          Hand.right,
          Hand.left,
        ]));
    expect(notes, hasLength(4));
    expect(notes[0].isDotted, isTrue);
    expect(notes.skip(1).every((n) => !n.isDotted), isTrue,
        reason: 'only the dotted quarter itself is marked dotted');
  });

  test('notesOf carries isAccented through (Skill 6: paradiddle accents)',
      () {
    final notes = layout.notesOf(exercise(0,
        rhythm: ['e>', 'e', 'e', 'e>'],
        sticking: const [
          Hand.right,
          Hand.left,
          Hand.right,
          Hand.right,
        ]));
    expect(notes, hasLength(4));
    expect(notes[0].isAccented, isTrue);
    expect(notes[3].isAccented, isTrue);
    expect(notes[1].isAccented, isFalse);
    expect(notes[2].isAccented, isFalse);
  });

  test(
      'an accented run beams by half-measure (groups of 4), not by beat — '
      'standard paradiddle engraving (Skill 6, design doc §20)', () {
    // R L R R | L R L L, accent on note 0 and note 4 (paradiddle shape).
    final notes = layout.notesOf(exercise(0,
        rhythm: ['e>', 'e', 'e', 'e', 'e>', 'e', 'e', 'e'],
        sticking: const [
          Hand.right,
          Hand.left,
          Hand.right,
          Hand.right,
          Hand.left,
          Hand.right,
          Hand.left,
          Hand.left,
        ]));
    expect(notes, hasLength(8));
    expect(notes.every((n) => n.beamed), isTrue,
        reason: 'the whole accented run beams');
    // Group closes only at index 3 (end of the first 4-note group) and
    // index 7 (end of the measure) — NOT at index 1 or 5, which is where
    // a plain per-beat grouping would have closed it.
    final groupEnds = [
      for (var i = 0; i < notes.length; i++)
        if (notes[i].beamGroupEnd) i,
    ];
    expect(groupEnds, [3, 7]);
  });

  test(
      'a run with no accents still beams by single beat (pairs) — '
      'unchanged from the original per-beat convention', () {
    final notes = layout.notesOf(exercise(0,
        rhythm: ['e', 'e', 'e', 'e', 'e', 'e', 'e', 'e'],
        sticking: const [
          Hand.right,
          Hand.left,
          Hand.right,
          Hand.left,
          Hand.right,
          Hand.left,
          Hand.right,
          Hand.left,
        ]));
    final groupEnds = [
      for (var i = 0; i < notes.length; i++)
        if (notes[i].beamGroupEnd) i,
    ];
    expect(groupEnds, [1, 3, 5, 7]);
  });

  test('a full sixteenth-note group (4 notes in one beat) beams together '
      'with an inner double-beam spanning all 4 (Skill 7, design doc §21)',
      () {
    // beat1 = s,s,s,s; beats 2-4 = quarters (Skill 7 Level 1 shape).
    final notes = layout.notesOf(exercise(0,
        rhythm: ['s', 's', 's', 's', 'q', 'q', 'q'],
        sticking: const [
          Hand.right,
          Hand.left,
          Hand.right,
          Hand.left,
          Hand.right,
          Hand.left,
          Hand.right,
        ]));
    expect(notes.take(4).every((n) => n.beamed), isTrue);
    expect(notes[3].beamGroupEnd, isTrue);
    expect(notes.take(4).every((n) => n.secondaryBeamed), isTrue);
    expect(notes[3].secondaryBeamGroupEnd, isTrue);
    expect(notes.skip(4).every((n) => !n.beamed), isTrue,
        reason: 'plain quarters never beam');
  });

  test(
      'two sixteenths + an eighth (Skill 7 Level 2): the whole beat beams '
      'together, but only the two sixteenths get the inner double-beam',
      () {
    final notes = layout.notesOf(exercise(0,
        rhythm: ['s', 's', 'e', 'e', 'e', 'q', 'q'],
        sticking: const [
          Hand.right,
          Hand.left,
          Hand.right,
          Hand.left,
          Hand.right,
          Hand.left,
          Hand.right,
        ]));
    expect(notes.take(3).every((n) => n.beamed), isTrue,
        reason: 'all 3 notes of the beat share the primary beam');
    expect(notes[2].beamGroupEnd, isTrue);
    expect(notes[0].secondaryBeamed, isTrue);
    expect(notes[1].secondaryBeamed, isTrue);
    expect(notes[1].secondaryBeamGroupEnd, isTrue);
    expect(notes[2].secondaryBeamed, isFalse,
        reason: 'the eighth note is not part of the sixteenth sub-run');
  });

  test(
      'an eighth + two sixteenths (Skill 7 Level 3): inner double-beam '
      'covers only the trailing two sixteenths', () {
    final notes = layout.notesOf(exercise(0,
        rhythm: ['e', 's', 's', 'e', 'e', 'q', 'q'],
        sticking: const [
          Hand.right,
          Hand.left,
          Hand.right,
          Hand.left,
          Hand.right,
          Hand.left,
          Hand.right,
        ]));
    expect(notes.take(3).every((n) => n.beamed), isTrue);
    expect(notes[0].secondaryBeamed, isFalse);
    expect(notes[1].secondaryBeamed, isTrue);
    expect(notes[2].secondaryBeamed, isTrue);
    expect(notes[2].secondaryBeamGroupEnd, isTrue);
  });

  test(
      'an accented run of SIXTEENTH notes still beams by single beat '
      '(groups of 4) even when the accent spacing is 2 beats apart — '
      'unlike eighth notes, 4 strokes is already one beat at sixteenth '
      'density (design doc §22, confirmed against reference engraving for '
      'the triple paradiddle)', () {
    // Simulates a 16th-note "triple paradiddle" measure: accents on note 0
    // and note 8 (every 2 beats), but the correct beaming is 4 groups of 4,
    // not 2 groups of 8.
    final rhythm = [
      's>', 's', 's', 's', 's', 's', 's', 's',
      's>', 's', 's', 's', 's', 's', 's', 's',
    ];
    final sticking = List.generate(16, (i) => i.isEven ? Hand.right : Hand.left);
    final notes = layout.notesOf(exercise(0, rhythm: rhythm, sticking: sticking));
    expect(notes, hasLength(16));
    expect(notes.every((n) => n.beamed), isTrue);
    final groupEnds = [
      for (var i = 0; i < notes.length; i++)
        if (notes[i].beamGroupEnd) i,
    ];
    expect(groupEnds, [3, 7, 11, 15]);
  });

  test('a full beat of 8 thirty-second notes gets all three beam levels '
      '(design doc §9.3, 2026-07-27 addition)', () {
    final rhythm = ['x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'q', 'q', 'q'];
    final sticking =
        List.generate(11, (i) => i.isEven ? Hand.right : Hand.left);
    final notes = layout.notesOf(exercise(0, rhythm: rhythm, sticking: sticking));
    expect(notes.take(8).every((n) => n.beamed), isTrue);
    expect(notes[7].beamGroupEnd, isTrue);
    expect(notes.take(8).every((n) => n.secondaryBeamed), isTrue);
    expect(notes[7].secondaryBeamGroupEnd, isTrue);
    expect(notes.take(8).every((n) => n.tertiaryBeamed), isTrue);
    expect(notes[7].tertiaryBeamGroupEnd, isTrue);
    expect(notes.skip(8).every((n) => !n.beamed), isTrue,
        reason: 'plain quarters never beam');
  });

  test('two sixteenths + four thirty-seconds: the third (innermost) beam '
      'covers only the 32nd-note sub-run, not the sixteenths', () {
    final rhythm = ['s', 's', 'x', 'x', 'x', 'x', 'q', 'q', 'q'];
    final sticking =
        List.generate(9, (i) => i.isEven ? Hand.right : Hand.left);
    final notes = layout.notesOf(exercise(0, rhythm: rhythm, sticking: sticking));
    expect(notes.take(6).every((n) => n.beamed), isTrue,
        reason: 'all 6 notes of the beat share the primary beam');
    expect(notes.take(6).every((n) => n.secondaryBeamed), isTrue,
        reason: 'sixteenths AND 32nds both need the secondary beam');
    expect(notes[0].tertiaryBeamed, isFalse);
    expect(notes[1].tertiaryBeamed, isFalse);
    expect(notes.sublist(2, 6).every((n) => n.tertiaryBeamed), isTrue);
    expect(notes[5].tertiaryBeamGroupEnd, isTrue);
  });

  test('notesOf carries isTied through and skips sticking for the tied '
      'note (Skill 9: a note held across beat 3, design doc §24)', () {
    final notes = layout.notesOf(exercise(0,
        rhythm: ['e', 'e', 'e', 'e', 'q~', 'e', 'e'],
        sticking: const [
          Hand.right,
          Hand.left,
          Hand.right,
          Hand.left,
          Hand.right,
          Hand.left,
        ]));
    expect(notes, hasLength(7));
    expect(notes[4].isTied, isTrue);
    expect(notes[4].sticking, isEmpty,
        reason: 'a tied note has no new attack, so no hand to show');
    expect(notes.where((n) => n.isTied), hasLength(1));
    // the struck note right after the tie continues the alternation
    // (R,L,R,L, [tie skipped], R,L) rather than repeating the tied hand.
    expect(notes[3].sticking, 'L');
    expect(notes[5].sticking, 'R');
  });

  test('a "How to Count" intro level\'s countingLabel shows on notesOf '
      '(replacing sticking) AND restsOf, indexed per TOKEN not per struck '
      'note (2026-07-27 addition)', () {
    final notes = layout.notesOf(exercise(0,
        rhythm: ['e', 're', 'e', 're', 'e', 're', 'e', 're'],
        sticking: const [Hand.right, Hand.left, Hand.right, Hand.left],
        countingLabels: ['1', '&', '2', '&', '3', '&', '4', '&']));
    expect(notes, hasLength(4));
    expect(notes.map((n) => n.countingLabel), ['1', '2', '3', '4']);

    final rests = layout.restsOf(exercise(0,
        rhythm: ['e', 're', 'e', 're', 'e', 're', 'e', 're'],
        sticking: const [Hand.right, Hand.left, Hand.right, Hand.left],
        countingLabels: ['1', '&', '2', '&', '3', '&', '4', '&']));
    expect(rests, hasLength(4));
    expect(rests.map((r) => r.countingLabel), ['&', '&', '&', '&']);
  });

  test('active row is the top row, clamped at the last window', () {
    expect(layout.topRow(0), 0);
    expect(layout.topRow(1), 0); // second measure of row 0
    expect(layout.topRow(2), 1); // row 1 becomes top
    expect(layout.topRow(11), 5);
    // rows 6..7 are the final window: row 6 stays on top through the end
    expect(layout.topRow(12), 6);
    expect(layout.topRow(14), 6);
    expect(layout.topRow(15), 6);
    expect(layout.scrollY(4), 2 * 100);
  });

  test('playhead spans the measure as beats advance', () {
    final start = layout.playheadX(3, 0, 0);
    final end = layout.playheadX(3, 0, 3.999);
    expect(start, greaterThanOrEqualTo(layout.measureX(3)));
    expect(end, lessThan(layout.measureX(3) + 200));
    expect(end, greaterThan(start));
  });

  group('measuresPerExercise = 2 (design doc §23, multi-measure rudiments '
      "like the Triple Paradiddle that don't fit one measure)", () {
    // 8 exercises * 2 measures = 16 measures, same page size as above.
    final layout2 = NotationLayout(
      timeSignature: TimeSignature.fourFour,
      measureWidth: 200,
      rowHeight: 100,
      measureCount: 16,
      measuresPerExercise: 2,
    );

    Exercise twoMeasureExercise(int index) => Exercise(
          templateId: 't2',
          rhythm: List.filled(8, NoteToken.parse('q')),
          sticking: List.generate(
              8, (i) => i.isEven ? Hand.right : Hand.left),
          index: index,
          measureCount: 2,
        );

    test('notesOf spreads a 2-measure exercise across 2 measure columns',
        () {
      final notes = layout2.notesOf(twoMeasureExercise(0));
      expect(notes, hasLength(8));
      // First 4 notes (measure 0 of the exercise) land in column 0...
      for (final n in notes.take(4)) {
        expect(n.x, lessThan(layout2.measureX(1)));
      }
      // ...the next 4 (measure 1 of the exercise) land in column 1.
      for (final n in notes.skip(4)) {
        expect(n.x, greaterThanOrEqualTo(layout2.measureX(1)));
      }
      expect(notes.every((n) => n.row == 0), isTrue,
          reason: 'exercise 0 always fits entirely in row 0');
    });

    test('exercise 1 starts right after exercise 0\'s 2 measures', () {
      final notes = layout2.notesOf(twoMeasureExercise(1));
      expect(notes.first.x, closeTo(layout2.beatX(2, 0), 1e-9));
      expect(notes.first.row, 1); // measures 2-3 -> row 1
    });

    test('topRow/scrollY anchor on the exercise\'s own row', () {
      expect(layout2.topRow(0), 0);
      expect(layout2.topRow(1), 1);
      expect(layout2.scrollY(1), 100);
    });

    test('playheadX resolves the correct measure column via '
        'measureWithinExercise', () {
      final firstMeasureX = layout2.playheadX(0, 0, 0);
      final secondMeasureX = layout2.playheadX(0, 1, 0);
      expect(firstMeasureX, closeTo(layout2.beatX(0, 0), 1e-9));
      expect(secondMeasureX, closeTo(layout2.beatX(1, 0), 1e-9));
    });
  });

  group('compound meter (6/8) beaming (design doc §25)', () {
    test('TimeSignature.isCompound identifies 6/8, 9/8... but not 3/4 or 4/4',
        () {
      expect(const TimeSignature(6, 8).isCompound, isTrue);
      expect(const TimeSignature(9, 8).isCompound, isTrue);
      expect(const TimeSignature(3, 4).isCompound, isFalse);
      expect(TimeSignature.fourFour.isCompound, isFalse);
    });

    final layout68 = NotationLayout(
      timeSignature: const TimeSignature(6, 8),
      measureWidth: 200,
      rowHeight: 100,
      measureCount: 16,
    );

    Exercise exercise68(List<String> rhythm, List<Hand> sticking) => Exercise(
          templateId: 't68',
          rhythm: rhythm.map(NoteToken.parse).toList(),
          sticking: sticking,
          index: 0,
        );

    test('a full eighth-note stream beams in two groups of 3 (the '
        'compound pulse), not one giant beam or per-numerator-beat pairs',
        () {
      final notes = layout68.notesOf(exercise68(
        List.filled(6, 'e'),
        const [
          Hand.right,
          Hand.left,
          Hand.right,
          Hand.left,
          Hand.right,
          Hand.left
        ],
      ));
      expect(notes.every((n) => n.beamed), isTrue);
      final groupEnds = [
        for (var i = 0; i < notes.length; i++)
          if (notes[i].beamGroupEnd) i,
      ];
      expect(groupEnds, [2, 5]);
    });

    test('Double Paradiddle (12 sixteenths) beams in two groups of 6 — its '
        'own accent-cell size happens to match the compound pulse exactly',
        () {
      final rhythm = [
        's>', 's', 's', 's', 's', 's',
        's>', 's', 's', 's', 's', 's',
      ];
      final sticking = List.generate(
          12, (i) => i.isEven ? Hand.right : Hand.left);
      final notes = layout68.notesOf(exercise68(rhythm, sticking));
      expect(notes.every((n) => n.beamed), isTrue);
      final groupEnds = [
        for (var i = 0; i < notes.length; i++)
          if (notes[i].beamGroupEnd) i,
      ];
      expect(groupEnds, [5, 11]);
    });

    test('a duplet pair (2 notes filling one compound pulse) beams as its '
        'own group and is marked isDuplet, independent of the plain eighth '
        'stream filling the other pulse (2026-07-27 addition)', () {
      final notes = layout68.notesOf(exercise68(
        ['ed', 'ed', 'e', 'e', 'e'],
        const [Hand.right, Hand.left, Hand.right, Hand.left, Hand.right],
      ));
      expect(notes, hasLength(5));
      expect(notes[0].isDuplet, isTrue);
      expect(notes[1].isDuplet, isTrue);
      expect(notes.skip(2).every((n) => !n.isDuplet), isTrue);
      expect(notes[0].dupletGroupEnd, isFalse);
      expect(notes[1].dupletGroupEnd, isTrue);

      // Each compound pulse still gets its own beam group: the duplet
      // pair together, then the 3 plain eighths together.
      expect(notes.every((n) => n.beamed), isTrue);
      final groupEnds = [
        for (var i = 0; i < notes.length; i++)
          if (notes[i].beamGroupEnd) i,
      ];
      expect(groupEnds, [1, 4]);
    });
  });

  group('explicit beatGroupPattern (7/8 "2+2+3", design doc §26)', () {
    final layout78 = NotationLayout(
      timeSignature: const TimeSignature(7, 8),
      measureWidth: 200,
      rowHeight: 100,
      measureCount: 16,
      beatGroupPattern: const [2, 2, 3],
    );

    test('a full eighth-note stream beams as 2+2+3, not by the compound '
        'default (which would be wrong here — 7 is not evenly divisible '
        'by 3) nor by single-beat pairs', () {
      final notes = layout78.notesOf(Exercise(
        templateId: 't78',
        rhythm: List.filled(7, 'e').map(NoteToken.parse).toList(),
        sticking: List.generate(
            7, (i) => i.isEven ? Hand.right : Hand.left),
        index: 0,
      ));
      expect(notes.every((n) => n.beamed), isTrue);
      final groupEnds = [
        for (var i = 0; i < notes.length; i++)
          if (notes[i].beamGroupEnd) i,
      ];
      expect(groupEnds, [1, 3, 6]); // groups of 2, 2, 3 notes
    });
  });

  group('triplets (design doc §27)', () {
    test('3 eighth-note triplets are beamed (eighth duration is beamable) '
        'AND marked as one triplet group', () {
      final notes = layout.notesOf(exercise(0,
          rhythm: ['et', 'et', 'et', 'q', 'q', 'q'],
          sticking: const [
            Hand.right,
            Hand.left,
            Hand.right,
            Hand.left,
            Hand.right,
            Hand.left,
          ]));
      expect(notes.take(3).every((n) => n.beamed), isTrue,
          reason: 'eighth triplets are eighth-duration, so they beam too');
      expect(notes.take(3).every((n) => n.isTriplet), isTrue);
      expect(notes[0].tripletGroupEnd, isFalse);
      expect(notes[1].tripletGroupEnd, isFalse);
      expect(notes[2].tripletGroupEnd, isTrue);
      expect(notes.skip(3).every((n) => !n.isTriplet), isTrue);
    });

    test('3 quarter-note triplets are marked as a triplet group but NEVER '
        'beamed (quarter notes never beam)', () {
      // 3 quarter-triplets = 2 beats, + 2 plain quarters = 4 beats total.
      final notes = layout.notesOf(exercise(0,
          rhythm: ['qt', 'qt', 'qt', 'q', 'q'],
          sticking: const [
            Hand.right,
            Hand.left,
            Hand.right,
            Hand.left,
            Hand.right,
          ]));
      expect(notes.take(3).every((n) => n.isTriplet), isTrue);
      expect(notes.take(3).every((n) => !n.beamed), isTrue,
          reason: 'quarter notes never beam, triplet or not');
      expect(notes[2].tripletGroupEnd, isTrue);
    });

    test('a full beat of 6 sixteenth-note triplets (sextuplet, Skill '
        '"Triplets" Level 3) beams as one beat group but splits into TWO '
        'triplet-of-3 brackets', () {
      final notes = layout.notesOf(exercise(0,
          rhythm: ['st', 'st', 'st', 'st', 'st', 'st', 'q', 'q', 'q'],
          sticking: const [
            Hand.right,
            Hand.left,
            Hand.right,
            Hand.left,
            Hand.right,
            Hand.left,
            Hand.right,
            Hand.left,
            Hand.right,
          ]));
      expect(notes.take(6).every((n) => n.isTriplet), isTrue);
      expect(notes.take(6).every((n) => n.beamed), isTrue,
          reason: 'sixteenth-triplets are sixteenth-duration, so they beam');
      // Triplet grouping is fixed runs of 3, independent of beam grouping:
      // two brackets, not one "6".
      expect(notes[2].tripletGroupEnd, isTrue);
      expect(notes[5].tripletGroupEnd, isTrue);
      for (final i in [0, 1, 3, 4]) {
        expect(notes[i].tripletGroupEnd, isFalse, reason: 'index $i');
      }
      expect(notes.skip(6).every((n) => !n.isTriplet), isTrue);
    });
  });
}
