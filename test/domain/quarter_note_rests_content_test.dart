import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_pad/domain/content/content_loader.dart';
import 'package:one_pad/domain/generation/session_generator.dart';
import 'package:one_pad/domain/model/skill.dart';

void main() {
  late Skill skill;

  setUpAll(() {
    skill = ContentLoader().loadSkill(
        File('content/skills/quarter_note_rests.json').readAsStringSync());
  });

  test('loads skill metadata', () {
    expect(skill.id, 'quarter_note_rests');
    expect(skill.bpmDefault, 80);
    expect(skill.bpmMin, 30);
    expect(skill.bpmMax, 180);
  });

  test('level pool sizes follow the rest-count axis (8/6/6/8), plus a How '
      'to Count intro (2026-07-27)', () {
    expect(skill.levels.map((l) => l.level), [0, 1, 2, 3, 4]);
    expect(skill.level(0).templates, hasLength(2));
    expect(skill.level(0).name, 'How to Count: Rests');
    expect(skill.level(1).templates, hasLength(8));
    expect(skill.level(2).templates, hasLength(6));
    expect(skill.level(3).templates, hasLength(6));
    expect(skill.level(4).templates, hasLength(8));
  });

  test('How to Count: both templates show all 4 numbers, one struck '
      'position and one rested — the rest still gets a syllable to '
      'silently count', () {
    for (final t in skill.level(0).templates) {
      expect(t.countingLabels, ['1', '2', '3', '4'], reason: t.id);
      final restCount = t.rhythm.where((n) => n.isRest).length;
      expect(restCount, 2, reason: t.id);
    }
  });

  test('no level carries a practice note (bpm comes from the top field)',
      () {
    for (final level in skill.levels) {
      expect(level.note, isNull, reason: 'level ${level.level}');
    }
  });

  test('level 1: exactly one rest per template, 3 notes with sticking', () {
    for (final t in skill.level(1).templates) {
      expect(t.rhythm.where((n) => n.isRest), hasLength(1), reason: t.id);
      expect(t.rhythm.where((n) => !n.isRest), hasLength(3), reason: t.id);
      expect(t.sticking, hasLength(3), reason: t.id);
    }
  });

  test('level 2: two non-adjacent rests', () {
    for (final t in skill.level(2).templates) {
      final restIndices = [
        for (var i = 0; i < t.rhythm.length; i++)
          if (t.rhythm[i].isRest) i
      ];
      expect(restIndices, hasLength(2), reason: t.id);
      expect((restIndices[1] - restIndices[0]).abs(), greaterThan(1),
          reason: '${t.id}: rests must not be adjacent');
    }
  });

  test('level 3: two adjacent (consecutive) rests', () {
    for (final t in skill.level(3).templates) {
      final restIndices = [
        for (var i = 0; i < t.rhythm.length; i++)
          if (t.rhythm[i].isRest) i
      ];
      expect(restIndices, hasLength(2), reason: t.id);
      expect((restIndices[1] - restIndices[0]).abs(), 1,
          reason: '${t.id}: rests must be adjacent');
    }
  });

  test('level 4: three rests, a single hit', () {
    for (final t in skill.level(4).templates) {
      expect(t.rhythm.where((n) => n.isRest), hasLength(3), reason: t.id);
      expect(t.sticking, hasLength(1), reason: t.id);
    }
  });

  test(
      'ghost-stroke alternation: a rest between two hits of the same '
      'underlying hand produces the expected same-hand pair', () {
    // R-start base [R,L,R,L] with the L at index 1 resting leaves R,R,L.
    final t = skill
        .level(1)
        .templates
        .firstWhere((t) => t.id == 'qnr1_a_rest2');
    expect(t.sticking.map((h) => h.label).join(), 'RRL');
  });

  test('every template validates against 4/4 (rests still fill the measure)',
      () {
    for (final level in skill.levels) {
      for (final t in level.templates) {
        expect(() => t.validateAgainst(skill.timeSignature), returnsNormally,
            reason: t.id);
      }
    }
  });

  test('generator produces valid 16-exercise sessions for every level', () {
    for (var level = 1; level <= 4; level++) {
      final session = SessionGenerator(seed: 3)
          .generate(skill: skill, levelNumber: level);
      expect(session.exercises, hasLength(16));
    }
  });
}
