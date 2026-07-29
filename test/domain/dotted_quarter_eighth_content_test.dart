import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_pad/domain/content/content_loader.dart';
import 'package:one_pad/domain/generation/session_generator.dart';
import 'package:one_pad/domain/model/skill.dart';

void main() {
  late Skill skill;

  setUpAll(() {
    skill = ContentLoader().loadSkill(
        File('content/skills/dotted_quarter_eighth.json').readAsStringSync());
  });

  test('loads skill metadata (roadmap title "Dotted Quarter + Eighth")', () {
    expect(skill.id, 'dotted_quarter_eighth');
    expect(skill.name, 'Dotted Quarter + Eighth');
    expect(skill.bpmDefault, 60);
  });

  test('has 3 levels (measure-half building blocks: Q/E backdrop, then '
      'full dotted quarter — design doc §19)', () {
    expect(skill.levels.map((l) => l.level), [1, 2, 3]);
  });

  test('pool sizes follow the position-permutation combinatorics', () {
    expect(skill.level(1).templates, hasLength(4)); // 2 positions x 2 hands
    expect(skill.level(2).templates, hasLength(4)); // 2 positions x 2 hands
    expect(skill.level(3).templates, hasLength(2)); // 1 position x 2 hands
  });

  test('level 3 is sessionFixed (only 2 templates, mirrors Skill 3 Level 5 '
      'fix — see design doc §17/§19)', () {
    expect(skill.level(3).generation.sessionFixed, isTrue);
    final session =
        SessionGenerator(seed: 5).generate(skill: skill, levelNumber: 3);
    expect(session.exercises.map((e) => e.templateId).toSet(), hasLength(1));
  });

  test('every template validates against 4/4', () {
    for (final level in skill.levels) {
      for (final t in level.templates) {
        expect(() => t.validateAgainst(skill.timeSignature), returnsNormally,
            reason: t.id);
      }
    }
  });

  test('the dotted-quarter half is always dotted-quarter followed by a '
      'single eighth ("and" of the beat) — design doc §19', () {
    for (final level in skill.levels) {
      for (final t in level.templates) {
        for (var i = 0; i < t.rhythm.length; i++) {
          if (t.rhythm[i].isDotted) {
            expect(t.rhythm[i + 1].isDotted, isFalse, reason: t.id);
            expect(t.rhythm[i + 1].isRest, isFalse, reason: t.id);
            expect(t.rhythm[i + 1].duration.code, 'e', reason: t.id);
          }
        }
      }
    }
  });

  test(
      'sticking is plain sequential alternation across whatever is struck',
      () {
    for (final level in skill.levels) {
      for (final t in level.templates) {
        final labels = t.sticking.map((h) => h.label).toList();
        for (var i = 1; i < labels.length; i++) {
          expect(labels[i], isNot(labels[i - 1]),
              reason: '${t.id}: two same-hand notes in a row at index $i');
        }
      }
    }
  });

  test('generator produces valid 16-exercise sessions for every level', () {
    for (var level = 1; level <= 3; level++) {
      final session = SessionGenerator(seed: 11)
          .generate(skill: skill, levelNumber: level);
      expect(session.exercises, hasLength(16), reason: 'level $level');
    }
  });
}
