import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_pad/domain/content/content_loader.dart';
import 'package:one_pad/domain/generation/session_generator.dart';
import 'package:one_pad/domain/model/skill.dart';

void main() {
  late Skill skill;

  setUpAll(() {
    skill = ContentLoader().loadSkill(File(
            'content/skills/offbeat_eighth_notes.json')
        .readAsStringSync());
  });

  test('loads skill metadata (roadmap title "Eighth Notes + Rests")', () {
    expect(skill.id, 'offbeat_eighth_notes');
    expect(skill.name, 'Eighth Notes + Rests');
    expect(skill.bpmDefault, 70);
  });

  test('has 4 levels (2-offbeat spread/consecutive merged — see design '
      'doc §18: adjacency isn\'t a real difficulty axis for offbeats)', () {
    expect(skill.levels.map((l) => l.level), [1, 2, 3, 4]);
  });

  test('pool sizes follow the position-permutation combinatorics', () {
    expect(skill.level(1).templates, hasLength(8)); // 4 positions x 2 hands
    expect(skill.level(2).templates, hasLength(12)); // 6 positions x 2 hands
    expect(skill.level(3).templates, hasLength(8)); // 4 positions x 2 hands
    expect(skill.level(4).templates, hasLength(2)); // 2 lead hands only
  });

  test('level 4 is sessionFixed ("all and\'s" — one lead hand per session)',
      () {
    expect(skill.level(4).generation.sessionFixed, isTrue);
    final session =
        SessionGenerator(seed: 4).generate(skill: skill, levelNumber: 4);
    expect(session.exercises.map((e) => e.templateId).toSet(), hasLength(1));
  });

  test('an offbeat beat is rest-then-note, never note-then-rest '
      '(design doc §18: the audibly-quarter-equivalent shape is excluded)',
      () {
    for (final level in skill.levels) {
      for (final t in level.templates) {
        for (var i = 0; i < t.rhythm.length; i += 2) {
          final first = t.rhythm[i];
          final second = t.rhythm[i + 1];
          if (first.isRest || second.isRest) {
            expect(first.isRest, isTrue, reason: '${t.id} beat ${i ~/ 2}');
            expect(second.isRest, isFalse, reason: '${t.id} beat ${i ~/ 2}');
          }
        }
      }
    }
  });

  test('every template validates against 4/4', () {
    for (final level in skill.levels) {
      for (final t in level.templates) {
        expect(() => t.validateAgainst(skill.timeSignature), returnsNormally,
            reason: t.id);
      }
    }
  });

  test(
      'sticking is plain sequential alternation regardless of offbeat '
      'placement', () {
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
    for (var level = 1; level <= 4; level++) {
      final session = SessionGenerator(seed: 9)
          .generate(skill: skill, levelNumber: level);
      expect(session.exercises, hasLength(16), reason: 'level $level');
    }
  });
}
