import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_pad/domain/content/content_loader.dart';
import 'package:one_pad/domain/generation/session_generator.dart';
import 'package:one_pad/domain/model/skill.dart';
import 'package:one_pad/domain/model/time_signature.dart';

void main() {
  group('odd_meters_54.json (5/4, simple, odd count)', () {
    late Skill skill;

    setUpAll(() {
      skill = ContentLoader().loadSkill(
          File('content/skills/odd_meters_54.json').readAsStringSync());
    });

    test('loads skill metadata — 5/4 time signature, no beat group pattern '
        'needed (quarter notes are never beamed)', () {
      expect(skill.id, 'odd_meters_54');
      expect(skill.timeSignature, const TimeSignature(5, 4));
      expect(skill.beatGroupPattern, isNull);
    });

    test('has 2 levels: quarter pulse, then eighth-pair transfer', () {
      expect(skill.levels.map((l) => l.level), [1, 2]);
      expect(skill.level(1).templates, hasLength(2));
      expect(skill.level(2).templates, hasLength(10));
    });

    test('every template validates against 5/4 (5 beats)', () {
      for (final level in skill.levels) {
        for (final t in level.templates) {
          expect(() => t.validateAgainst(skill.timeSignature), returnsNormally,
              reason: t.id);
        }
      }
    });

    test('level 1 is a 5-beat pulse with plain alternation', () {
      for (final t in skill.level(1).templates) {
        expect(t.rhythm, hasLength(5));
      }
    });

    test('generator produces valid 16-exercise sessions for every level',
        () {
      for (var level = 1; level <= 2; level++) {
        final session = SessionGenerator(seed: 12)
            .generate(skill: skill, levelNumber: level);
        expect(session.exercises, hasLength(16), reason: 'level $level');
      }
    });
  });

  group('odd_meters_78.json (7/8, asymmetric, 2+2+3)', () {
    late Skill skill;

    setUpAll(() {
      skill = ContentLoader().loadSkill(
          File('content/skills/odd_meters_78.json').readAsStringSync());
    });

    test('loads skill metadata — 7/8 time signature with an explicit '
        '2+2+3 beam-group pattern (design doc §26: 7/8 has no single '
        'derivable grouping)', () {
      expect(skill.id, 'odd_meters_78');
      expect(skill.timeSignature, const TimeSignature(7, 8));
      expect(skill.beatGroupPattern, [2, 2, 3]);
    });

    test('has 3 levels: How to Count intro, full eighth stream, then the '
        'group-pulse reading', () {
      expect(skill.levels.map((l) => l.level), [0, 1, 2]);
      expect(skill.level(0).templates, hasLength(2));
      expect(skill.level(0).name, 'How to Count: 7/8');
      for (final t in skill.level(0).templates) {
        expect(t.countingLabels, ['1', '&', '2', '&', '3', '&', 'a'],
            reason: '${t.id}: last group of 3 counted compound-style '
                '("a"), matching this skill\'s own 2+2+3 beatGroupPattern');
      }
      expect(skill.level(1).templates, hasLength(2));
      expect(skill.level(2).templates, hasLength(2));
    });

    test('every template validates against 7/8 (7 beats)', () {
      for (final level in skill.levels) {
        for (final t in level.templates) {
          expect(() => t.validateAgainst(skill.timeSignature), returnsNormally,
              reason: t.id);
        }
      }
    });

    test('level 2: q, q, q. exactly fills 7/8 as 2+2+3', () {
      for (final t in skill.level(2).templates) {
        expect(t.rhythm.map((tok) => tok.code), ['q', 'q', 'q.']);
      }
    });

    test('the session\'s beatGroupPattern flows through from the skill '
        '(design doc §26)', () {
      final session =
          SessionGenerator(seed: 13).generate(skill: skill, levelNumber: 1);
      expect(session.beatGroupPattern, [2, 2, 3]);
    });

    test('generator produces valid 16-exercise sessions for every level',
        () {
      for (var level = 1; level <= 2; level++) {
        final session = SessionGenerator(seed: 14)
            .generate(skill: skill, levelNumber: level);
        expect(session.exercises, hasLength(16), reason: 'level $level');
      }
    });
  });
}
