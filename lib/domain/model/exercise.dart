import 'note_token.dart';
import 'sticking.dart';
import 'time_signature.dart';

/// A hand-authored (or transform-derived) one-measure pattern that exercises
/// are instantiated from. Lives in content JSON.
class ExerciseTemplate {
  final String id;
  final List<NoteToken> rhythm;

  /// One entry per *note* in [rhythm] (rests carry no sticking).
  final List<Hand> sticking;
  final int difficulty;

  ExerciseTemplate({
    required this.id,
    required this.rhythm,
    required this.sticking,
    required this.difficulty,
  }) {
    final noteCount = rhythm.where((t) => !t.isRest).length;
    if (sticking.length != noteCount) {
      throw ArgumentError(
          'Template $id: sticking length ${sticking.length} != note count $noteCount');
    }
  }

  /// Total length must fill the measure exactly.
  void validateAgainst(TimeSignature ts) {
    final total = rhythm.fold<double>(
        0, (sum, t) => sum + t.lengthInBeats(ts.beatUnit));
    if ((total - ts.beats).abs() > 1e-9) {
      throw ArgumentError(
          'Template $id: measure length $total beats, expected ${ts.beats} ($ts)');
    }
  }
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

  const Exercise({
    required this.templateId,
    required this.rhythm,
    required this.sticking,
    required this.index,
  });

  Exercise copyWith({int? index}) => Exercise(
        templateId: templateId,
        rhythm: rhythm,
        sticking: sticking,
        index: index ?? this.index,
      );

  static Exercise fromTemplate(ExerciseTemplate t, int index) => Exercise(
        templateId: t.id,
        rhythm: List.unmodifiable(t.rhythm),
        sticking: List.unmodifiable(t.sticking),
        index: index,
      );
}
