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

  TimelineMap({
    required this.timeSignature,
    required this.bpm,
    required this.sampleRate,
    this.exerciseCount = Session.exerciseCount,
  })  : assert(bpm > 0),
        assert(sampleRate > 0);

  TimelineMap.forSession(Session session, {required int sampleRate})
      : this(
          timeSignature: session.timeSignature,
          bpm: session.bpm,
          sampleRate: sampleRate,
          exerciseCount: session.exercises.length,
        );

  /// Duration of one beat in samples. Kept as double: rounding only happens
  /// at the final sample-offset step so error never accumulates.
  double get samplesPerBeat => sampleRate * 60.0 / bpm;

  double get samplesPerMeasure => samplesPerBeat * timeSignature.beats;

  /// Count-in is always exactly one measure (spec §6).
  int get countInSamples => samplesPerMeasure.round();

  int get totalSamples =>
      (samplesPerMeasure * (exerciseCount + 1)).round();

  /// Sample offset of a beat within a given exercise (both 0-based).
  /// Exercise -1 addresses the count-in measure.
  int sampleOfBeat({required int exercise, required int beat}) {
    final measureIndex = exercise + 1; // count-in occupies measure 0
    return (samplesPerMeasure * measureIndex + samplesPerBeat * beat).round();
  }

  /// Musical position for a stream position. During count-in,
  /// [TimelinePosition.exercise] is -1.
  TimelinePosition positionAt(int samples) {
    final clamped = samples.clamp(0, totalSamples - 1);
    final measure = clamped ~/ samplesPerMeasure;
    final withinMeasure = clamped - measure * samplesPerMeasure;
    final beatDouble = withinMeasure / samplesPerBeat;
    return TimelinePosition(
      exercise: measure - 1,
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
    for (var m = 0; m < exerciseCount + 1; m++) {
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
  final int beat;

  /// 0..1 progress within the current beat (drives the smooth playhead).
  final double beatFraction;
  final bool isCountIn;
  final bool isFinished;

  const TimelinePosition({
    required this.exercise,
    required this.beat,
    required this.beatFraction,
    required this.isCountIn,
    required this.isFinished,
  });

  @override
  String toString() =>
      'TimelinePosition(ex $exercise, beat $beat+${beatFraction.toStringAsFixed(3)}'
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
