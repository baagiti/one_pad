import 'package:flutter_test/flutter_test.dart';
import 'package:one_pad/domain/model/note_token.dart';

void main() {
  group('NoteToken.parse', () {
    test('parses plain notes', () {
      final q = NoteToken.parse('q');
      expect(q.duration, NoteDuration.quarter);
      expect(q.isRest, isFalse);
      expect(q.isDotted, isFalse);
    });

    test('parses 32nd notes (2026-07-27 addition)', () {
      final x = NoteToken.parse('x');
      expect(x.duration, NoteDuration.thirtySecond);
      expect(x.isRest, isFalse);
    });

    test('parses rests and dots', () {
      final rq = NoteToken.parse('rq');
      expect(rq.isRest, isTrue);
      expect(rq.duration, NoteDuration.quarter);

      final dottedHalf = NoteToken.parse('h.');
      expect(dottedHalf.isDotted, isTrue);
      expect(dottedHalf.duration, NoteDuration.half);

      final dottedEighthRest = NoteToken.parse('re.');
      expect(dottedEighthRest.isRest, isTrue);
      expect(dottedEighthRest.isDotted, isTrue);
    });

    test('parses accents (Skill 6: paradiddle lead-stroke accents)', () {
      final accentedEighth = NoteToken.parse('e>');
      expect(accentedEighth.isAccented, isTrue);
      expect(accentedEighth.duration, NoteDuration.eighth);
      expect(accentedEighth.isDotted, isFalse);

      final plainEighth = NoteToken.parse('e');
      expect(plainEighth.isAccented, isFalse);

      final dottedAccented = NoteToken.parse('q.>');
      expect(dottedAccented.isDotted, isTrue);
      expect(dottedAccented.isAccented, isTrue);
    });

    test('parses ties (Skill 9: a note tied from the previous one)', () {
      final tiedQuarter = NoteToken.parse('q~');
      expect(tiedQuarter.isTied, isTrue);
      expect(tiedQuarter.duration, NoteDuration.quarter);
      expect(tiedQuarter.isDotted, isFalse);

      final plainQuarter = NoteToken.parse('q');
      expect(plainQuarter.isTied, isFalse);

      final dottedTied = NoteToken.parse('q.~');
      expect(dottedTied.isDotted, isTrue);
      expect(dottedTied.isTied, isTrue);
    });

    test('isStruck is false for rests and tied notes, true otherwise', () {
      expect(NoteToken.parse('q').isStruck, isTrue);
      expect(NoteToken.parse('rq').isStruck, isFalse);
      expect(NoteToken.parse('q~').isStruck, isFalse);
    });

    test('parses triplets (Skill 12: "3 in the time of 2")', () {
      final tripletEighth = NoteToken.parse('et');
      expect(tripletEighth.isTriplet, isTrue);
      expect(tripletEighth.duration, NoteDuration.eighth);

      final plainEighth = NoteToken.parse('e');
      expect(plainEighth.isTriplet, isFalse);

      final tripletQuarter = NoteToken.parse('qt');
      expect(tripletQuarter.isTriplet, isTrue);
      expect(tripletQuarter.duration, NoteDuration.quarter);
    });

    test('parses duplets — the triplet\'s mirror image, "2 in the time of '
        '3" (only meaningful in compound meter)', () {
      final dupletEighth = NoteToken.parse('ed');
      expect(dupletEighth.isDuplet, isTrue);
      expect(dupletEighth.isTriplet, isFalse);
      expect(dupletEighth.duration, NoteDuration.eighth);

      final plainEighth = NoteToken.parse('e');
      expect(plainEighth.isDuplet, isFalse);
    });

    test('rejects unknown codes', () {
      expect(() => NoteToken.parse('z'), throwsFormatException);
    });

    test('round-trips through code', () {
      for (final code in [
        'w', 'h', 'q', 'e', 's', 'x', 'rq', 'q.', 'rh.', 'e>', 'q.>', 'q~',
        'q.~', 'et', 'qt', 'ed',
      ]) {
        expect(NoteToken.parse(code).code, code);
      }
    });
  });

  group('lengthInBeats', () {
    test('quarter note is one beat in x/4 meters', () {
      expect(NoteToken.parse('q').lengthInBeats(4), 1.0);
    });

    test('eighth note is one beat in x/8 meters', () {
      expect(NoteToken.parse('e').lengthInBeats(8), 1.0);
    });

    test('dotted quarter is 1.5 beats in x/4', () {
      expect(NoteToken.parse('q.').lengthInBeats(4), 1.5);
    });

    test('half note is 2 beats in x/4', () {
      expect(NoteToken.parse('h').lengthInBeats(4), 2.0);
    });

    test('8 thirty-second notes sum to exactly 1 quarter beat (x/4) — '
        'the next hand-speed doubling after sixteenths', () {
      final x = NoteToken.parse('x').lengthInBeats(4);
      expect(x, 0.125);
      expect(x * 8, 1.0);
    });

    test('3 eighth-note triplets sum to exactly 1 beat (the space of 2 '
        'plain eighths) — design doc §27', () {
      // beatUnit 4 (x/4 meter): a plain eighth is 0.5 beat, so 2 of them
      // (the space the triplet fills) is 1 beat.
      final t = NoteToken.parse('et').lengthInBeats(4);
      expect(t, closeTo(1 / 3, 1e-12));
      expect(t * 3, closeTo(1.0, 1e-12));
    });

    test('3 quarter-note triplets sum to exactly 2 beats (the space of 2 '
        'plain quarters)', () {
      final t = NoteToken.parse('qt').lengthInBeats(4);
      expect(t, closeTo(2 / 3, 1e-12));
      expect(t * 3, closeTo(2.0, 1e-12));
    });

    test('2 duplet eighths in 6/8 sum to exactly one compound pulse (the '
        'space 3 plain eighths would normally take)', () {
      // beatUnit 8 (x/8 meter): a plain eighth is 1 beat-unit, so 3 of
      // them (the compound pulse the duplet replaces) is 3 beat-units.
      final d = NoteToken.parse('ed').lengthInBeats(8);
      expect(d, closeTo(1.5, 1e-12));
      expect(d * 2, closeTo(3.0, 1e-12));
    });
  });
}
