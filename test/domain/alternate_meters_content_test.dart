import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_pad/domain/content/content_loader.dart';
import 'package:one_pad/domain/generation/session_generator.dart';
import 'package:one_pad/domain/model/skill.dart';
import 'package:one_pad/domain/model/time_signature.dart';

void main() {
  group('alternate_meters_34.json (3/4, simple triple)', () {
    late Skill skill;

    setUpAll(() {
      skill = ContentLoader().loadSkill(
          File('content/skills/alternate_meters_34.json').readAsStringSync());
    });

    test('loads skill metadata — 3/4 time signature', () {
      expect(skill.id, 'alternate_meters_34');
      expect(skill.timeSignature, const TimeSignature(3, 4));
      expect(skill.timeSignature.isCompound, isFalse);
    });

    test('has 2 levels: quarter pulse, then eighth-pair transfer', () {
      expect(skill.levels.map((l) => l.level), [1, 2]);
      expect(skill.level(1).templates, hasLength(2));
      expect(skill.level(2).templates, hasLength(6));
    });

    test('every template validates against 3/4 (3 beats, not 4)', () {
      for (final level in skill.levels) {
        for (final t in level.templates) {
          expect(() => t.validateAgainst(skill.timeSignature), returnsNormally,
              reason: t.id);
        }
      }
    });

    test('level 1 is a 3-beat pulse with plain alternation', () {
      for (final t in skill.level(1).templates) {
        expect(t.rhythm, hasLength(3));
        final labels = t.sticking.map((h) => h.label).toList();
        for (var i = 1; i < labels.length; i++) {
          expect(labels[i], isNot(labels[i - 1]), reason: t.id);
        }
      }
    });

    test('generator produces valid 16-exercise sessions for every level',
        () {
      for (var level = 1; level <= 2; level++) {
        final session = SessionGenerator(seed: 10)
            .generate(skill: skill, levelNumber: level);
        expect(session.exercises, hasLength(16), reason: 'level $level');
      }
    });
  });

  group('alternate_meters_68.json (6/8, compound duple)', () {
    late Skill skill;

    setUpAll(() {
      skill = ContentLoader().loadSkill(
          File('content/skills/alternate_meters_68.json').readAsStringSync());
    });

    test('loads skill metadata — 6/8 time signature, compound', () {
      expect(skill.id, 'alternate_meters_68');
      expect(skill.timeSignature, const TimeSignature(6, 8));
      expect(skill.timeSignature.isCompound, isTrue);
    });

    test('has 6 levels: How to Count intro, eighth stream, dotted-quarter '
        'pulse, Double Paradiddle, Single Paradiddle-Diddle (both '
        'rudiments\' natural home — design doc §25/§28), then Duplets '
        '(2026-07-27 addition)', () {
      expect(skill.levels.map((l) => l.level), [0, 1, 2, 3, 4, 5]);
      expect(skill.level(0).templates, hasLength(2));
      expect(skill.level(0).name, 'How to Count: 6/8');
      for (final t in skill.level(0).templates) {
        expect(t.countingLabels, ['1', '&', 'a', '2', '&', 'a'],
            reason: '${t.id}: deliberately different from 4/4 sixteenth '
                'notes\' "1 e & a" — same-looking syllables, different '
                'pulse');
      }
      expect(skill.level(1).templates, hasLength(2));
      expect(skill.level(2).templates, hasLength(2));
      expect(skill.level(3).templates, hasLength(2));
      expect(skill.level(4).templates, hasLength(2));
      expect(skill.level(5).templates, hasLength(4));
    });

    test('every template validates against 6/8', () {
      for (final level in skill.levels) {
        for (final t in level.templates) {
          expect(() => t.validateAgainst(skill.timeSignature), returnsNormally,
              reason: t.id);
        }
      }
    });

    test('level 2: two dotted quarters — the compound "feel 2" pulse', () {
      for (final t in skill.level(2).templates) {
        expect(t.rhythm, hasLength(2));
        expect(t.rhythm.every((tok) => tok.isDotted), isTrue, reason: t.id);
      }
    });

    test('level 3: Double Paradiddle — RLRLRR LRLRLL (or mirrored), '
        'accent on the first stroke of each 6-note half', () {
      for (final t in skill.level(3).templates) {
        final labels = t.sticking.map((h) => h.label).toList();
        expect(labels, hasLength(12));
        final lead = labels[0];
        final other = lead == 'R' ? 'L' : 'R';
        expect(labels, [
          lead, other, lead, other, lead, lead,
          other, lead, other, lead, other, other,
        ], reason: t.id);
        expect(t.rhythm[0].isAccented, isTrue, reason: t.id);
        expect(t.rhythm[6].isAccented, isTrue, reason: t.id);
      }
    });

    test('level 4: Single Paradiddle-Diddle — RLRRLL LRLLRR (or mirrored), '
        'accent on the first stroke of each 6-note half', () {
      for (final t in skill.level(4).templates) {
        final labels = t.sticking.map((h) => h.label).toList();
        expect(labels, hasLength(12));
        final lead = labels[0];
        final other = lead == 'R' ? 'L' : 'R';
        expect(labels, [
          lead, other, lead, lead, other, other,
          other, lead, other, other, lead, lead,
        ], reason: t.id);
        expect(t.rhythm[0].isAccented, isTrue, reason: t.id);
        expect(t.rhythm[6].isAccented, isTrue, reason: t.id);
      }
    });

    test('level 5: Duplets — exactly 2 isDuplet eighth notes per template, '
        'the other pulse stays a plain dotted quarter', () {
      for (final t in skill.level(5).templates) {
        final dupletCount = t.rhythm.where((tok) => tok.isDuplet).length;
        expect(dupletCount, 2, reason: t.id);
        expect(
            t.rhythm.where((tok) => tok.isDuplet).every((tok) =>
                tok.duration.code == 'e'),
            isTrue,
            reason: t.id);
        expect(t.rhythm.where((tok) => !tok.isDuplet), hasLength(1),
            reason: t.id);
        expect(t.rhythm.where((tok) => !tok.isDuplet).single.isDotted, isTrue,
            reason: t.id);
      }
    });

    test('generator produces valid 16-exercise sessions for every level',
        () {
      for (var level = 1; level <= 5; level++) {
        final session = SessionGenerator(seed: 11)
            .generate(skill: skill, levelNumber: level);
        expect(session.exercises, hasLength(16), reason: 'level $level');
      }
    });
  });
}
