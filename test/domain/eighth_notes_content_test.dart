import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_pad/domain/content/content_loader.dart';
import 'package:one_pad/domain/generation/session_generator.dart';
import 'package:one_pad/domain/model/skill.dart';

void main() {
  late Skill skill;

  setUpAll(() {
    skill = ContentLoader().loadSkill(
        File('content/skills/eighth_notes.json').readAsStringSync());
  });

  test('loads skill metadata', () {
    expect(skill.id, 'eighth_notes');
    expect(skill.bpmDefault, 60);
    expect(skill.bpmMin, 30);
    expect(skill.bpmMax, 140);
  });

  test('has 8 levels: How to Count intro + 7 (no "free sticking reading" '
      'level — see design doc §17)', () {
    expect(skill.levels.map((l) => l.level), [0, 1, 2, 3, 4, 5, 6, 7]);
    expect(skill.level(0).name, 'How to Count: Eighth Notes');
  });

  test('How to Count: countingLabels are exactly "1 & 2 & 3 & 4 &", one '
      'per token, for every template', () {
    for (final t in skill.level(0).templates) {
      expect(t.countingLabels,
          ['1', '&', '2', '&', '3', '&', '4', '&'], reason: t.id);
      expect(t.rhythm.every((n) => n.duration.code == 'e'), isTrue,
          reason: t.id);
    }
  });

  test('density levels (1-4) pool sizes follow the combinatorics', () {
    expect(skill.level(1).templates, hasLength(8)); // 4 positions x 2 hands
    expect(skill.level(2).templates, hasLength(6)); // 3 non-adjacent x 2
    expect(skill.level(3).templates, hasLength(6)); // 3 adjacent x 2
    expect(skill.level(4).templates, hasLength(8)); // 4 positions x 2 hands
  });

  test('only level 1 carries a BPM-variety practice note', () {
    expect(skill.level(1).note, isNotNull);
    for (var level = 2; level <= 7; level++) {
      expect(skill.level(level).note, isNull, reason: 'level $level');
    }
  });

  test('density levels: total rhythm duration is always 4 beats', () {
    for (var level = 1; level <= 4; level++) {
      for (final t in skill.level(level).templates) {
        expect(() => t.validateAgainst(skill.timeSignature), returnsNormally,
            reason: t.id);
      }
    }
  });

  test(
      'density levels: sticking is always plain alternation, regardless of '
      'where the eighth-pair falls (revised model — see design doc §17: a '
      'held quarter note is not "ghosted" the way a rest is)', () {
    for (var level = 1; level <= 4; level++) {
      for (final t in skill.level(level).templates) {
        final labels = t.sticking.map((h) => h.label).toList();
        for (var i = 1; i < labels.length; i++) {
          expect(labels[i], isNot(labels[i - 1]),
              reason: '${t.id}: two same-hand notes in a row at index $i');
        }
      }
    }
  });

  test('full-stream levels (5-7) are always 8 eighth notes, no rests', () {
    for (var level = 5; level <= 7; level++) {
      for (final t in skill.level(level).templates) {
        expect(t.rhythm, hasLength(8), reason: t.id);
        expect(t.rhythm.every((n) => !n.isRest), isTrue, reason: t.id);
        expect(t.sticking, hasLength(8), reason: t.id);
      }
    }
  });

  test('generator produces valid 16-exercise sessions for every level', () {
    for (var level = 1; level <= 7; level++) {
      final session = SessionGenerator(seed: 11)
          .generate(skill: skill, levelNumber: level);
      expect(session.exercises, hasLength(16), reason: 'level $level');
    }
  });

  test(
      'level 5 is sessionFixed (one lead hand for the whole session); '
      'level 6 is not (forces switching every measure)', () {
    expect(skill.level(5).generation.sessionFixed, isTrue);
    expect(skill.level(6).generation.sessionFixed, isFalse);

    final level5Session =
        SessionGenerator(seed: 3).generate(skill: skill, levelNumber: 5);
    expect(
        level5Session.exercises.map((e) => e.templateId).toSet(), hasLength(1));

    final level6Session =
        SessionGenerator(seed: 3).generate(skill: skill, levelNumber: 6);
    for (var i = 1; i < level6Session.exercises.length; i++) {
      expect(level6Session.exercises[i].templateId,
          isNot(level6Session.exercises[i - 1].templateId));
    }
  });
}
