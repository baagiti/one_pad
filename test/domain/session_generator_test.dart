import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_pad/domain/content/content_loader.dart';
import 'package:one_pad/domain/generation/session_generator.dart';
import 'package:one_pad/domain/model/session.dart';
import 'package:one_pad/domain/model/skill.dart';

void main() {
  late Skill skill;

  setUpAll(() {
    final jsonString =
        File('content/skills/quarter_note_pulse.json').readAsStringSync();
    skill = ContentLoader().loadSkill(jsonString);
  });

  Session gen(int level, int seed) =>
      SessionGenerator(seed: seed).generate(skill: skill, levelNumber: level);

  test('always produces exactly 16 exercises with correct indices', () {
    for (var level = 1; level <= 4; level++) {
      final s = gen(level, 42);
      expect(s.exercises, hasLength(Session.exerciseCount));
      expect(s.exercises.map((e) => e.index), List.generate(16, (i) => i));
    }
  });

  test('is deterministic for the same seed, varies across seeds', () {
    List<String> ids(int seed) =>
        gen(4, seed).exercises.map((e) => e.templateId).toList();

    expect(ids(7), ids(7));
    // With a 14-template pool two seeds virtually never collide fully.
    expect(ids(7), isNot(ids(8)));
  });

  test('uses default BPM from skill, honors explicit BPM', () {
    expect(gen(1, 1).bpm, 70);
    final custom = SessionGenerator(seed: 1)
        .generate(skill: skill, levelNumber: 1, bpm: 95);
    expect(custom.bpm, 95);
  });

  test('level 2 forces strict lead-hand alternation (pool of 2 + noAdjacentRepeat)',
      () {
    for (var seed = 0; seed < 100; seed++) {
      final s = gen(2, seed);
      for (var i = 1; i < s.exercises.length; i++) {
        expect(s.exercises[i].templateId,
            isNot(s.exercises[i - 1].templateId),
            reason: 'seed $seed, slot $i');
      }
    }
  });

  test('noAdjacentRepeat holds on levels 3 and 4 across many seeds', () {
    for (final level in [3, 4]) {
      for (var seed = 0; seed < 200; seed++) {
        final s = gen(level, seed);
        for (var i = 1; i < s.exercises.length; i++) {
          expect(s.exercises[i].templateId,
              isNot(s.exercises[i - 1].templateId),
              reason: 'level $level, seed $seed, slot $i');
        }
      }
    }
  });

  test('minVariety is respected', () {
    for (var seed = 0; seed < 200; seed++) {
      final distinct3 =
          gen(3, seed).exercises.map((e) => e.templateId).toSet().length;
      expect(distinct3, greaterThanOrEqualTo(3), reason: 'seed $seed');

      final distinct4 =
          gen(4, seed).exercises.map((e) => e.templateId).toSet().length;
      expect(distinct4, greaterThanOrEqualTo(6), reason: 'seed $seed');
    }
  });

  test('difficultyRamp: first half is on average no harder than second half',
      () {
    double meanDifficulty(Iterable<int> xs) =>
        xs.fold<int>(0, (a, b) => a + b) / xs.length;

    final byId = {
      for (final t in skill.level(4).templates) t.id: t.difficulty
    };
    for (var seed = 0; seed < 100; seed++) {
      final diffs = gen(4, seed)
          .exercises
          .map((e) => byId[e.templateId]!)
          .toList();
      final firstHalf = meanDifficulty(diffs.take(8));
      final secondHalf = meanDifficulty(diffs.skip(8));
      expect(firstHalf, lessThanOrEqualTo(secondHalf + 1e-9),
          reason: 'seed $seed: $diffs');
    }
  });

  test('exercises are snapshots — mutating template list later is impossible',
      () {
    final s = gen(1, 5);
    expect(() => s.exercises.first.rhythm.clear(), throwsUnsupportedError);
    expect(() => s.exercises.first.sticking.clear(), throwsUnsupportedError);
  });
}
