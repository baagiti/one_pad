import 'exercise.dart';
import 'time_signature.dart';

/// One complete practice run (spec §4): exactly 16 exercises in version 1.
class Session {
  static const exerciseCount = 16;

  final String id;
  final DateTime createdAt;

  /// Skill id + level this session was generated from.
  /// (PerformanceArea source arrives in a later milestone.)
  final String skillId;
  final int level;

  final TimeSignature timeSignature;

  /// Explicit notation beam-grouping snapshot from the source skill (design
  /// doc §26) — null when the meter's grouping can be derived automatically.
  final List<int>? beatGroupPattern;

  /// Changing BPM never regenerates the session (spec §4); it only re-renders
  /// the audio timeline.
  final int bpm;

  final List<Exercise> exercises;

  Session({
    required this.id,
    required this.createdAt,
    required this.skillId,
    required this.level,
    required this.timeSignature,
    this.beatGroupPattern,
    required this.bpm,
    required this.exercises,
  }) {
    if (exercises.length != exerciseCount) {
      throw ArgumentError(
          'Session must contain $exerciseCount exercises, got ${exercises.length}');
    }
  }

  Session withBpm(int newBpm) => Session(
        id: id,
        createdAt: createdAt,
        skillId: skillId,
        level: level,
        timeSignature: timeSignature,
        beatGroupPattern: beatGroupPattern,
        bpm: newBpm,
        exercises: exercises,
      );
}
