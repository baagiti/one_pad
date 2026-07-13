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

    test('rejects unknown codes', () {
      expect(() => NoteToken.parse('x'), throwsFormatException);
    });

    test('round-trips through code', () {
      for (final code in ['w', 'h', 'q', 'e', 's', 'rq', 'q.', 'rh.']) {
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
  });
}
