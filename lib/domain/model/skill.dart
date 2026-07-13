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

  const Skill({
    required this.id,
    required this.name,
    required this.timeSignature,
    required this.bpmDefault,
    required this.bpmMin,
    required this.bpmMax,
    required this.levels,
  });

  Level level(int n) => levels.firstWhere((l) => l.level == n,
      orElse: () => throw ArgumentError('Skill $id has no level $n'));
}

class Level {
  final int level;
  final String name;
  final GenerationSpec generation;
  final List<ExerciseTemplate> templates;

  const Level({
    required this.level,
    required this.name,
    required this.generation,
    required this.templates,
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

  const GenerationSpec({
    required this.strategy,
    this.noAdjacentRepeat = true,
    this.difficultyRamp = false,
    this.minVariety = 0,
  });
}
