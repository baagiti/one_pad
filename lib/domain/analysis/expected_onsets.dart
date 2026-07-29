import '../model/exercise.dart';
import '../timeline/timeline_map.dart';

/// Sample offsets of every struck ([NoteToken.isStruck]) note in [exercise],
/// on the same [map] used to render the session's reference-hit audio
/// (infrastructure/audio/session_audio_renderer.dart) — the single source of
/// "when was this note supposed to happen," shared by the renderer (to place
/// an audible reference hit) and M4's [TimingScorer] (to grade a recording
/// against it). Rests and tied notes contribute no onset (design doc §24).
List<int> expectedOnsetSamples(TimelineMap map, Exercise exercise) {
  final baseMeasure = map.baseMeasureOfExercise(exercise.index);
  final offsets = <int>[];
  var beatPos = 0.0;
  for (final token in exercise.rhythm) {
    if (token.isStruck) {
      offsets.add((map.samplesPerMeasure * baseMeasure +
              map.samplesPerBeat * beatPos)
          .round());
    }
    beatPos += token.lengthInBeats(map.timeSignature.beatUnit);
  }
  return offsets;
}
