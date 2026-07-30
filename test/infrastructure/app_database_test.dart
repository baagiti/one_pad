import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_pad/infrastructure/storage/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  test('completed count starts at zero for an untouched level', () async {
    final count =
        await db.watchCompletedCount(skillId: 'qnp', level: 1).first;
    expect(count, 0);
  });

  test('recordCompleted increments the count for that skill+level only',
      () async {
    await db.recordCompleted(skillId: 'qnp', level: 1, bpm: 70);
    await db.recordCompleted(skillId: 'qnp', level: 1, bpm: 80);
    await db.recordCompleted(skillId: 'qnp', level: 2, bpm: 70);

    expect(await db.watchCompletedCount(skillId: 'qnp', level: 1).first, 2);
    expect(await db.watchCompletedCount(skillId: 'qnp', level: 2).first, 1);
    expect(await db.watchCompletedCount(skillId: 'qnp', level: 3).first, 0);
  });

  test('watchCompletedCount emits a new value as sessions are recorded',
      () async {
    final stream = db.watchCompletedCount(skillId: 'qnp', level: 1);
    final values = <int>[];
    final sub = stream.listen(values.add);

    await Future.delayed(Duration.zero);
    await db.recordCompleted(skillId: 'qnp', level: 1, bpm: 70);
    await Future.delayed(Duration.zero);
    await db.recordCompleted(skillId: 'qnp', level: 1, bpm: 70);
    await Future.delayed(Duration.zero);

    await sub.cancel();
    expect(values, [0, 1, 2]);
  });

  group('premium flag (2026-07-27, dev-only local toggle)', () {
    test('defaults to false with no row yet', () async {
      expect(await db.isPremium(), isFalse);
    });

    test('setPremium persists and flips both the future read and the stream',
        () async {
      final stream = db.watchPremium();
      final values = <bool>[];
      final sub = stream.listen(values.add);
      await Future.delayed(Duration.zero);

      await db.setPremium(true);
      await Future.delayed(Duration.zero);
      expect(await db.isPremium(), isTrue);

      await db.setPremium(false);
      await Future.delayed(Duration.zero);
      expect(await db.isPremium(), isFalse);

      await sub.cancel();
      expect(values, [false, true, false]);
    });
  });

  group('daily unlocks (2026-07-27, free-tier 3-sessions-a-day cap)', () {
    test('nothing is unlocked and the count is zero on a fresh day',
        () async {
      expect(
        await db.isUnlockedToday(skillId: 'quarter_note_pulse', level: 1),
        isFalse,
      );
      expect(await db.todayUnlockCount(), 0);
      expect(await db.watchTodayUnlocks().first, isEmpty);
    });

    test('recordUnlock makes that (skill, level) count as unlocked today',
        () async {
      await db.recordUnlock(skillId: 'quarter_note_pulse', level: 1);

      expect(
        await db.isUnlockedToday(skillId: 'quarter_note_pulse', level: 1),
        isTrue,
      );
      expect(
        await db.isUnlockedToday(skillId: 'quarter_note_pulse', level: 2),
        isFalse,
        reason: 'a different level of the same skill is a different unlock',
      );
      expect(await db.todayUnlockCount(), 1);
    });

    test('todayUnlockCount reaches the free daily cap after three unlocks',
        () async {
      await db.recordUnlock(skillId: 'quarter_note_pulse', level: 1);
      await db.recordUnlock(skillId: 'quarter_note_rests', level: 1);
      await db.recordUnlock(skillId: 'eighth_notes', level: 2);

      expect(await db.todayUnlockCount(), 3);
    });

    test('watchTodayUnlocks lists every unlock made today', () async {
      await db.recordUnlock(skillId: 'quarter_note_pulse', level: 1);
      await db.recordUnlock(skillId: 'eighth_notes', level: 3);

      final unlocks = await db.watchTodayUnlocks().first;
      expect(unlocks, hasLength(2));
      expect(
        unlocks.map((u) => (u.skillId, u.level)).toSet(),
        {('quarter_note_pulse', 1), ('eighth_notes', 3)},
      );
    });
  });

  group('ad bonus slots (2026-07-30, rewarded-ad daily bonus slot)', () {
    test('starts at zero on a fresh day', () async {
      expect(await db.todayBonusSlots(), 0);
      expect(await db.watchTodayBonusSlots().first, 0);
    });

    test('addBonusSlot increments the count and the stream', () async {
      final stream = db.watchTodayBonusSlots();
      final values = <int>[];
      final sub = stream.listen(values.add);
      await Future.delayed(Duration.zero);

      await db.addBonusSlot();
      await Future.delayed(Duration.zero);
      expect(await db.todayBonusSlots(), 1);

      await db.addBonusSlot();
      await Future.delayed(Duration.zero);
      expect(await db.todayBonusSlots(), 2);

      await sub.cancel();
      expect(values, [0, 1, 2]);
    });
  });

  group('recent practiced (2026-07-27, Premium\'s Today\'s Session list)',
      () {
    test('empty with no completed sessions', () async {
      expect(await db.watchRecentPracticed().first, isEmpty);
    });

    test('most recently completed (skillId, level) comes first', () async {
      await db.recordCompleted(
        skillId: 'quarter_note_pulse',
        level: 1,
        bpm: 80,
        completedAt: DateTime(2026, 1, 1),
      );
      await db.recordCompleted(
        skillId: 'eighth_notes',
        level: 2,
        bpm: 90,
        completedAt: DateTime(2026, 1, 3),
      );
      await db.recordCompleted(
        skillId: 'sixteenth_notes',
        level: 1,
        bpm: 70,
        completedAt: DateTime(2026, 1, 2),
      );

      final recent = await db.watchRecentPracticed().first;
      expect(recent, [
        ('eighth_notes', 2),
        ('sixteenth_notes', 1),
        ('quarter_note_pulse', 1),
      ]);
    });

    test('each (skillId, level) appears once, ranked by its latest '
        'completion', () async {
      await db.recordCompleted(
        skillId: 'quarter_note_pulse',
        level: 1,
        bpm: 80,
        completedAt: DateTime(2026, 1, 1),
      );
      await db.recordCompleted(
        skillId: 'quarter_note_pulse',
        level: 1,
        bpm: 80,
        completedAt: DateTime(2026, 1, 5),
      );

      final recent = await db.watchRecentPracticed().first;
      expect(recent, [('quarter_note_pulse', 1)]);
    });

    test('respects the limit', () async {
      for (var i = 1; i <= 5; i++) {
        await db.recordCompleted(
          skillId: 'skill_$i',
          level: 1,
          bpm: 80,
          completedAt: DateTime(2026, 1, i),
        );
      }

      final recent = await db.watchRecentPracticed(limit: 3).first;
      expect(recent, hasLength(3));
      expect(recent, [('skill_5', 1), ('skill_4', 1), ('skill_3', 1)]);
    });
  });
}
