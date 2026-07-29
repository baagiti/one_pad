/// Repetition-count tiers (2026-07-27, replacing the old "completed/5 as a
/// %" placeholder — a raw percentage implied a precision the app never
/// actually measured). A tier is an honest signal of "how many times you've
/// practiced this", not of accuracy — accuracy only exists for recorded
/// (Premium) takes and is shown separately as the real M4 score.
enum ProgressTier { none, practicing, solid, mastered, virtuoso, legend }

const _tierThresholds = {
  ProgressTier.legend: 51,
  ProgressTier.virtuoso: 31,
  ProgressTier.mastered: 16,
  ProgressTier.solid: 6,
  ProgressTier.practicing: 1,
};

ProgressTier tierFor(int completedSessions) {
  for (final entry in _tierThresholds.entries) {
    if (completedSessions >= entry.value) return entry.key;
  }
  return ProgressTier.none;
}

extension ProgressTierLabel on ProgressTier {
  String get label => switch (this) {
        ProgressTier.none => '',
        ProgressTier.practicing => 'Practicing',
        ProgressTier.solid => 'Solid',
        ProgressTier.mastered => 'Mastered',
        ProgressTier.virtuoso => 'Virtuoso',
        ProgressTier.legend => 'Legend',
      };
}
