import 'dart:typed_data';

import '../../domain/model/exercise.dart';
import '../../domain/timeline/timeline_map.dart';
import 'click_sounds.dart';

/// Renders a session's complete audio timeline into one mono 16-bit PCM
/// buffer ("render, don't schedule" — design doc §3):
///
///   [count-in][exercise 0]...[exercise 15][decay tail]
///
/// Because every click and reference hit is mixed at a sample offset computed
/// from the same TimelineMap that drives the playhead and (later) analysis,
/// everything is synchronous by construction.
class SessionAudioRenderer {
  final ClickSounds sounds;

  SessionAudioRenderer({required this.sounds});

  /// Extra samples after the last measure so the final click's decay is not
  /// cut off.
  static const _tailMs = 250;

  Int16List render({
    required TimelineMap map,
    required List<Exercise> exercises,
    bool includeReferenceHits = false,
  }) {
    assert(map.sampleRate == sounds.sampleRate,
        'TimelineMap and ClickSounds must agree on sample rate');

    final tail = map.sampleRate * _tailMs ~/ 1000;
    final acc = Int32List(map.totalSamples + tail);

    for (final c in map.clickEvents()) {
      final sample = c.isCountIn
          ? sounds.countIn
          : (c.isMeasureStart ? sounds.accent : sounds.click);
      _mix(acc, sample, c.sampleOffset);
    }

    if (includeReferenceHits) {
      for (final e in exercises) {
        var beatPos = 0.0;
        for (final token in e.rhythm) {
          if (!token.isRest) {
            final offset = (map.samplesPerMeasure * (e.index + 1) +
                    map.samplesPerBeat * beatPos)
                .round();
            _mix(acc, sounds.padHit, offset);
          }
          beatPos += token.lengthInBeats(map.timeSignature.beatUnit);
        }
      }
    }

    final out = Int16List(acc.length);
    for (var i = 0; i < acc.length; i++) {
      out[i] = acc[i].clamp(-32768, 32767);
    }
    return out;
  }

  void _mix(Int32List acc, Int16List sample, int offset) {
    final end = (offset + sample.length).clamp(0, acc.length);
    for (var i = offset; i < end; i++) {
      acc[i] += sample[i - offset];
    }
  }
}
