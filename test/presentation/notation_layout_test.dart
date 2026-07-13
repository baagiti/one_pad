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

  Exercise exercise(int index, {List<String>? rhythm, List<Hand>? sticking}) =>
      Exercise(
        templateId: 't',
        rhythm: (rhythm ?? ['q', 'q', 'q', 'q']).map(NoteToken.parse).toList(),
        sticking: sticking ??
            const [Hand.right, Hand.left, Hand.right, Hand.left],
        index: index,
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

  test('rests occupy time but produce no placement', () {
    final notes = layout.notesOf(exercise(0,
        rhythm: ['q', 'rq', 'q', 'rq'],
        sticking: const [Hand.right, Hand.left]));
    expect(notes, hasLength(2));
    // second note lands on beat 2 (third beat)
    expect(notes[1].x, closeTo(layout.beatX(0, 2), 1e-9));
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
    final start = layout.playheadX(3, 0);
    final end = layout.playheadX(3, 3.999);
    expect(start, greaterThanOrEqualTo(layout.measureX(3)));
    expect(end, lessThan(layout.measureX(3) + 200));
    expect(end, greaterThan(start));
  });
}
