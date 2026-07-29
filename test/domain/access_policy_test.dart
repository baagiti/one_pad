import 'package:flutter_test/flutter_test.dart';
import 'package:one_pad/domain/progress/access_policy.dart';

void main() {
  test('exactly the first three roadmap skills are free (2026-07-27)', () {
    expect(freeSkillIds, {
      'quarter_note_pulse',
      'quarter_note_rests',
      'eighth_notes',
    });
  });

  test('isSkillFree matches the free set and rejects everything else', () {
    expect(isSkillFree('quarter_note_pulse'), isTrue);
    expect(isSkillFree('eighth_notes'), isTrue);
    expect(isSkillFree('sixteenth_notes'), isFalse);
    expect(isSkillFree('performance_foundations'), isFalse);
  });

  test('the free daily session cap is 3, the free-tier bpm is 60', () {
    expect(freeDailySessionCap, 3);
    expect(freeBpm, 60);
  });

  group('decideGate (2026-07-27, the exact tap-time decision)', () {
    test('premium always allows, regardless of skill or count', () {
      expect(
        decideGate(
          premium: true,
          skillId: 'performance_foundations',
          alreadyUnlockedToday: false,
          todayUnlockCount: 99,
        ),
        GateDecision.allow,
      );
    });

    test('a non-free skill is upsellLocked even with zero unlocks used',
        () {
      expect(
        decideGate(
          premium: false,
          skillId: 'sixteenth_notes',
          alreadyUnlockedToday: false,
          todayUnlockCount: 0,
        ),
        GateDecision.upsellLocked,
      );
    });

    test('the 1st, 2nd and 3rd new unlocks of the day are allowed', () {
      for (final countSoFar in [0, 1, 2]) {
        expect(
          decideGate(
            premium: false,
            skillId: 'quarter_note_pulse',
            alreadyUnlockedToday: false,
            todayUnlockCount: countSoFar,
          ),
          GateDecision.allow,
          reason: 'count so far: $countSoFar',
        );
      }
    });

    test('a 4th NEW lesson is blocked once 3 are already used today', () {
      expect(
        decideGate(
          premium: false,
          skillId: 'quarter_note_pulse',
          alreadyUnlockedToday: false,
          todayUnlockCount: 3,
        ),
        GateDecision.upsellCapReached,
      );
    });

    test(
        're-opening one of today\'s 3 already-unlocked lessons is still '
        'allowed at the cap — that\'s the whole point of "Today\'s '
        'Lessons"', () {
      expect(
        decideGate(
          premium: false,
          skillId: 'quarter_note_pulse',
          alreadyUnlockedToday: true,
          todayUnlockCount: 3,
        ),
        GateDecision.allow,
      );
    });
  });
}
