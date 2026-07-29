/// Free-tier gating rules (2026-07-27): everything beyond the first three
/// skills, plus recording/analysis (already gated separately in the M3/M4
/// UI), is Premium. Free users still get the whole curriculum's *first*
/// stretch, a capped number of sessions per day, and every lesson opens at
/// one common, easy-to-settle-into tempo rather than each skill's own
/// (often faster) designed default.
const freeSkillIds = {
  'quarter_note_pulse',
  'quarter_note_rests',
  'eighth_notes',
};

const freeDailySessionCap = 3;

const freeBpm = 60;

bool isSkillFree(String skillId) => freeSkillIds.contains(skillId);

/// What tapping into (skillId, level) should do for the current user —
/// pulled out of the Home screen's `_startPractice` as a pure function
/// (2026-07-27) so the exact cap-boundary behavior (does the 3rd unlock
/// still go through? does re-opening something already unlocked today
/// dodge the cap?) can be unit-tested directly, without a widget harness.
enum GateDecision { allow, upsellLocked, upsellCapReached }

GateDecision decideGate({
  required bool premium,
  required String skillId,
  required bool alreadyUnlockedToday,
  required int todayUnlockCount,
}) {
  if (premium) return GateDecision.allow;
  if (!isSkillFree(skillId)) return GateDecision.upsellLocked;
  if (!alreadyUnlockedToday && todayUnlockCount >= freeDailySessionCap) {
    return GateDecision.upsellCapReached;
  }
  return GateDecision.allow;
}
