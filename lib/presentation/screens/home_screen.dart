import 'package:flutter/material.dart';

import '../../application/session_flow/practice_flow_controller.dart';
import '../../domain/model/skill.dart';
import '../../domain/progress/access_policy.dart';
import '../../domain/progress/progress_policy.dart';
import '../../infrastructure/ads/ads_service.dart';
import '../../infrastructure/iap/purchase_service.dart';
import '../../infrastructure/storage/app_database.dart';
import '../theme/app_theme.dart';
import '../widgets/ad_banner.dart';
import '../widgets/drum_head_background.dart';
import 'premium_screen.dart';
import 'session_preview_screen.dart';
import 'today_session_screen.dart';

/// One entry of the full curriculum roadmap (design doc §15). The whole
/// 20-skill roadmap has content now, so every entry has a real [skill]
/// (there used to be a locked "coming soon" placeholder state for skills
/// without content yet; removed 2026-07-27 once the last gap was filled).
class _RoadmapEntry {
  final String title;
  final Skill skill;
  const _RoadmapEntry(this.title, this.skill);
}

/// Home (spec §3 + design doc §14–15): tagline header, Today's Session
/// card, and the full curriculum roadmap as a lessons list grouped by
/// skill, showing each level's live progress from [AppDatabase].
///
/// "Skills" and "Performance" (spec §3) are folded into this dashboard:
/// selecting a lesson row IS the skill/level picker. Performance Areas
/// have no content yet, so they appear as the roadmap's locked final entry
/// rather than a separate button that would lead nowhere.
///
/// Free-tier gating (2026-07-27, [access_policy.dart]): non-premium users
/// get [freeSkillIds] plus [freeDailySessionCap] session-starts per day
/// (tracked in [AppDatabase.watchTodayUnlocks], resets automatically at
/// midnight since that query is scoped to today's date key) at a single
/// common [freeBpm] rather than each level's own default. Everything else
/// shows a Premium lock. There's no real purchase flow yet (design doc
/// §12), so "Go Premium" is a dev-only local toggle for now.
class HomeScreen extends StatefulWidget {
  final PracticeFlowController controller;
  final List<Skill> skills;
  final AppDatabase db;
  final PurchaseService purchases;
  final AdsService ads;

