import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_pad/domain/content/content_loader.dart';
import 'package:one_pad/domain/generation/session_generator.dart';
import 'package:one_pad/domain/model/skill.dart';

void main() {
  late Skill skill;

  setUpAll(() {
    skill = ContentLoader().loadSkill(
        File('content/skills/syncopation_ties.json').readAsStringSync());
  });

  test('loads skill metadata (roadmap title "Syncopation / Ties")', () {
    expect(skill.id, 'syncopation_ties');
    expect(skill.name, 'Syncopation / Ties');
    expect(skill.bpmDefault, 60);
  });

  test('has 3 levels (simpler 2-onset syncopation, the classic 3-onset '
      'figure, then a real tie — design doc §24)', () {
    expect(skill.levels.map((l) => l.level), [1, 2, 3]);
  });

  test('pool sizes: levels 1/2 are 2 half-placements x 2 hands; level 3 is '
      'R-lead vs L-lead only', () {
    expect(skill.level(1).templates, hasLength(4));
    expect(skill.level(2).templates, hasLength(4));
    expect(skill.level(3).templates, hasLength(2));
  });

  test('level 3 is sessionFixed (only 2 templates, same rationale as every '
      'other small pool in this project)', () {
    expect(skill.level(3).generation.sessionFixed, isTrue);
    final session =
        SessionGenerator(seed: 9).generate(skill: skill, levelNumber: 3);
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

  test('level 1: the syncopation half is eighth + dotted quarter (2 '
      'onsets), no tie needed', () {
    for (final t in skill.level(1).templates) {
      final syncStart =
          t.rhythm.indexWhere((tok) => tok.duration.code == 'e');
      expect(t.rhythm[syncStart].isDotted, isFalse, reason: t.id);
      expect(t.rhythm[syncStart + 1].isDotted, isTrue, reason: t.id);
      expect(t.rhythm.any((tok) => tok.isTied), isFalse, reason: t.id);
    }
  });

  test('level 2: the syncopation half is eighth-quarter-eighth (3 onsets, '
      'the middle quarter starts on the "and" of the half) — no tie '
      'needed (a plain quarter, not dotted)', () {
    for (final t in skill.level(2).templates) {
      final labels = t.sticking.map((h) => h.label).toList();
      expect(labels, hasLength(5)); // 3 (figure) + 2 (plain quarter half)
      expect(t.rhythm.any((tok) => tok.isTied), isFalse, reason: t.id);
      expect(t.rhythm.where((tok) => tok.duration.code == 'e'), hasLength(2),
          reason: t.id);
    }
  });

  test('level 3: a real tie — the tied quarter has no sticking entry and '
      "does not disrupt the surrounding hand alternation (design doc §24)",
      () {
    for (final t in skill.level(3).templates) {
      final tiedTokens = t.rhythm.where((tok) => tok.isTied);
      expect(tiedTokens, hasLength(1), reason: t.id);
      expect(tiedTokens.single.duration.code, 'q', reason: t.id);

      final labels = t.sticking.map((h) => h.label).toList();
      expect(labels, hasLength(6)); // 7 tokens - 1 tied = 6 struck notes
      for (var i = 1; i < labels.length; i++) {
        expect(labels[i], isNot(labels[i - 1]),
            reason: '${t.id}: two same-hand notes in a row at index $i');
      }
    }
  });

  test('generator produces valid 16-exercise sessions for every level', () {
    for (var level = 1; level <= 3; level++) {
      final session = SessionGenerator(seed: 24)
          .generate(skill: skill, levelNumber: level);
      expect(session.exercises, hasLength(16), reason: 'level $level');
    }
  });
}
