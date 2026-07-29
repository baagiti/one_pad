import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_pad/domain/content/content_loader.dart';
import 'package:one_pad/domain/generation/session_generator.dart';
import 'package:one_pad/domain/model/skill.dart';

void main() {
  late Skill skill;

  setUpAll(() {
    skill = ContentLoader().loadSkill(
        File('content/skills/thirty_second_notes.json').readAsStringSync());
  });

  test('loads skill metadata (roadmap title "32nd Notes")', () {
    expect(skill.id, 'thirty_second_notes');
    expect(skill.name, '32nd Notes');
    expect(skill.bpmDefault, 25);
    expect(skill.bpmMin, 10);
    expect(skill.bpmMax, 50);
  });

  test('has 2 levels: isolate the new sound, then a full steady-stream '
      'measure — deliberately smaller than Sixteenth Notes\' 7 levels, the '
      'sticking sub-curriculum was already exhausted at that tier', () {
    expect(skill.levels.map((l) => l.level), [1, 2]);
  });

  test('every template validates against 4/4', () {
    for (final level in skill.levels) {
      for (final t in level.templates) {
        expect(() => t.validateAgainst(skill.timeSignature), returnsNormally,
            reason: t.id);
      }
    }
  });

  test('level 1: exactly one beat is a full 32nd-note group (8 notes), '
      'the other 3 beats are full sixteenth-note groups (4 notes each)', () {
    for (final t in skill.level(1).templates) {
      final thirtySecondNotes =
          t.rhythm.where((tok) => tok.duration.code == 'x').toList();
      expect(thirtySecondNotes, hasLength(8), reason: t.id);
      final sixteenths =
          t.rhythm.where((tok) => tok.duration.code == 's').toList();
      expect(sixteenths, hasLength(12), reason: t.id);
    }
    expect(skill.level(1).note, isNotNull);
  });

  test('level 2: a full measure of 32 thirty-second notes, steady '
      'alternation, sessionFixed', () {
    for (final t in skill.level(2).templates) {
      expect(t.rhythm, hasLength(32));
      expect(t.rhythm.every((tok) => tok.duration.code == 'x'), isTrue,
          reason: t.id);
      final labels = t.sticking.map((h) => h.label).toList();
      for (var i = 1; i < labels.length; i++) {
        expect(labels[i], isNot(labels[i - 1]), reason: t.id);
      }
    }
    expect(skill.level(2).generation.sessionFixed, isTrue);
  });

  test('generator produces valid 16-exercise sessions for every level', () {
    for (var level = 1; level <= 2; level++) {
      final session = SessionGenerator(seed: 32)
          .generate(skill: skill, levelNumber: level);
      expect(session.exercises, hasLength(16), reason: 'level $level');
    }
  });
}
