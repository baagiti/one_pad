import 'dart:math';

import '../model/exercise.dart';
import '../model/session.dart';
import '../model/skill.dart';

/// Generates a 16-exercise session from a skill level's template pool.
///
/// Deterministic for a given [seed], so tests are reproducible and a session
/// can in principle be re-derived from (skillId, level, seed).
///
/// pool_shuffle pipeline:
///   1. allocate pick-counts across templates (respecting minVariety and,
///      when noAdjacentRepeat is on, a per-template cap of half the session)
///   2. sequence slot by slot; a template whose remaining count exceeds half
///      the remaining slots MUST be picked (this guarantees noAdjacentRepeat
///      is always satisfiable — no repair pass needed)
///   3. difficultyRamp biases free choices toward easier templates early
///
/// Review Pool injection (premium) hooks in between steps 1 and 2 in a later
/// milestone: reserved slots are filled with review exercises first.
class SessionGenerator {
  final Random _rng;

  SessionGenerator({int? seed}) : _rng = Random(seed);

  Session generate({
    required Skill skill,
    required int levelNumber,
    int? bpm,
    DateTime? now,
  }) {
    final level = skill.level(levelNumber);
    final spec = level.generation;

    if (spec.strategy != GenerationStrategy.poolShuffle) {
      throw UnsupportedError(
          'Strategy ${spec.strategy} is not implemented yet (level ${level.level})');
    }
    if (level.templates.isEmpty) {
      throw StateError('Level ${level.level} has an empty template pool');
    }
    if (spec.noAdjacentRepeat && level.templates.length < 2) {
      throw StateError(
          'Level ${level.level}: noAdjacentRepeat requires at least 2 templates');
    }

    final sequence = _sequence(level.templates, spec, Session.exerciseCount);

    final createdAt = now ?? DateTime.now();
    return Session(
      id: _newId(createdAt),
      createdAt: createdAt,
      skillId: skill.id,
      level: level.level,
      timeSignature: skill.timeSignature,
      bpm: bpm ?? skill.bpmDefault,
      exercises: [
        for (var i = 0; i < sequence.length; i++)
          Exercise.fromTemplate(sequence[i], i),
      ],
    );
  }

  List<ExerciseTemplate> _sequence(
      List<ExerciseTemplate> pool, GenerationSpec spec, int slots) {
    final counts = _allocateCounts(pool, spec, slots);

    final result = <ExerciseTemplate>[];
    ExerciseTemplate? prev;

    for (var slot = 0; slot < slots; slot++) {
      final remainingSlots = slots - slot;

      var candidates = counts.keys.where((t) => counts[t]! > 0).toList();
      if (spec.noAdjacentRepeat && prev != null) {
        candidates = candidates.where((t) => t != prev).toList();
      }

      ExerciseTemplate pick;
      final forced = spec.noAdjacentRepeat
          ? candidates.where((t) => counts[t]! * 2 > remainingSlots).toList()
          : const <ExerciseTemplate>[];

      if (forced.isNotEmpty) {
        forced.sort((a, b) => counts[b]!.compareTo(counts[a]!));
        pick = forced.first;
      } else if (spec.difficultyRamp) {
        final minDiff =
            candidates.map((t) => t.difficulty).reduce(min);
        final easiest =
            candidates.where((t) => t.difficulty == minDiff).toList();
        pick = easiest[_rng.nextInt(easiest.length)];
      } else {
        pick = _weightedPick(candidates, counts);
      }

      counts[pick] = counts[pick]! - 1;
      result.add(pick);
      prev = pick;
    }
    return result;
  }

  /// Distributes [slots] picks across the pool. Guarantees:
  ///  - at least min(minVariety, pool size) distinct templates
  ///  - no template exceeds ceil(slots/2) when noAdjacentRepeat is on,
  ///    which makes adjacency-safe sequencing always feasible
  Map<ExerciseTemplate, int> _allocateCounts(
      List<ExerciseTemplate> pool, GenerationSpec spec, int slots) {
    final variety = max(1, min(spec.minVariety, pool.length));
    final chosen = [...pool]..shuffle(_rng);
    final active = chosen.take(max(variety, min(pool.length, slots))).toList();

    // When adjacency is constrained, a single template may fill at most half
    // the session; with a pool of 2 this forces strict alternation (which is
    // exactly the level-2 "lead-hand switching" curriculum).
    final cap = spec.noAdjacentRepeat ? (slots + 1) ~/ 2 : slots;

    final counts = <ExerciseTemplate, int>{};
    // Seed the required variety first.
    for (var i = 0; i < variety; i++) {
      counts[active[i]] = 1;
    }
    var assigned = variety;
    while (assigned < slots) {
      final t = active[_rng.nextInt(active.length)];
      if ((counts[t] ?? 0) >= cap) continue;
      counts[t] = (counts[t] ?? 0) + 1;
      assigned++;
    }
    return counts;
  }

  ExerciseTemplate _weightedPick(
      List<ExerciseTemplate> candidates, Map<ExerciseTemplate, int> counts) {
    final total = candidates.fold<int>(0, (s, t) => s + counts[t]!);
    var roll = _rng.nextInt(total);
    for (final t in candidates) {
      roll -= counts[t]!;
      if (roll < 0) return t;
    }
    return candidates.last;
  }

  String _newId(DateTime t) =>
      'ses_${t.millisecondsSinceEpoch.toRadixString(36)}_${_rng.nextInt(1 << 32).toRadixString(36)}';
}
