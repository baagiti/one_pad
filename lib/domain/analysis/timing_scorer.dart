import '../model/exercise.dart';
import '../timeline/timeline_map.dart';
import 'expected_onsets.dart';

/// How close a detected mic onset landed to its expected timeline position.
/// Bands agreed 2026-07-22 (design doc §9.2): deliberately more forgiving
/// than competitive rhythm games (which use ±15-50ms) — this is a training
/// tool, not a scored game, and should read as encouraging.
enum HitQuality { great, good, miss }

class NoteScore {
  /// Signed deviation in ms (negative = early, positive = late). Null when
  /// no detected onset fell within the search window at all.
  final double? deviationMs;
  final HitQuality quality;

  const NoteScore({this.deviationMs, required this.quality});
}

class ExerciseScore {
  final int exerciseIndex;
  final List<NoteScore> notes;

  const ExerciseScore({required this.exerciseIndex, required this.notes});

  /// Fraction of this exercise's notes rated Great or Good (0..1). An
  /// exercise with no struck notes (shouldn't happen in practice) counts as
  /// perfect rather than dividing by zero.
  double get accuracy {
    if (notes.isEmpty) return 1.0;
    final hits = notes.where((n) => n.quality != HitQuality.miss).length;
    return hits / notes.length;
  }
}

class SessionScore {
  final List<ExerciseScore> exercises;

  const SessionScore({required this.exercises});

  double get overallAccuracy {
    final allNotes = exercises.expand((e) => e.notes);
    var total = 0;
    var hits = 0;
    for (final n in allNotes) {
      total++;
      if (n.quality != HitQuality.miss) hits++;
    }
    return total == 0 ? 1.0 : hits / total;
  }

  /// The single number the Results screen shows (2026-07-22 decision: a
  /// minimal overall score, not a per-exercise breakdown, for M4's scope).
  int get grade => (overallAccuracy * 100).round();
}

/// Grades a Record-mode take: matches the mic's detected onsets (already
/// adjusted for this device's calibrated latency) against each exercise's
/// expected onset positions from [expectedOnsetSamples] — the same ground
/// truth the reference-hit audio was rendered from.
class TimingScorer {
  static const greatMs = 40.0;
  static const goodMs = 80.0;
  static const missMs = 150.0;

  /// How far (in ms) either side of an expected onset we'll even consider a
  /// detected onset as a candidate match. Comfortably wider than [missMs] so
  /// a badly-timed but genuine hit still gets a reported deviation instead
  /// of being indistinguishable from "no onset detected at all".
  static const _searchMs = 300.0;

  SessionScore score({
    required TimelineMap map,
    required List<Exercise> exercises,
    required List<int> detectedOnsetSamples,
    required int latencySamples,
  }) {
    final msPerSample = 1000.0 / map.sampleRate;
    final searchSamples = (_searchMs / msPerSample).round();

    // Shift detected onsets back by the round-trip latency so they land in
    // the timeline's own (rendered) coordinate space.
    final adjusted = detectedOnsetSamples
        .map((s) => s - latencySamples)
        .toList(growable: false)
      ..sort();
    final used = List<bool>.filled(adjusted.length, false);

    final exerciseScores = <ExerciseScore>[];
    for (final exercise in exercises) {
      final notes = <NoteScore>[];
      for (final expectedSample in expectedOnsetSamples(map, exercise)) {
        var bestIndex = -1;
        var bestDelta = 0;
        for (var i = 0; i < adjusted.length; i++) {
          if (used[i]) continue;
          final delta = adjusted[i] - expectedSample;
          if (delta.abs() > searchSamples) continue;
          if (bestIndex == -1 || delta.abs() < bestDelta.abs()) {
            bestIndex = i;
            bestDelta = delta;
          }
        }

        if (bestIndex == -1) {
          notes.add(const NoteScore(quality: HitQuality.miss));
          continue;
        }
        used[bestIndex] = true;
        final deviationMs = bestDelta * msPerSample;
        final quality = deviationMs.abs() <= greatMs
            ? HitQuality.great
            : deviationMs.abs() <= goodMs
                ? HitQuality.good
                : HitQuality.miss;
        notes.add(NoteScore(deviationMs: deviationMs, quality: quality));
      }
      exerciseScores
          .add(ExerciseScore(exerciseIndex: exercise.index, notes: notes));
    }
    return SessionScore(exercises: exerciseScores);
  }
}
