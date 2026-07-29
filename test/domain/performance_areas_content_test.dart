import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_pad/domain/content/content_loader.dart';
import 'package:one_pad/domain/generation/session_generator.dart';
import 'package:one_pad/domain/model/skill.dart';

void main() {
  const areas = {
    'performance_foundations': 86,
    'performance_syncopated_feel': 50,
    // +8 from Triplets Level 3 (sextuplets) +10 from adding the whole new
    // 32nd Notes skill (2026-07-27) — same hand-speed-tier family.
    'performance_fast_subdivision': 78,
    // +2 from Roll Family Level 1 (Double Stroke Roll, 2026-07-27).
    'performance_rudiment_workout': 24,
  };

  for (final entry in areas.entries) {
    group('${entry.key}.json (design doc §29)', () {
      late Skill skill;

      setUpAll(() {
        skill = ContentLoader().loadSkill(
            File('content/skills/${entry.key}.json').readAsStringSync());
      });

      test('loads with a 4/4 time signature and one pooled level', () {
        expect(skill.id, entry.key);
        expect(skill.timeSignature.toString(), '4/4');
        expect(skill.levels, hasLength(1));
      });

      test('the pooled level has every constituent skill\'s templates, '
          'each id still unique', () {
        final templates = skill.level(1).templates;
        expect(templates, hasLength(entry.value));
        expect(templates.map((t) => t.id).toSet(), hasLength(entry.value));
      });

      test('every pooled template still validates against 4/4 (each came '
          'from an already-validated 4/4 skill)', () {
        for (final t in skill.level(1).templates) {
          expect(() => t.validateAgainst(skill.timeSignature), returnsNormally,
              reason: t.id);
        }
      });

      test('generator produces a valid 16-exercise session', () {
        final session =
            SessionGenerator(seed: 29).generate(skill: skill, levelNumber: 1);
        expect(session.exercises, hasLength(16));
      });
    });
  }
}
