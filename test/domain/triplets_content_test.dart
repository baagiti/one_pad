import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_pad/domain/content/content_loader.dart';
import 'package:one_pad/domain/generation/session_generator.dart';
import 'package:one_pad/domain/model/skill.dart';

void main() {
  late Skill skill;

  setUpAll(() {
    skill = ContentLoader()
        .loadSkill(File('content/skills/triplets.json').readAsStringSync());
  });

  test('loads skill metadata (roadmap title "Triplets")', () {
    expect(skill.id, 'triplets');
    expect(skill.name, 'Triplets');
    expect(skill.bpmDefault, 70);
  });

  test('has 4 levels: How to Count intro, eighth-note triplets, '
      'quarter-note triplets, then sixteenth-note triplets/sextuplets '
      '(2026-07-27 additions)', () {
    expect(skill.levels.map((l) => l.level), [0, 1, 2, 3]);
    expect(skill.level(0).name, 'How to Count: Triplets');
  });

  test('How to Count: countingLabels are exactly "1 trip let 2 trip '
      'let..." for every template', () {
    const expected = [
      '1', 'trip', 'let', '2', 'trip', 'let',
      '3', 'trip', 'let', '4', 'trip', 'let',
    ];
    for (final t in skill.level(0).templates) {
      expect(t.countingLabels, expected, reason: t.id);
      expect(t.rhythm.every((n) => n.isTriplet && n.duration.code == 'e'),
          isTrue, reason: t.id);
    }
  });

  test('pool sizes follow the position-permutation combinatorics', () {
    expect(skill.level(1).templates, hasLength(8)); // 4 positions x 2 hands
    expect(skill.level(2).templates, hasLength(4)); // 2 halves x 2 hands
    expect(skill.level(3).templates, hasLength(8)); // 4 positions x 2 hands
  });

  test('every template validates against 4/4 (a triplet note is 2/3 of '
      'its base duration, so 3 of them sum to what 2 normally would)', () {
    for (final level in skill.levels) {
      for (final t in level.templates) {
        expect(() => t.validateAgainst(skill.timeSignature), returnsNormally,
            reason: t.id);
      }
    }
  });

  test('level 1: exactly one beat is a triplet (3 isTriplet eighth notes), '
      'the other 3 beats are plain quarters', () {
    for (final t in skill.level(1).templates) {
      final tripletCount = t.rhythm.where((tok) => tok.isTriplet).length;
      expect(tripletCount, 3, reason: t.id);
      expect(
          t.rhythm.where((tok) => tok.isTriplet).every((tok) =>
              tok.duration.code == 'e'),
          isTrue,
          reason: t.id);
      expect(t.rhythm.where((tok) => !tok.isTriplet), hasLength(3),
          reason: t.id);
    }
  });

  test('level 2: exactly 3 quarter-note triplets per template, filling '
      'one measure-half', () {
    for (final t in skill.level(2).templates) {
      final tripletCount = t.rhythm.where((tok) => tok.isTriplet).length;
      expect(tripletCount, 3, reason: t.id);
      expect(
          t.rhythm.where((tok) => tok.isTriplet).every((tok) =>
              tok.duration.code == 'q'),
          isTrue,
          reason: t.id);
    }
  });

  test('level 3: exactly one beat is a full sextuplet (6 isTriplet '
      'sixteenth notes), the other 3 beats are plain quarters', () {
    for (final t in skill.level(3).templates) {
      final tripletCount = t.rhythm.where((tok) => tok.isTriplet).length;
      expect(tripletCount, 6, reason: t.id);
      expect(
          t.rhythm.where((tok) => tok.isTriplet).every((tok) =>
              tok.duration.code == 's'),
          isTrue,
          reason: t.id);
      expect(t.rhythm.where((tok) => !tok.isTriplet), hasLength(3),
          reason: t.id);
    }
  });

  test('sticking is plain sequential alternation across whatever is '
      'struck, regardless of triplet placement', () {
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
      final session = SessionGenerator(seed: 27)
          .generate(skill: skill, levelNumber: level);
      expect(session.exercises, hasLength(16), reason: 'level $level');
    }
  });
}
