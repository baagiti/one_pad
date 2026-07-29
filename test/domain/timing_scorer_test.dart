import 'package:flutter_test/flutter_test.dart';
import 'package:one_pad/domain/analysis/expected_onsets.dart';
import 'package:one_pad/domain/analysis/timing_scorer.dart';
import 'package:one_pad/domain/model/exercise.dart';
import 'package:one_pad/domain/model/note_token.dart';
import 'package:one_pad/domain/model/sticking.dart';
import 'package:one_pad/domain/model/time_signature.dart';
import 'package:one_pad/domain/timeline/timeline_map.dart';

void main() {
  const sr = 44100;
  // 60 BPM 4/4: one beat = exactly 44100 samples, so "Xms" is trivial to
  // convert to a sample offset for test fixtures (44100 samples/sec).
  final map = TimelineMap(
    timeSignature: TimeSignature.fourFour,
    bpm: 60,
    sampleRate: sr,
  );
  int ms(double milliseconds) => (sr * milliseconds / 1000).round();

  Exercise fourQuarters(int index) => Exercise(
        templateId: 't$index',
        rhythm: [for (var b = 0; b < 4; b++) NoteToken.parse('q')],
        sticking: const [Hand.right, Hand.left, Hand.right, Hand.left],
        index: index,
      );

  final scorer = TimingScorer();

  test('perfectly-timed hits score Great, grade 100', () {
    final exercise = fourQuarters(0);
    final expected = expectedOnsetSamples(map, exercise);

    final result = scorer.score(
      map: map,
      exercises: [exercise],
      detectedOnsetSamples: expected,
      latencySamples: 0,
    );

    expect(result.exercises, hasLength(1));
    final notes = result.exercises.single.notes;
    expect(notes, hasLength(4));
    expect(notes.every((n) => n.quality == HitQuality.great), isTrue);
    expect(result.grade, 100);
  });

  test('a constant device latency is fully compensated by latencySamples',
      () {
    final exercise = fourQuarters(0);
    final expected = expectedOnsetSamples(map, exercise);
    final latency = ms(180); // arbitrary round-trip delay
    final detected = expected.map((s) => s + latency).toList();

    final result = scorer.score(
      map: map,
      exercises: [exercise],
      detectedOnsetSamples: detected,
      latencySamples: latency,
    );

    final notes = result.exercises.single.notes;
    expect(notes.every((n) => n.quality == HitQuality.great), isTrue);
  });

  test('a hit within the Good band but outside Great is scored Good', () {
    final exercise = fourQuarters(0);
    final expected = expectedOnsetSamples(map, exercise);
    // Shift only the first note by 60ms: beyond greatMs(40) but within
    // goodMs(80).
    final detected = [
      expected[0] + ms(60),
      ...expected.sublist(1),
    ];

    final result = scorer.score(
      map: map,
      exercises: [exercise],
      detectedOnsetSamples: detected,
      latencySamples: 0,
    );

    final notes = result.exercises.single.notes;
    expect(notes[0].quality, HitQuality.good);
    expect(notes[0].deviationMs, closeTo(60, 0.5));
    expect(notes.sublist(1).every((n) => n.quality == HitQuality.great),
        isTrue);
  });

  test('a hit found but far outside the Miss band is scored Miss with a '
      'reported deviation', () {
    final exercise = fourQuarters(0);
    final expected = expectedOnsetSamples(map, exercise);
    // 200ms late: inside the 300ms search window, but past missMs(150).
    final detected = [
      expected[0] + ms(200),
      ...expected.sublist(1),
    ];

    final result = scorer.score(
      map: map,
      exercises: [exercise],
      detectedOnsetSamples: detected,
      latencySamples: 0,
    );

    final notes = result.exercises.single.notes;
    expect(notes[0].quality, HitQuality.miss);
    expect(notes[0].deviationMs, isNotNull);
  });

  test('a note with no nearby detected onset at all is a Miss with no '
      'deviation reported', () {
    final exercise = fourQuarters(0);
    final expected = expectedOnsetSamples(map, exercise);

    final result = scorer.score(
      map: map,
      exercises: [exercise],
      detectedOnsetSamples: expected.sublist(1), // note 0 never struck
      latencySamples: 0,
    );

    final notes = result.exercises.single.notes;
    expect(notes[0].quality, HitQuality.miss);
    expect(notes[0].deviationMs, isNull);
    expect(notes.sublist(1).every((n) => n.quality == HitQuality.great),
        isTrue);
  });

  test('overallAccuracy and grade aggregate across exercises', () {
    final e0 = fourQuarters(0);
    final e1 = fourQuarters(1);
    final expected0 = expectedOnsetSamples(map, e0);
    final expected1 = expectedOnsetSamples(map, e1);

    // e0: all 4 perfect. e1: 2 perfect, 2 missed entirely -> 6/8 = 75%.
    final detected = [...expected0, expected1[0], expected1[1]];

    final result = scorer.score(
      map: map,
      exercises: [e0, e1],
      detectedOnsetSamples: detected,
      latencySamples: 0,
    );

    expect(result.exercises[0].accuracy, 1.0);
    expect(result.exercises[1].accuracy, 0.5);
    expect(result.overallAccuracy, closeTo(0.75, 0.001));
    expect(result.grade, 75);
  });

  test('a detected onset is never reused for two different expected notes',
      () {
    final exercise = fourQuarters(0);
    final expected = expectedOnsetSamples(map, exercise);
    // Only ONE detected onset, close to note 0 — it must not also be
    // claimed as a match for note 1 (1000ms away, well outside the window).
    final detectedOnset = expected[0] + ms(10);

    final result = scorer.score(
      map: map,
      exercises: [exercise],
      detectedOnsetSamples: [detectedOnset],
      latencySamples: 0,
    );

    final notes = result.exercises.single.notes;
    final matched = notes.where((n) => n.deviationMs != null);
    expect(matched.length, 1);
    expect(notes[0].deviationMs, isNotNull);
    expect(notes[1].deviationMs, isNull);
  });
}
