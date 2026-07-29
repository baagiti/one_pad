import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_pad/domain/content/content_loader.dart';
import 'package:one_pad/domain/generation/session_generator.dart';
import 'package:one_pad/domain/model/skill.dart';

void main() {
  late Skill skill;

  setUpAll(() {
    skill = ContentLoader().loadSkill(
        File('content/skills/sixteenth_notes.json').readAsStringSync());
  });

  test('loads skill metadata (roadmap title "Sixteenth Notes")', () {
    expect(skill.id, 'sixteenth_notes');
    expect(skill.name, 'Sixteenth Notes');
    expect(skill.bpmDefault, 50);
  });

  test('has 8 levels: How to Count intro + 7 (3 figure levels, rests, then '
      'the 3-level full-stream sub-curriculum reused from Skill 3 — design '
      'doc §21)', () {
    expect(skill.levels.map((l) => l.level), [0, 1, 2, 3, 4, 5, 6, 7]);
    expect(skill.level(0).name, 'How to Count: Sixteenth Notes');
  });

  test('How to Count: countingLabels are exactly "1 e & a 2 e & a..." for '
      'every template', () {
    const expected = [
      '1', 'e', '&', 'a', '2', 'e', '&', 'a',
      '3', 'e', '&', 'a', '4', 'e', '&', 'a',
    ];
    for (final t in skill.level(0).templates) {
      expect(t.countingLabels, expected, reason: t.id);
      expect(t.rhythm.every((n) => n.duration.code == 's'), isTrue,
          reason: t.id);
    }
  });

  test('levels 1-3 (figure levels): 4 beat positions x 2 hands', () {
    expect(skill.level(1).templates, hasLength(8));
    expect(skill.level(2).templates, hasLength(8));
    expect(skill.level(3).templates, hasLength(8));
  });

  test('level 4 (rests): 4 beat positions x 2 rest figures x 2 hands', () {
    expect(skill.level(4).templates, hasLength(16));
  });

  test('levels 5-7 (full stream): pool sizes match Skill 3\'s sub-curriculum',
      () {
    expect(skill.level(5).templates, hasLength(2));
    expect(skill.level(6).templates, hasLength(2));
    expect(skill.level(7).templates, hasLength(4));
  });

  test('only level 1 carries a BPM-variety practice note (easing into the '
      'new hand-speed demand, same rationale as Skill 3 Level 1)', () {
    expect(skill.level(1).note, isNotNull);
    for (var level = 2; level <= 7; level++) {
      expect(skill.level(level).note, isNull, reason: 'level $level');
    }
  });

  test('level 5 is sessionFixed (one lead hand for the whole session); '
      'level 6 is not (forces switching every measure)', () {
    expect(skill.level(5).generation.sessionFixed, isTrue);
    expect(skill.level(6).generation.sessionFixed, isFalse);
    final session =
        SessionGenerator(seed: 7).generate(skill: skill, levelNumber: 5);
    expect(session.exercises.map((e) => e.templateId).toSet(), hasLength(1));
  });

  test('every template validates against 4/4', () {
    for (final level in skill.levels) {
      for (final t in level.templates) {
        expect(() => t.validateAgainst(skill.timeSignature), returnsNormally,
            reason: t.id);
      }
    }
  });

  test('levels 1-3: sticking is plain sequential alternation across '
      'whatever is struck (no ghost grid — mixed note lengths, design '
      'doc §17/§21)', () {
    for (final level in [skill.level(1), skill.level(2), skill.level(3)]) {
      for (final t in level.templates) {
        final labels = t.sticking.map((h) => h.label).toList();
        for (var i = 1; i < labels.length; i++) {
          expect(labels[i], isNot(labels[i - 1]),
              reason: '${t.id}: two same-hand notes in a row at index $i');
        }
      }
    }
  });

  test('level 4: the rested slot is always inside the one 4-sixteenth '
      'figure beat, never inside the surrounding eighth-pair beats', () {
    for (final t in skill.level(4).templates) {
      final restIndices = <int>[
        for (var i = 0; i < t.rhythm.length; i++)
          if (t.rhythm[i].isRest) i,
      ];
      expect(restIndices, hasLength(1), reason: t.id);
      // The figure beat is always the first 4 tokens of some 4-token
      // window; a rest can only ever land among the sixteenth (not
      // eighth) tokens.
      expect(t.rhythm[restIndices.single].duration.code, 's', reason: t.id);
    }
  });

  test('generator produces valid 16-exercise sessions for every level', () {
    for (var level = 1; level <= 7; level++) {
      final session = SessionGenerator(seed: 21)
          .generate(skill: skill, levelNumber: level);
      expect(session.exercises, hasLength(16), reason: 'level $level');
    }
  });
}
