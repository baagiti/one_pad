import 'note_token.dart';
import 'sticking.dart';
import 'time_signature.dart';

/// A hand-authored (or transform-derived) pattern that exercises are
/// instantiated from. Lives in content JSON. Usually exactly one measure,
/// but a template MAY span multiple whole measures (e.g. a rudiment like
/// the Triple Paradiddle at eighth-note speed needs 2 measures — see design
/// doc §23) — [measureCountFor] reports how many.
class ExerciseTemplate {
  final String id;
  final List<NoteToken> rhythm;

  /// One entry per STRUCK note in [rhythm] — rests carry no sticking, and
  /// neither does a tied-continuation token (design doc §24: it has no new
  /// attack, so nothing to assign a hand to).
  final List<Hand> sticking;
  final int difficulty;

  /// Optional counting-syllable label per token in [rhythm] — ONE ENTRY PER
  /// TOKEN (unlike [sticking], this includes rests: a "How to Count" intro
  /// level needs to show what to silently count through a rest too). Null
  /// for every ordinary level; only set on the dedicated "How to Count"
  /// Level 0 a handful of skills carry (design doc, "Sayma (Counting) Giriş
  /// Dersleri" section, 2026-07-27) — when present, the notation view shows
  /// this text instead of the sticking letter.
  final List<String>? countingLabels;

  ExerciseTemplate({
    required this.id,
    required this.rhythm,
    required this.sticking,
    required this.difficulty,
    this.countingLabels,
  }) {
    final noteCount = rhythm.where((t) => t.isStruck).length;
    if (sticking.length != noteCount) {
      throw ArgumentError(
          'Template $id: sticking length ${sticking.length} != note count $noteCount');
    }
    if (countingLabels != null && countingLabels!.length != rhythm.length) {
      throw ArgumentError(
          'Template $id: countingLabels length ${countingLabels!.length} '
          '!= token count ${rhythm.length}');
    }
  }

  double _totalBeats(TimeSignature ts) => rhythm.fold<double>(
      0, (sum, t) => sum + t.lengthInBeats(ts.beatUnit));

  /// Total length must fill a WHOLE number of measures — 1 in the common
  /// case, but 2+ is valid (design doc §23).
  void validateAgainst(TimeSignature ts) {
    final total = _totalBeats(ts);
    final measures = total / ts.beats;
    if ((measures - measures.round()).abs() > 1e-9 || measures.round() < 1) {
      throw ArgumentError(
          'Template $id: length $total beats is not a whole number of '
          '$ts measures');
    }
  }

  /// How many measures this template occupies. Only meaningful after
  /// [validateAgainst] has passed (content loading always validates first).
  int measureCountFor(TimeSignature ts) => (_totalBeats(ts) / ts.beats).round();
}

/// The smallest practice unit (spec §11): one resolved measure inside a
/// session. Rhythm and sticking are SNAPSHOTS of the template at generation
/// time so that Review Pool replays are bit-exact even if content is later
/// edited (spec §9).
class Exercise {
  final String templateId;
  final List<NoteToken> rhythm;
  final List<Hand> sticking;

  /// Position within the session, 0-based.
  final int index;

  /// How many measures this exercise occupies — always the same for every
  /// exercise in a session (one level's template pool is always uniform in
  /// length, design doc §23), but stored per-exercise since it's a snapshot
  /// of the template like [rhythm]/[sticking].
  final int measureCount;

  /// See [ExerciseTemplate.countingLabels] — a per-token counting-syllable
  /// snapshot, only set for "How to Count" intro levels.
  final List<String>? countingLabels;

  const Exercise({
    required this.templateId,
    required this.rhythm,
    required this.sticking,
    required this.index,
    this.measureCount = 1,
    this.countingLabels,
  });

  Exercise copyWith({int? index}) => Exercise(
        templateId: templateId,
        rhythm: rhythm,
        sticking: sticking,
        index: index ?? this.index,
        measureCount: measureCount,
        countingLabels: countingLabels,
      );

  static Exercise fromTemplate(
          ExerciseTemplate t, int index, TimeSignature ts) =>
      Exercise(
        templateId: t.id,
        rhythm: List.unmodifiable(t.rhythm),
        sticking: List.unmodifiable(t.sticking),
        index: index,
        measureCount: t.measureCountFor(ts),
        countingLabels:
            t.countingLabels == null ? null : List.unmodifiable(t.countingLabels!),
      );
}
