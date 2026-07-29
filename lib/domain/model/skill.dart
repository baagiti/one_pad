import 'exercise.dart';
import 'time_signature.dart';

class Skill {
  final String id;
  final String name;
  final TimeSignature timeSignature;
  final int bpmDefault;
  final int bpmMin;
  final int bpmMax;
  final List<Level> levels;

  /// Explicit notation beam-grouping, in numerator-beat units (e.g. [2, 2,
  /// 3] for 7/8's "2+2+3" phrasing). Null for meters whose grouping can be
  /// derived automatically (simple: 1 beat; compound: 3 beats, design doc
  /// §25) — asymmetric meters like 7/8 have no single derivable grouping,
  /// the beams themselves ARE what convey the phrasing to the reader
  /// (design doc §26), so content must say which one is in use.
  final List<int>? beatGroupPattern;

  const Skill({
    required this.id,
    required this.name,
    required this.timeSignature,
    required this.bpmDefault,
    required this.bpmMin,
    required this.bpmMax,
    required this.levels,
    this.beatGroupPattern,
  });

  Level level(int n) => levels.firstWhere((l) => l.level == n,
      orElse: () => throw ArgumentError('Skill $id has no level $n'));
}

class Level {
  final int level;
  final String name;
  final GenerationSpec generation;
  final List<ExerciseTemplate> templates;

  /// Optional short practice tip shown on Session Preview (e.g. "vary your
  /// BPM, don't skip the slow ones" for levels that used to force that via
  /// a fixed tempo ramp, 2026-07-27 — the ramp itself was removed in favor
  /// of the same free BPM control every other level uses, but the advice
  /// behind it is still worth surfacing).
  final String? note;

  const Level({
    required this.level,
    required this.name,
    required this.generation,
    required this.templates,
    this.note,
  });
}

enum GenerationStrategy { poolShuffle, poolTransform, generative }

class GenerationSpec {
  final GenerationStrategy strategy;

  /// Adjacent session slots never contain the same template.
  final bool noAdjacentRepeat;

  /// Easier templates front-loaded, harder ones later.
  final bool difficultyRamp;

  /// Minimum distinct templates in one 16-slot session (0 = no constraint).
  final int minVariety;

  /// When true, one template is picked ONCE per session (from the pool,
  /// weighted like a normal pick) and repeated across all 16 exercises,
  /// instead of the pool being reshuffled slot by slot. Use for "hold one
  /// steady pattern for the whole session" levels (e.g. Eighth Notes
  /// Level 5) — with [noAdjacentRepeat] this would be a contradiction
  /// (same template repeating IS an adjacent repeat), so it's ignored when
  /// this is true.
  final bool sessionFixed;

  const GenerationSpec({
    required this.strategy,
    this.noAdjacentRepeat = true,
    this.difficultyRamp = false,
    this.minVariety = 0,
    this.sessionFixed = false,
  });
}
