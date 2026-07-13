import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_pad/domain/content/content_loader.dart';
import 'package:one_pad/domain/model/skill.dart';
import 'package:one_pad/domain/model/time_signature.dart';

void main() {
  late Skill skill;

  setUpAll(() {
    final jsonString =
        File('content/skills/quarter_note_pulse.json').readAsStringSync();
    skill = ContentLoader().loadSkill(jsonString);
  });

  test('loads skill metadata', () {
    expect(skill.id, 'quarter_note_pulse');
    expect(skill.timeSignature, TimeSignature.fourFour);
    expect(skill.bpmDefault, 70);
    expect(skill.bpmMin, 50);
    expect(skill.bpmMax, 120);
  });

  test('has 4 levels with expected pool sizes', () {
    expect(skill.levels.map((l) => l.level), [1, 2, 3, 4]);
    expect(skill.level(1).templates, hasLength(2));
    expect(skill.level(2).templates, hasLength(2));
    expect(skill.level(3).templates, hasLength(4));
    // 16 R/L combinations minus the two pure alternations.
    expect(skill.level(4).templates, hasLength(14));
  });

  test('every template is 4 quarter notes with full sticking', () {
    for (final level in skill.levels) {
      for (final t in level.templates) {
        expect(t.rhythm, hasLength(4), reason: t.id);
        expect(t.rhythm.every((n) => !n.isRest), isTrue, reason: t.id);
        expect(t.sticking, hasLength(4), reason: t.id);
      }
    }
  });

  test('template ids are globally unique', () {
    final ids = [
      for (final l in skill.levels) ...l.templates.map((t) => t.id)
    ];
    expect(ids.toSet(), hasLength(ids.length));
  });

  test('level 4 contains no pure alternation', () {
    for (final t in skill.level(4).templates) {
      final s = t.sticking.map((h) => h.label).join();
      expect(s, isNot(anyOf('RLRL', 'LRLR')), reason: t.id);
    }
  });

  test('rejects unsupported schema version', () {
    expect(
      () => ContentLoader().loadSkill('{"schemaVersion": 99}'),
      throwsFormatException,
    );
  });
}
