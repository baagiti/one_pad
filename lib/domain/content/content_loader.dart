import 'dart:convert';

import '../model/exercise.dart';
import '../model/note_token.dart';
import '../model/skill.dart';
import '../model/sticking.dart';
import '../model/time_signature.dart';

/// Parses skill content JSON into domain objects. Pure Dart: the caller
/// (infrastructure layer) is responsible for reading the asset/file.
class ContentLoader {
  static const supportedSchemaVersion = 1;

  Skill loadSkill(String jsonString) {
    final root = json.decode(jsonString) as Map<String, dynamic>;

    final schema = root['schemaVersion'] as int?;
    if (schema != supportedSchemaVersion) {
      throw FormatException(
          'Unsupported schemaVersion $schema (expected $supportedSchemaVersion)');
    }

    final timeSignature = TimeSignature.parse(root['timeSignature'] as String);
    final bpmRange = (root['bpmRange'] as List).cast<int>();

    final levels = (root['levels'] as List)
        .cast<Map<String, dynamic>>()
        .map((l) => _parseLevel(l, timeSignature))
        .toList()
      ..sort((a, b) => a.level.compareTo(b.level));

    return Skill(
      id: root['skillId'] as String,
      name: root['name'] as String,
      timeSignature: timeSignature,
      bpmDefault: root['bpmDefault'] as int,
      bpmMin: bpmRange[0],
      bpmMax: bpmRange[1],
      levels: levels,
    );
  }

  Level _parseLevel(Map<String, dynamic> l, TimeSignature ts) {
    final g = l['generation'] as Map<String, dynamic>;
    final spec = GenerationSpec(
      strategy: _parseStrategy(g['strategy'] as String),
      noAdjacentRepeat: g['noAdjacentRepeat'] as bool? ?? true,
      difficultyRamp: g['difficultyRamp'] as bool? ?? false,
      minVariety: g['minVariety'] as int? ?? 0,
    );

    final templates = (l['templates'] as List)
        .cast<Map<String, dynamic>>()
        .map(_parseTemplate)
        .toList();

    final ids = <String>{};
    for (final t in templates) {
      if (!ids.add(t.id)) {
        throw FormatException('Duplicate template id: ${t.id}');
      }
      t.validateAgainst(ts);
    }

    return Level(
      level: l['level'] as int,
      name: l['name'] as String,
      generation: spec,
      templates: templates,
    );
  }

  ExerciseTemplate _parseTemplate(Map<String, dynamic> t) => ExerciseTemplate(
        id: t['id'] as String,
        rhythm:
            (t['rhythm'] as List).cast<String>().map(NoteToken.parse).toList(),
        sticking:
            (t['sticking'] as List).cast<String>().map(Hand.parse).toList(),
        difficulty: t['difficulty'] as int,
      );

  GenerationStrategy _parseStrategy(String s) => switch (s) {
        'pool_shuffle' => GenerationStrategy.poolShuffle,
        'pool_transform' => GenerationStrategy.poolTransform,
        'generative' => GenerationStrategy.generative,
        _ => throw FormatException('Unknown generation strategy: $s'),
      };
}
