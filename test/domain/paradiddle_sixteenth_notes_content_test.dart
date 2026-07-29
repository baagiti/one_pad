import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_pad/domain/content/content_loader.dart';
import 'package:one_pad/domain/generation/session_generator.dart';
import 'package:one_pad/domain/model/skill.dart';

void main() {
  late Skill skill;

  setUpAll(() {
    skill = ContentLoader().loadSkill(
        File('content/skills/paradiddle_sixteenth_notes.json')
            .readAsStringSync());
  });

  test('loads skill metadata (roadmap title "Rudiments (Sixteenth Notes)")',
      () {
    expect(skill.id, 'paradiddle_sixteenth_notes');
    expect(skill.name, 'Rudiments (Sixteenth Notes)');
  });

  test('has 3 levels (Single Paradiddle fixed/switching lead, then Triple '
      'Paradiddle — Double Paradiddle / Paradiddle-Diddle deferred to a '
      '6/8 "Alternate Meters" skill, see design doc §22)', () {
    expect(skill.levels.map((l) => l.level), [1, 2, 3]);
  });

  test('every level has exactly 2 templates (R-lead / L-lead)', () {
    for (final level in skill.levels) {
      expect(level.templates, hasLength(2), reason: 'level ${level.level}');
    }
  });

  test('levels 1 and 3 are sessionFixed; level 2 forces switching every '
      'measure', () {
    expect(skill.level(1).generation.sessionFixed, isTrue);
    expect(skill.level(2).generation.sessionFixed, isFalse);
    expect(skill.level(3).generation.sessionFixed, isTrue);
  });

  test('every template validates against 4/4 (Triple Paradiddle fits '
      'exactly one measure at sixteenth speed — it did not at eighth '
      'speed, see design doc §20/§22)', () {
    for (final level in skill.levels) {
      for (final t in level.templates) {
        expect(() => t.validateAgainst(skill.timeSignature), returnsNormally,
            reason: t.id);
      }
    }
  });

  test('levels 1/2: Single Paradiddle stated twice per measure — RLRR '
      'LRLL RLRR LRLL (or mirrored), accent on the first stroke of every '
      '4-note group', () {
    for (final level in [skill.level(1), skill.level(2)]) {
      for (final t in level.templates) {
        final labels = t.sticking.map((h) => h.label).toList();
        expect(labels, hasLength(16));
        final lead = labels[0];
        final other = lead == 'R' ? 'L' : 'R';
        final oneGroup = [lead, other, lead, lead];
        final otherGroup = [other, lead, other, other];
        expect(labels, [
          ...oneGroup,
          ...otherGroup,
          ...oneGroup,
          ...otherGroup,
        ], reason: t.id);
        for (var g = 0; g < 4; g++) {
          expect(t.rhythm[g * 4].isAccented, isTrue,
              reason: '${t.id} group $g lead stroke');
          for (var n = 1; n < 4; n++) {
            expect(t.rhythm[g * 4 + n].isAccented, isFalse,
                reason: '${t.id} group $g note $n');
          }
        }
      }
    }
  });

  test('level 3: Triple Paradiddle — RLRLRLRR LRLRLRLL (or mirrored), '
      'accent on the first stroke of each 8-note half', () {
    for (final t in skill.level(3).templates) {
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
      for (final i in [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]) {
        expect(t.rhythm[i].isAccented, isFalse, reason: '${t.id} note $i');
      }
    }
  });

  test('generator produces valid 16-exercise sessions for every level', () {
    for (var level = 1; level <= 3; level++) {
      final session = SessionGenerator(seed: 8)
          .generate(skill: skill, levelNumber: level);
      expect(session.exercises, hasLength(16), reason: 'level $level');
    }
  });
}