  const HomeScreen({
    super.key,
    required this.controller,
    required this.skills,
    required this.db,
    required this.purchases,
    required this.ads,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _roadmapTitles = [
    'Quarter-Note Pulse',
    'Quarter Note Rests',
    'Eighth Notes',
    'Eighth Notes + Rests',
    'Dotted Quarter + Eighth',
    'Rudiments (Eighth Notes)',
    'Sixteenth Notes',
    'Rudiments (Sixteenth Notes)',
    '32nd Notes',
    'Syncopation / Ties',
    'Alternate Meters: 3/4',
    'Alternate Meters: 6/8',
    'Odd Meters: 5/4',
    'Odd Meters: 7/8',
    'Triplets',
    'Rudiments: Roll Family',
    'Performance: Foundations',
    'Performance: Syncopated Feel',
    'Performance: Fast Subdivision',
    'Performance: Rudiment Workout',
  ];

  late Skill _selectedSkill;
  late int _selectedLevel;

  @override
  void initState() {
    super.initState();
    _selectedSkill = widget.skills.first;
    _selectedLevel = 1;
  }

  List<_RoadmapEntry> get _roadmap {
    final byId = {for (final s in widget.skills) s.id: s};
    const idsInOrder = [
      'quarter_note_pulse',
      'quarter_note_rests',
      'eighth_notes',
      'offbeat_eighth_notes',
      'dotted_quarter_eighth',
      'paradiddle_eighth_notes',
      'sixteenth_notes',
      'paradiddle_sixteenth_notes',
      'thirty_second_notes',
      'syncopation_ties',
      'alternate_meters_34',
      'alternate_meters_68',
      'odd_meters_54',
      'odd_meters_78',
      'triplets',
      'roll_rudiments',
      'performance_foundations',
      'performance_syncopated_feel',
      'performance_fast_subdivision',
      'performance_rudiment_workout',
    ];
    return [
      for (var i = 0; i < _roadmapTitles.length; i++)
        _RoadmapEntry(_roadmapTitles[i], byId[idsInOrder[i]]!),
    ];
  }

  /// Starts a session for (skill, levelNumber) — used both by the Today's
  /// Session card and by tapping a lesson row. Free-tier gating happens
  /// here, once, so every entry point is covered: a locked skill or an
  /// exhausted daily cap shows the upsell dialog instead of navigating;
  /// re-opening something already unlocked today never costs another slot;
  /// a free user's session always starts at [freeBpm] regardless of the
  /// skill's own default (still adjustable live via the existing BPM
  /// controls on the next screen).
  Future<void> _startPractice(Skill skill, int levelNumber) async {
    final premium = await widget.db.isPremium();
    final alreadyUnlocked = premium
        ? false
        : await widget.db
            .isUnlockedToday(skillId: skill.id, level: levelNumber);
    final todayCount = premium ? 0 : await widget.db.todayUnlockCount();
    final bonusSlots = premium ? 0 : await widget.db.todayBonusSlots();

    final decision = decideGate(
      premium: premium,
      skillId: skill.id,
      alreadyUnlockedToday: alreadyUnlocked,
      todayUnlockCount: todayCount,
      bonusSlotsToday: bonusSlots,
    );

    switch (decision) {
      case GateDecision.upsellLocked:
        if (mounted) _showPremiumUpsell('This lesson is part of Premium.');
        return;
      case GateDecision.upsellCapReached:
        if (mounted) {
          final effectiveCap = freeDailySessionCap +
              bonusSlots.clamp(0, freeBonusSlotCap);
          // Only dangle the ad option if today's one bonus slot (design
          // doc, 2026-07-30) hasn't already been spent — otherwise this
          // dialog would offer a video that isn't actually available until
          // tomorrow.
          final adHint = bonusSlots < freeBonusSlotCap
              ? "Watch a video on the Today's Session screen for one more, "
                  'come back tomorrow, or go Premium for unlimited practice.'
              : 'Come back tomorrow, or go Premium for unlimited practice.';
          _showPremiumUpsell(
            "You've used today's $effectiveCap free lessons. $adHint",
          );
        }
        return;
      case GateDecision.allow:
        break;
    }

    var bpm = skill.bpmDefault;
    if (!premium) {
      if (!alreadyUnlocked) {
        await widget.db.recordUnlock(skillId: skill.id, level: levelNumber);
      }
      bpm = freeBpm;
    }

    setState(() {
      _selectedSkill = skill;
      _selectedLevel = levelNumber;
    });
    widget.controller.generateSession(
      skill: skill,
      level: levelNumber,
      bpm: bpm,
    );
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SessionPreviewScreen(
          controller: widget.controller,
          db: widget.db,
          ads: widget.ads,
          levelNote: skill.level(levelNumber).note,
        ),
      ),
    );
  }

