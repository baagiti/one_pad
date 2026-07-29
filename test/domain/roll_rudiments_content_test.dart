import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_pad/domain/content/content_loader.dart';
import 'package:one_pad/domain/generation/session_generator.dart';
import 'package:one_pad/domain/model/skill.dart';

void main() {
  late Skill skill;

  setUpAll(() {
    skill = ContentLoader().loadSkill(
        File('content/skills/roll_rudiments.json').readAsStringSync());
  });

  test('loads skill metadata (roadmap title "Rudiments: Roll Family")', () {
    expect(skill.id, 'roll_rudiments');
    expect(skill.name, 'Rudiments: Roll Family');
  });

  test('has 4 levels: Double Stroke Roll (2026-07-27 addition, the '
      'building block), then 5-Stroke, 7-Stroke, 9-Stroke Roll — "Tier 2" '
      'PAS rudiments taught right after it', () {
    expect(skill.levels.map((l) => l.level), [1, 2, 3, 4]);
    for (final level in skill.levels) {
      expect(level.templates, hasLength(2), reason: 'level ${level.level}');
      expect(level.generation.sessionFixed, isTrue,
          reason: 'level ${level.level}');
    }
  });

  test('level 1: Double Stroke Roll — a full measure of sustained open '
      'doubles ("RRLLRRLL..."), no accent (unlike the rolls that follow)',
      () {
    for (final t in skill.level(1).templates) {
      final labels = t.sticking.map((h) => h.label).toList();
      expect(labels, hasLength(16));
      final lead = labels[0];
      final other = lead == 'R' ? 'L' : 'R';
      final expected = [
        for (var i = 0; i < 8; i++) ...[
          i.isEven ? lead : other,
          i.isEven ? lead : other,
        ],
      ];
      expect(labels, expected, reason: t.id);
      expect(t.rhythm.every((n) => n.duration.code == 's'), isTrue,
          reason: t.id);
      expect(t.rhythm.every((n) => !n.isAccented), isTrue, reason: t.id);
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

  test('level 2: 5-Stroke Roll — RRLLR LLRRL (or mirrored), accent on '
      'each half\'s final (5th) stroke', () {
    for (final t in skill.level(2).templates) {
      final labels = t.sticking.map((h) => h.label).toList();
      expect(labels, hasLength(10));
      final lead = labels[0];
      final other = lead == 'R' ? 'L' : 'R';
      expect(labels, [
        lead, lead, other, other, lead,
        other, other, lead, lead, other,
      ], reason: t.id);
      expect(t.rhythm[4].isAccented, isTrue, reason: t.id);
      expect(t.rhythm[4].duration.code, 'q', reason: t.id);
      expect(t.rhythm[9].isAccented, isTrue, reason: t.id);
    }
  });

  test('level 3: 7-Stroke Roll — RRLLRRL LLRRLLR (or mirrored), accent on '
      'each half\'s final (7th) stroke', () {
    for (final t in skill.level(3).templates) {
      final labels = t.sticking.map((h) => h.label).toList();
      expect(labels, hasLength(14));
      final lead = labels[0];
      final other = lead == 'R' ? 'L' : 'R';
      expect(labels, [
        lead, lead, other, other, lead, lead, other,
        other, other, lead, lead, other, other, lead,
      ], reason: t.id);
      expect(t.rhythm[6].isAccented, isTrue, reason: t.id);
      expect(t.rhythm[6].duration.code, 'e', reason: t.id);
    }
  });

  test('level 4: 9-Stroke Roll — RRLLRRLLR (or mirrored), a single '
      'measure-filling template (no mirrored half needed), accent on the '
      'final stroke', () {
    for (final t in skill.level(4).templates) {
      final labels = t.sticking.map((h) => h.label).toList();
      expect(labels, hasLength(9));
      final lead = labels[0];
      final other = lead == 'R' ? 'L' : 'R';
      expect(labels,
          [lead, lead, other, other, lead, lead, other, other, lead],
          reason: t.id);
      expect(t.rhythm[8].isAccented, isTrue, reason: t.id);
      expect(t.rhythm[8].duration.code, 'h', reason: t.id);
    }
  });

  test('generator produces valid 16-exercise sessions for every level', () {
    for (var level = 1; level <= 4; level++) {
      final session = SessionGenerator(seed: 28)
          .generate(skill: skill, levelNumber: level);
      expect(session.exercises, hasLength(16), reason: 'level $level');
    }
  });
}
