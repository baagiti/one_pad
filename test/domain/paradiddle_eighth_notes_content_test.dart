import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_pad/domain/content/content_loader.dart';
import 'package:one_pad/domain/generation/session_generator.dart';
import 'package:one_pad/domain/model/skill.dart';

void main() {
  late Skill skill;

  setUpAll(() {
    skill = ContentLoader().loadSkill(
        File('content/skills/paradiddle_eighth_notes.json')
            .readAsStringSync());
  });

  test('loads skill metadata (roadmap title "Rudiments (Eighth Notes)")', () {
    expect(skill.id, 'paradiddle_eighth_notes');
    expect(skill.name, 'Rudiments (Eighth Notes)');
    expect(skill.bpmDefault, 60);
  });

  test('has 4 levels (fixed lead, switching lead, mix with plain '
      'alternation, then Triple Paradiddle — the last was added once '
      'multi-measure templates became possible, see design doc §20/§23)',
      () {
    expect(skill.levels.map((l) => l.level), [1, 2, 3, 4]);
  });

  test('pool sizes: level 1/2/4 are R-lead vs L-lead only, level 3 adds the '
      'P+A / A+P ordering axis', () {
    expect(skill.level(1).templates, hasLength(2));
    expect(skill.level(2).templates, hasLength(2));
    expect(skill.level(3).templates, hasLength(4));
    expect(skill.level(4).templates, hasLength(2));
  });

  test('level 1 is sessionFixed (fixed lead hand for the whole session); '
      'level 2 is not (forces switching every measure)', () {
    expect(skill.level(1).generation.sessionFixed, isTrue);
    expect(skill.level(2).generation.sessionFixed, isFalse);
    final session =
        SessionGenerator(seed: 6).generate(skill: skill, levelNumber: 1);
    expect(session.exercises.map((e) => e.templateId).toSet(), hasLength(1));
  });

  test('every template validates against 4/4 (levels 1-3 are one measure; '
      'level 4\'s Triple Paradiddle is 2 measures — design doc §23)', () {
    for (final level in skill.levels) {
      for (final t in level.templates) {
        expect(() => t.validateAgainst(skill.timeSignature), returnsNormally,
            reason: t.id);
      }
    }
    expect(skill.level(4).templates.first.measureCountFor(skill.timeSignature),
        2);
  });

  test('level 4: Triple Paradiddle — RLRLRLRR LRLRLRLL (or mirrored), '
      'accent on the first stroke of each 8-note half, sessionFixed '
      '(2 templates, same rationale as levels 1/2 and Skill 5 L3/Skill 8 L3)',
      () {
    expect(skill.level(4).generation.sessionFixed, isTrue);
    for (final t in skill.level(4).templates) {
      final labels = t.sticking.map((h) => h.label).toList();
      expect(labels, hasLength(16));
      final lead = labels[0];
      final other = lead == 'R' ? 'L' : 'R';
      expect(labels, [
        lead, other, lead, other, lead, other, lead, lead,
        other, lead, other, lead, other, lead, other, other,
      ], reason: t.id);
      expect(t.rhythm[0].isAccented, isTrue, reason: t.id);
      expect(t.rhythm[8].isAccented, isTrue, reason: t.id);
    }
  });

  test('level 1/2: single paradiddle shape — RLRR LRLL (or mirrored), '
      'accent on the first stroke of each 4-note group', () {
    for (final level in [skill.level(1), skill.level(2)]) {
      for (final t in level.templates) {
        final labels = t.sticking.map((h) => h.label).toList();
        expect(labels, hasLength(8));
        final lead = labels[0];
        final other = lead == 'R' ? 'L' : 'R';
        expect(labels, [lead, other, lead, lead, other, lead, other, other],
            reason: t.id);
        expect(t.rhythm[0].isAccented, isTrue, reason: '${t.id} note 0');
        expect(t.rhythm[4].isAccented, isTrue, reason: '${t.id} note 4');
        for (final i in [1, 2, 3, 5, 6, 7]) {
          expect(t.rhythm[i].isAccented, isFalse,
              reason: '${t.id} note $i');
        }
      }
    }
  });

  test('level 3: exactly one accented note per template (the paradiddle '
      "group's lead stroke); the plain-alternation half carries no accent",
      () {
    for (final t in skill.level(3).templates) {
      final accentedCount =
          t.rhythm.where((token) => token.isAccented).length;
      expect(accentedCount, 1, reason: t.id);
    }
  });

  test('generator produces valid 16-exercise sessions for every level', () {
    for (var level = 1; level <= 4; level++) {
      final session = SessionGenerator(seed: 13)
          .generate(skill: skill, levelNumber: level);
      expect(session.exercises, hasLength(16), reason: 'level $level');
    }
  });
}