  Future<void> _showPremiumUpsell(String message) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Go Premium'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Maybe later'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              _openPremiumScreen();
            },
            child: const Text('Go Premium'),
          ),
        ],
      ),
    );
  }

  Future<void> _openPremiumScreen() {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PremiumScreen(db: widget.db, purchases: widget.purchases),
      ),
    );
  }

  Future<void> _openTodaySessionScreen() {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TodaySessionScreen(
          controller: widget.controller,
          db: widget.db,
          skills: widget.skills,
          ads: widget.ads,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: widget.db.watchPremium(),
      builder: (context, premiumSnap) {
        final premium = premiumSnap.data ?? false;
        return Scaffold(
          body: Stack(
            children: [
              const Positioned.fill(child: DrumHeadBackground()),
              SafeArea(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  children: [
                    _buildHeader(context),
                    const SizedBox(height: 20),
                    _buildTodaySessionCard(context, premium),
                    const SizedBox(height: 28),
                    Text('Lessons',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    for (var i = 0; i < _roadmap.length; i++)
                      _buildRoadmapEntry(context, i + 1, _roadmap[i], premium),
                    const SizedBox(height: 12),
                    _buildPremiumCard(context, premium),
                    if (!premium) ...[
                      const SizedBox(height: 20),
                      Center(child: AdBanner(ads: widget.ads)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Let's make some rhythms.",
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                'Practice. Listen. Improve.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: _openPremiumScreen,
          icon: const Icon(
            Icons.workspace_premium_outlined,
            color: AppColors.secondary,
          ),
        ),
      ],
    );
  }

  /// Always opens [TodaySessionScreen] rather than starting anything
  /// directly (2026-07-27) — Home's card stays a single, static entry
  /// point; the stacked slot list (today's capped picks for free, most
  /// recently practiced for Premium) lives on its own page now, not
  /// inline here.
  Widget _buildTodaySessionCard(BuildContext context, bool premium) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _openTodaySessionScreen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _iconBadge(Icons.close_fullscreen, size: 44), // placeholder mark
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Today's Session",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      premium
                          ? 'See your recent lessons'
                          : "See today's picks",
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
    );
  }

  Widget _buildRoadmapEntry(
    BuildContext context,
    int number,
    _RoadmapEntry entry,
    bool premium,
  ) {
    final premiumLocked = !premium && !isSkillFree(entry.skill.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6, left: 2),
            child: Row(
              children: [
                Text(
                  '$number. ${entry.title}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (premiumLocked) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.workspace_premium_outlined,
                      size: 15, color: AppColors.secondary),
                ],
              ],
            ),
          ),
          for (final level in entry.skill.levels)
            _buildLessonRow(context, entry.skill, level, premiumLocked),
        ],
      ),
    );
  }

  Widget _buildLessonRow(
    BuildContext context,
    Skill skill,
    Level level,
    bool premiumLocked,
  ) {
    final selected =
        skill.id == _selectedSkill.id && level.level == _selectedLevel;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _startPractice(skill, level.level),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.outline,
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Row(
              children: [
                _iconBadge(Icons.tag, label: '${level.level}'),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        level.name,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${skill.timeSignature}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (premiumLocked)
                  const Icon(Icons.lock_outline,
                      color: AppColors.secondary, size: 18)
                else
                  _buildProgress(skill, level),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static const _tierColors = {
    ProgressTier.practicing: AppColors.tierBronze,
    ProgressTier.solid: AppColors.tierSilver,
    ProgressTier.mastered: AppColors.tierGold,
    ProgressTier.virtuoso: AppColors.tierPlatinum,
    ProgressTier.legend: AppColors.tierDiamond,
  };

  /// Repetition-tier badge, not a completion percentage (2026-07-27) — the
  /// app never measured accuracy outside a recorded take, so a bare "%"
  /// implied a precision that wasn't real. Tiers are an honest "how many
  /// times you've practiced this" signal instead.
  Widget _buildProgress(Skill skill, Level level) {
    return StreamBuilder<int>(
      stream: widget.db.watchCompletedCount(
        skillId: skill.id,
        level: level.level,
      ),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        final tier = tierFor(count);
        if (tier == ProgressTier.none) {
          return Text(
            '$count reps',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          );
        }
        final color = _tierColors[tier]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                tier.label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$count reps',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPremiumCard(BuildContext context, bool premium) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _openPremiumScreen,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.textPrimary,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(
                premium ? Icons.workspace_premium : Icons.lock_outline,
                color: AppColors.secondary,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      premium ? 'Premium active' : 'Go Premium',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.surface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      premium
                          ? 'Unlimited lessons, every skill, record and analyze.'
                          : 'Unlock every skill, unlimited sessions, record '
                              'and analyze.',
                      style: TextStyle(
                        color: AppColors.surface.withValues(alpha: 0.75),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: AppColors.surface.withValues(alpha: 0.75),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconBadge(IconData icon, {double size = 40, String? label}) {
    return Container(
      width: size,
      height: size,
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
          : Icon(icon, color: AppColors.primary, size: size * 0.5),
    );
  }
}
