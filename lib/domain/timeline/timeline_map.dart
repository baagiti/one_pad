import '../model/session.dart';
import '../model/time_signature.dart';

/// The Master Timeline's coordinate system (spec §15).
///
/// The rendered session audio is one continuous stream:
///
///   [count-in: 1 measure][exercise 0][exercise 1]...[exercise 15]
///
/// This class is the single source of mapping between stream position
/// (samples) and musical position (measure/beat). Everything — playhead,
/// exercise transitions, expected-hit times for analysis — derives from it.
/// Pure math, no I/O.
class TimelineMap {
  final TimeSignature timeSignature;
  final int bpm;
  final int sampleRate;
  final int exerciseCount;

  /// How many measures each exercise occupies — 1 in the common case, but
  /// 2+ for rudiments that don't fit a single measure (e.g. the Triple
  /// Paradiddle at eighth-note speed, design doc §23). Uniform across a
  /// whole session (one level's template pool is always uniform in
  /// length).
  final int measuresPerExercise;

  TimelineMap({
    required this.timeSignature,
    required this.bpm,
    required this.sampleRate,
    this.exerciseCount = Session.exerciseCount,
    this.measuresPerExercise = 1,
  })  : assert(bpm > 0),
        assert(sampleRate > 0),
        assert(measuresPerExercise > 0);

  TimelineMap.forSession(Session session, {required int sampleRate})
      : this(
          timeSignature: session.timeSignature,
          bpm: session.bpm,
          sampleRate: sampleRate,
          exerciseCount: session.exercises.length,
          measuresPerExercise: session.exercises.isEmpty
              ? 1
              : session.exercises.first.measureCount,
        );

  /// Duration of one beat in samples. Kept as double: rounding only happens
  /// at the final sample-offset step so error never accumulates.
  double get samplesPerBeat => sampleRate * 60.0 / bpm;

  double get samplesPerMeasure => samplesPerBeat * timeSignature.beats;

  /// Count-in is always exactly one measure (spec §6).
  int get countInSamples => samplesPerMeasure.round();

  int get totalSamples =>
      (samplesPerMeasure * (exerciseCount * measuresPerExercise + 1)).round();

  /// Global (0-based, count-in-aware) measure index where [exercise]
  /// starts — measure 0 is always the count-in, so exercise 0 starts at
  /// measure 1 regardless of [measuresPerExercise].
  int baseMeasureOfExercise(int exercise) =>
      exercise * measuresPerExercise + 1;

  /// Sample offset of a beat within a given exercise (both 0-based).
  /// Exercise -1 addresses the count-in measure. [measureWithinExercise]
  /// selects which of a multi-measure exercise's measures [beat] is
  /// counted from (default 0, the exercise's first measure).
  int sampleOfBeat({
    required int exercise,
    required int beat,
    int measureWithinExercise = 0,
  }) {
    final measureIndex =
        baseMeasureOfExercise(exercise) + measureWithinExercise;
    return (samplesPerMeasure * measureIndex + samplesPerBeat * beat).round();
  }

  /// Musical position for a stream position. During count-in,
  /// [TimelinePosition.exercise] is -1. [TimelinePosition.beat] is always
  /// the beat WITHIN THE CURRENT MEASURE (0..timeSignature.beats-1) —
  /// [TimelinePosition.measureWithinExercise] says which of the current
  /// exercise's measures that is, for exercises spanning more than one.
  TimelinePosition positionAt(int samples) {
    final clamped = samples.clamp(0, totalSamples - 1);
    final measure = clamped ~/ samplesPerMeasure;
    final withinMeasure = clamped - measure * samplesPerMeasure;
    final beatDouble = withinMeasure / samplesPerBeat;
    final measureSinceCountIn = measure - 1;
    return TimelinePosition(
      exercise: measureSinceCountIn >= 0
          ? measureSinceCountIn ~/ measuresPerExercise
          : -1,
      measureWithinExercise: measureSinceCountIn >= 0
          ? measureSinceCountIn % measuresPerExercise
          : 0,
      beat: beatDouble.floor(),
      beatFraction: beatDouble - beatDouble.floor(),
      isCountIn: measure == 0,
      isFinished: samples >= totalSamples,
    );
  }

  /// All metronome click offsets: one per beat, count-in included.
  /// Count-in clicks are flagged so the renderer can use the distinct
  /// count-in sound (spec §6).
  List<ClickEvent> clickEvents() {
    final events = <ClickEvent>[];
    final totalMeasures = exerciseCount * measuresPerExercise + 1;
    for (var m = 0; m < totalMeasures; m++) {
      for (var b = 0; b < timeSignature.beats; b++) {
        events.add(ClickEvent(
          sampleOffset:
              (samplesPerMeasure * m + samplesPerBeat * b).round(),
          isCountIn: m == 0,
          isMeasureStart: b == 0,
        ));
      }
    }
    return events;
  }
}

class TimelinePosition {
  /// 0-based exercise index; -1 during count-in.
  final int exercise;

  /// Which of the current exercise's measures [beat] belongs to (0-based).
  /// Always 0 for a single-measure exercise; design doc §23.
  final int measureWithinExercise;

  /// Beat WITHIN THE CURRENT MEASURE (0..timeSignature.beats-1) — NOT
  /// cumulative across a multi-measure exercise, see [measureWithinExercise].
  final int beat;

  /// 0..1 progress within the current beat (drives the smooth playhead).
  final double beatFraction;
  final bool isCountIn;
  final bool isFinished;

  const TimelinePosition({
    required this.exercise,
    this.measureWithinExercise = 0,
    required this.beat,
    required this.beatFraction,
    required this.isCountIn,
    required this.isFinished,
  });

  @override
  String toString() =>
      'TimelinePosition(ex $exercise, measure $measureWithinExercise, '
      'beat $beat+${beatFraction.toStringAsFixed(3)}'
      '${isCountIn ? ', count-in' : ''}${isFinished ? ', finished' : ''})';
}

class ClickEvent {
  final int sampleOffset;
  final bool isCountIn;
  final bool isMeasureStart;

  const ClickEvent({
    required this.sampleOffset,
    required this.isCountIn,
    required this.isMeasureStart,
  });
}
