import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

/// One row per completed practice session (spec §4: a session is "complete"
/// once all 16 exercises have played through). Used to derive the Home
/// screen's per-level progress percentage (design doc §14) and, later, as
/// the basis for Review Pool queries.
class PracticeSessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get skillId => text()();
  IntColumn get level => integer()();
  IntColumn get bpm => integer()();
  DateTimeColumn get completedAt => dateTime()();
}

/// One row per (date, skill, level) a free-tier user has unlocked today
/// (spec: 3 free sessions/day, 2026-07-27). Re-opening an already-unlocked
/// entry doesn't cost another slot — that's the whole point of the Home
/// screen's "Today's Lessons" bucket — so this table is checked before
/// counting toward the daily cap, not just for the cap itself.
class DailyUnlocks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get dateKey => text()(); // local 'YYYY-MM-DD', not a DateTime —
  // sidesteps timezone/time-of-day comparison entirely for a "which
  // calendar day" question.
  TextColumn get skillId => text()();
  IntColumn get level => integer()();
}

/// Single-row table: whether the (local, non-StoreKit) premium flag is on.
/// Real purchase/subscription handling (StoreKit/RevenueCat) is still an
/// open topic (design doc §12) — this table is the seam it'll write to once
/// built; for now it's flipped by a dev-only toggle (design doc §14).
class PremiumSettings extends Table {
  IntColumn get id => integer().autoIncrement()();
  BoolColumn get isPremium => boolean().withDefault(const Constant(false))();
}

@DriftDatabase(tables: [PracticeSessions, DailyUnlocks, PremiumSettings])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // v2 added a CalibrationSettings table (device mic latency); v3
          // removed it (2026-07-27) — M4 scoring turned out to need each
          // take's own auto-detected alignment (domain/analysis/
          // latency_search.dart) rather than one upfront device number, so
          // the table became dead weight. Drop it if a v2 install has it.
          if (from >= 2 && from < 3) {
            await m.deleteTable('calibration_settings');
          }
          // v4 added the free-tier gating tables (2026-07-27).
          if (from < 4) {
            await m.createTable(dailyUnlocks);
            await m.createTable(premiumSettings);
          }
        },
      );

  String _todayKey([DateTime? now]) {
    final n = now ?? DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}-'
        '${n.month.toString().padLeft(2, '0')}-'
        '${n.day.toString().padLeft(2, '0')}';
  }

  Future<bool> isPremium() async {
    final row = await select(premiumSettings).getSingleOrNull();
    return row?.isPremium ?? false;
  }

  /// Live premium flag — the Home screen reacts immediately when the dev
  /// toggle (or, later, a real purchase) flips it, no manual refresh.
  Stream<bool> watchPremium() => select(premiumSettings)
      .watchSingleOrNull()
      .map((row) => row?.isPremium ?? false);

  Future<void> setPremium(bool value) async {
    final existing = await select(premiumSettings).getSingleOrNull();
    if (existing == null) {
      await into(premiumSettings)
          .insert(PremiumSettingsCompanion.insert(isPremium: Value(value)));
    } else {
      await (update(premiumSettings)..where((t) => t.id.equals(existing.id)))
          .write(PremiumSettingsCompanion(isPremium: Value(value)));
    }
  }

  Future<bool> isUnlockedToday(
      {required String skillId, required int level}) async {
    final query = select(dailyUnlocks)
      ..where((t) =>
          t.dateKey.equals(_todayKey()) &
          t.skillId.equals(skillId) &
          t.level.equals(level));
    return (await query.getSingleOrNull()) != null;
  }

  Future<int> todayUnlockCount() async {
    final query = selectOnly(dailyUnlocks)
      ..addColumns([dailyUnlocks.id.count()])
      ..where(dailyUnlocks.dateKey.equals(_todayKey()));
    final row = await query.getSingle();
    return row.read(dailyUnlocks.id.count()) ?? 0;
  }

  Future<void> recordUnlock({required String skillId, required int level}) {
    return into(dailyUnlocks).insert(DailyUnlocksCompanion.insert(
      dateKey: _todayKey(),
      skillId: skillId,
      level: level,
    ));
  }

  /// Today's unlocked (skillId, level) pairs — backs the Home screen's
  /// "Today's Lessons" bucket, which empties itself simply by virtue of
  /// this query being scoped to today's date key.
  Stream<List<DailyUnlock>> watchTodayUnlocks() {
    final query = select(dailyUnlocks)
      ..where((t) => t.dateKey.equals(_todayKey()));
    return query.watch();
  }

  Future<int> recordCompleted({
    required String skillId,
    required int level,
    required int bpm,
    DateTime? completedAt,
  }) {
    return into(practiceSessions).insert(PracticeSessionsCompanion.insert(
      skillId: skillId,
      level: level,
      bpm: bpm,
      completedAt: completedAt ?? DateTime.now(),
    ));
  }

  Selectable<int> _completedCountQuery(
      {required String skillId, required int level}) {
    final query = selectOnly(practiceSessions)
      ..addColumns([practiceSessions.id.count()])
      ..where(practiceSessions.skillId.equals(skillId) &
          practiceSessions.level.equals(level));
    return query.map((row) => row.read(practiceSessions.id.count()) ?? 0);
  }

  /// Live count of completed sessions for one skill level — drives the
  /// Home screen's progress percentage without a manual refresh.
  Stream<int> watchCompletedCount({required String skillId, required int level}) =>
      _completedCountQuery(skillId: skillId, level: level).watchSingle();

  /// One-off read, used to resolve a level's curriculum BPM (design doc)
  /// before generating the next session — a stream would be overkill for a
  /// value read exactly once at "Start" time.
  Future<int> completedCount({required String skillId, required int level}) =>
      _completedCountQuery(skillId: skillId, level: level).getSingle();

  /// The Premium Today's Session screen's list (2026-07-27): unlike free
  /// tier's day-scoped, capped [watchTodayUnlocks], Premium has no daily
  /// cap to display against — "recent lessons" instead means the most
  /// recently *completed* (skillId, level) pairs, full stop, regardless of
  /// which day, since [DailyUnlocks] rows are only ever written for
  /// free-tier gating.
  Stream<List<(String skillId, int level)>> watchRecentPracticed(
      {int limit = 3}) {
    final maxCompleted = practiceSessions.completedAt.max();
    final query = selectOnly(practiceSessions)
      ..addColumns([practiceSessions.skillId, practiceSessions.level, maxCompleted])
      ..groupBy([practiceSessions.skillId, practiceSessions.level])
      ..orderBy([OrderingTerm.desc(maxCompleted)])
      ..limit(limit);
    return query.watch().map((rows) => [
          for (final row in rows)
            (
              row.read(practiceSessions.skillId)!,
              row.read(practiceSessions.level)!,
            ),
        ]);
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'one_pad.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
