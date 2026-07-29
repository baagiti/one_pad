import 'package:flutter_test/flutter_test.dart';
import 'package:one_pad/domain/model/time_signature.dart';
import 'package:one_pad/domain/timeline/timeline_map.dart';

void main() {
  // 4/4 at 60 BPM, 44.1 kHz: one beat = exactly 44100 samples.
  final map = TimelineMap(
    timeSignature: TimeSignature.fourFour,
    bpm: 60,
    sampleRate: 44100,
  );

  test('basic sample math', () {
    expect(map.samplesPerBeat, 44100);
    expect(map.samplesPerMeasure, 44100 * 4);
    expect(map.countInSamples, 44100 * 4);
    // count-in + 16 exercises = 17 measures
    expect(map.totalSamples, 44100 * 4 * 17);
  });

  test('position during count-in', () {
    final p = map.positionAt(0);
    expect(p.isCountIn, isTrue);
    expect(p.exercise, -1);
    expect(p.beat, 0);
  });

  test('exercise 0 starts exactly after count-in', () {
    final p = map.positionAt(map.countInSamples);
    expect(p.isCountIn, isFalse);
    expect(p.exercise, 0);
    expect(p.beat, 0);
    expect(p.beatFraction, closeTo(0, 1e-9));
  });

  test('mid-beat position reports fraction for playhead', () {
    // exercise 2, beat 1, halfway through the beat
    final samples =
        map.sampleOfBeat(exercise: 2, beat: 1) + (44100 / 2).round();
    final p = map.positionAt(samples);
    expect(p.exercise, 2);
    expect(p.beat, 1);
    expect(p.beatFraction, closeTo(0.5, 1e-6));
  });

  test('sampleOfBeat and positionAt are inverse', () {
    for (var ex = 0; ex < 16; ex++) {
      for (var beat = 0; beat < 4; beat++) {
        final p = map.positionAt(map.sampleOfBeat(exercise: ex, beat: beat));
        expect(p.exercise, ex);
        expect(p.beat, beat);
      }
    }
  });

  test('click events: one per beat, count-in flagged with distinct sound',
      () {
    final clicks = map.clickEvents();
    expect(clicks, hasLength(17 * 4));
    expect(clicks.where((c) => c.isCountIn), hasLength(4));
    expect(clicks.where((c) => c.isMeasureStart), hasLength(17));
    // strictly increasing offsets
    for (var i = 1; i < clicks.length; i++) {
      expect(clicks[i].sampleOffset, greaterThan(clicks[i - 1].sampleOffset));
    }
  });

  test('count-in length follows the meter (spec §6: 7/8 = 7 clicks)', () {
    final sevenEight = TimelineMap(
      timeSignature: TimeSignature(7, 8),
      bpm: 120,
      sampleRate: 44100,
    );
    final countInClicks =
        sevenEight.clickEvents().where((c) => c.isCountIn);
    expect(countInClicks, hasLength(7));
  });

  test('non-integer samples-per-beat accumulates no rounding drift', () {
    // 44100 * 60 / 71 is not an integer.
    final odd = TimelineMap(
      timeSignature: TimeSignature.fourFour,
      bpm: 71,
      sampleRate: 44100,
    );
    // Offset of the last beat computed in one shot must match the
    // full-precision value (no per-beat accumulation error).
    final last = odd.sampleOfBeat(exercise: 15, beat: 3);
    final expected = (odd.samplesPerBeat * (16 * 4 + 3)).round();
    expect(last, expected);
  });

  group('measuresPerExercise = 2 (design doc §23, multi-measure rudiments)',
      () {
    final map2 = TimelineMap(
      timeSignature: TimeSignature.fourFour,
      bpm: 60,
      sampleRate: 44100,
      measuresPerExercise: 2,
    );

    test('total duration accounts for 2 measures per exercise', () {
      // count-in (1) + 16 exercises * 2 measures = 33 measures.
      expect(map2.totalSamples, 44100 * 4 * 33);
    });

    test('baseMeasureOfExercise skips 2 measures per prior exercise', () {
      expect(map2.baseMeasureOfExercise(0), 1); // right after count-in
      expect(map2.baseMeasureOfExercise(1), 3);
      expect(map2.baseMeasureOfExercise(2), 5);
    });

    test('sampleOfBeat: measureWithinExercise selects the 2nd measure', () {
      final firstMeasure = map2.sampleOfBeat(exercise: 0, beat: 0);
      final secondMeasure =
          map2.sampleOfBeat(exercise: 0, beat: 0, measureWithinExercise: 1);
      expect(secondMeasure - firstMeasure, map2.samplesPerMeasure.round());
    });

    test('positionAt resolves both measures of one exercise to the SAME '
        'exercise index, with measureWithinExercise distinguishing them',
        () {
      final firstMeasureStart =
          map2.positionAt(map2.sampleOfBeat(exercise: 0, beat: 0));
      final secondMeasureStart = map2.positionAt(
          map2.sampleOfBeat(exercise: 0, beat: 0, measureWithinExercise: 1));
      expect(firstMeasureStart.exercise, 0);
      expect(firstMeasureStart.measureWithinExercise, 0);
      expect(secondMeasureStart.exercise, 0);
      expect(secondMeasureStart.measureWithinExercise, 1);

      final nextExerciseStart = map2.positionAt(
          map2.sampleOfBeat(exercise: 1, beat: 0));
      expect(nextExerciseStart.exercise, 1);
      expect(nextExerciseStart.measureWithinExercise, 0);
    });

    test('click events cover every measure of every exercise', () {
      final clicks = map2.clickEvents();
      // count-in (1) + 16*2 measures = 33 measures, 4 beats each.
      expect(clicks, hasLength(33 * 4));
      expect(clicks.where((c) => c.isMeasureStart), hasLength(33));
    });
  });
}
