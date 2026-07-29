import 'package:flutter_test/flutter_test.dart';
import 'package:one_pad/domain/model/exercise.dart';
import 'package:one_pad/domain/model/note_token.dart';
import 'package:one_pad/domain/model/sticking.dart';
import 'package:one_pad/domain/model/time_signature.dart';

void main() {
  group('ExerciseTemplate multi-measure support (design doc §23)', () {
    ExerciseTemplate template(List<String> rhythmCodes) => ExerciseTemplate(
          id: 't',
          rhythm: rhythmCodes.map(NoteToken.parse).toList(),
          sticking: List.filled(
              rhythmCodes.where((c) => !c.startsWith('r')).length, Hand.right),
          difficulty: 1,
        );

    test('a single-measure template validates and reports measureCount 1',
        () {
      final t = template(['q', 'q', 'q', 'q']);
      expect(() => t.validateAgainst(TimeSignature.fourFour), returnsNormally);
      expect(t.measureCountFor(TimeSignature.fourFour), 1);
    });

    test('a 2-measure template (e.g. Triple Paradiddle at 8th-note speed) '
        'validates and reports measureCount 2', () {
      final t = template(List.filled(16, 'e'));
      expect(() => t.validateAgainst(TimeSignature.fourFour), returnsNormally);
      expect(t.measureCountFor(TimeSignature.fourFour), 2);
    });

    test('a template that is not a whole number of measures is rejected',
        () {
      final t = template(['q', 'q', 'q']); // 3 beats, not a multiple of 4
      expect(() => t.validateAgainst(TimeSignature.fourFour),
          throwsArgumentError);
    });
  });

  group('Exercise.fromTemplate snapshots measureCount', () {
    test('measureCount matches the template\'s length in measures', () {
      final t = ExerciseTemplate(
        id: 't',
        rhythm: List.filled(16, NoteToken.parse('e')),
        sticking: List.filled(16, Hand.right),
        difficulty: 1,
      );
      final e = Exercise.fromTemplate(t, 0, TimeSignature.fourFour);
      expect(e.measureCount, 2);
    });
  });

  group('ExerciseTemplate ties (design doc §24)', () {
    test('a tied token needs no sticking entry, same as a rest', () {
      // q, q~ (tied, no new attack), q, q -> only 3 struck notes.
      final t = ExerciseTemplate(
        id: 't',
        rhythm: ['q', 'q~', 'q', 'q'].map(NoteToken.parse).toList(),
        sticking: [Hand.right, Hand.left, Hand.right],
        difficulty: 1,
      );
      expect(() => t.validateAgainst(TimeSignature.fourFour), returnsNormally);
    });

    test('a sticking list that (wrongly) includes an entry for a tied '
        'token is rejected', () {
      expect(
        () => ExerciseTemplate(
          id: 't',
          rhythm: ['q', 'q~', 'q', 'q'].map(NoteToken.parse).toList(),
          sticking: [Hand.right, Hand.left, Hand.right, Hand.left],
          difficulty: 1,
        ),
        throwsArgumentError,
      );
    });
  });
}
