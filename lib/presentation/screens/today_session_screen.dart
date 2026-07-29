import 'package:flutter/material.dart';

import '../../application/session_flow/practice_flow_controller.dart';
import '../../domain/model/skill.dart';
import '../../domain/progress/access_policy.dart';
import '../../infrastructure/storage/app_database.dart';
import '../theme/app_theme.dart';
import 'session_preview_screen.dart';

/// What "Today's Session" on Home now opens into (2026-07-27) — moved off
/// Home so the home screen itself never grows a variable-length list
/// (design feedback: Home's card should stay a single, static entry
/// point). Both tiers see up to [freeDailySessionCap] stacked slots here,
/// but from different sources: free tier shows the day's actual capped
/// unlocks (empties itself at midnight, since that query is scoped to
/// today's date key); Premium has no cap to display against, so it shows
/// its most recently *completed* lessons instead — persists across days,
/// since [PracticeSessions] isn't day-scoped the way [DailyUnlocks] is.
class TodaySessionScreen extends StatelessWidget {
  final PracticeFlowController controller;
  final AppDatabase db;
  final List<Skill> skills;

  const TodaySessionScreen({
    super.key,
    required this.controller,
    required this.db,
    required this.skills,
  });

  Future<void> _open(BuildContext context, Skill skill, int level, int bpm) async {
    controller.generateSession(skill: skill, level: level, bpm: bpm);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SessionPreviewScreen(
          controller: controller,
          db: db,
          levelNote: skill.level(level).note,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Today's Session")),
      body: StreamBuilder<bool>(
        stream: db.watchPremium(),
        builder: (context, premiumSnap) {
          final premium = premiumSnap.data ?? false;
          return premium ? _buildPremium(context) : _buildFree(context);
        },
      ),
    );
  }

  Widget _buildFree(BuildContext context) {
    return StreamBuilder<List<DailyUnlock>>(
      stream: db.watchTodayUnlocks(),
      builder: (context, snapshot) {
        final unlocks = snapshot.data ?? const [];
        final byId = {for (final s in skills) s.id: s};
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Text(
              '${unlocks.length}/$freeDailySessionCap used today',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < freeDailySessionCap; i++)
              if (i < unlocks.length && byId[unlocks[i].skillId] != null)
                _buildSlot(
                  context,
                  skill: byId[unlocks[i].skillId]!,
                  level: unlocks[i].level,
                  bpm: freeBpm,
                )
              else
                _buildEmptySlot(context, "Free slot available"),
            const SizedBox(height: 8),
            Text(
              'Pick a lesson from the roadmap on Home to fill an empty '
              'slot.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPremium(BuildContext context) {
    return StreamBuilder<List<(String skillId, int level)>>(
      stream: db.watchRecentPracticed(limit: freeDailySessionCap),
      builder: (context, snapshot) {
        final recent = snapshot.data ?? const [];
        final byId = {for (final s in skills) s.id: s};
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Text(
              'Your most recently practiced lessons',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < freeDailySessionCap; i++)
              if (i < recent.length && byId[recent[i].$1] != null)
                _buildSlot(
                  context,
                  skill: byId[recent[i].$1]!,
                  level: recent[i].$2,
                  bpm: byId[recent[i].$1]!.bpmDefault,
                )
              else
                _buildEmptySlot(context, 'Not practiced yet'),
          ],
        );
      },
    );
  }

  Widget _buildSlot(
    BuildContext context, {
    required Skill skill,
    required int level,
    required int bpm,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _open(context, skill, level, bpm),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.outline),
            ),
            child: Row(
              children: [
                _iconBadge(Icons.replay, label: '$level'),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        skill.level(level).name,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        skill.name,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right,
                    color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptySlot(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.outline),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.outline),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.add,
                  color: AppColors.textSecondary, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconBadge(IconData icon, {String? label}) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: label != null
          ? Text(
              label,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            )
          : Icon(icon, color: AppColors.primary, size: 20),
    );
  }
}
