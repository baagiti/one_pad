import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_pad/domain/model/exercise.dart';
import 'package:one_pad/domain/model/note_token.dart';
import 'package:one_pad/domain/model/sticking.dart';
import 'package:one_pad/domain/model/time_signature.dart';
import 'package:one_pad/domain/timeline/timeline_map.dart';
import 'package:one_pad/infrastructure/audio/click_sounds.dart';
import 'package:one_pad/infrastructure/audio/session_audio_renderer.dart';
import 'package:one_pad/infrastructure/audio/wav_codec.dart';

void main() {
  const sr = 44100;
  final sounds = ClickSounds(sampleRate: sr);
  final renderer = SessionAudioRenderer(sounds: sounds);

  // 60 BPM 4/4: beat = exactly 44100 samples.
  final map = TimelineMap(
    timeSignature: TimeSignature.fourFour,
    bpm: 60,
    sampleRate: sr,
  );

  List<Exercise> exercises() => [
        for (var i = 0; i < 16; i++)
          Exercise(
            templateId: 't$i',
            rhythm: [for (var b = 0; b < 4; b++) NoteToken.parse('q')],
            sticking: const [Hand.right, Hand.left, Hand.right, Hand.left],
            index: i,
          ),
      ];

  test('buffer covers the full timeline plus decay tail', () {
    final pcm = renderer.render(map: map, exercises: exercises());
    expect(pcm.length, greaterThan(map.totalSamples));
  });

  test('clicks land on beat offsets, silence between them', () {
    final pcm = renderer.render(map: map, exercises: exercises());
    // energy right at the first count-in click
    expect(pcm[10], isNot(0));
    // energy at exercise 0 beat 0 (after count-in)
    expect(pcm[map.countInSamples + 10], isNot(0));
    // silence half a beat after a click (clicks decay within ~40 ms)
    expect(pcm[map.countInSamples ~/ 2], 0);
  });

  test('reference hits audible only when enabled', () {
    final without =
        renderer.render(map: map, exercises: exercises());
    final with_ = renderer.render(
        map: map, exercises: exercises(), includeReferenceHits: true);

    // 45 ms after exercise-0 beat-0: clicks (30-40 ms) have fully decayed,
    // the 60 ms pad thud is still sounding.
    final probe = map.countInSamples + (0.045 * sr).round();
    expect(without[probe], 0);
    expect(with_[probe], isNot(0));

    // count-in region never contains reference hits (spec §6)
    final countInProbe = (0.045 * sr).round();
    expect(with_[countInProbe], without[countInProbe]);
  });

  test('rests produce no reference hit', () {
    final withRest = [
      Exercise(
        templateId: 'rest_test',
        rhythm: [
          NoteToken.parse('q'),
          NoteToken.parse('rq'),
          NoteToken.parse('q'),
          NoteToken.parse('rq'),
        ],
        sticking: const [Hand.right, Hand.left],
        index: 0,
      ),
      ...exercises().skip(1),
    ];
    final pcm = renderer.render(
        map: map, exercises: withRest, includeReferenceHits: true);
    // beat 1 of exercise 0 is a rest: 45 ms after it there is no pad tail
    final probe =
        map.sampleOfBeat(exercise: 0, beat: 1) + (0.045 * sr).round();
    expect(pcm[probe], 0);
  });

  test('tied notes produce no reference hit (design doc §24: a tie has no '
      'new attack)', () {
    final withTie = [
      Exercise(
        templateId: 'tie_test',
        rhythm: [
          NoteToken.parse('q'),
          NoteToken.parse('q~'),
          NoteToken.parse('q'),
          NoteToken.parse('q'),
        ],
        sticking: const [Hand.right, Hand.right, Hand.left],
        index: 0,
      ),
      ...exercises().skip(1),
    ];
    final pcm = renderer.render(
        map: map, exercises: withTie, includeReferenceHits: true);
    // beat 1 of exercise 0 is tied FROM beat 0 — no new attack there.
    final probe =
        map.sampleOfBeat(exercise: 0, beat: 1) + (0.045 * sr).round();
    expect(pcm[probe], 0);
  });

  test('WAV codec produces a valid header', () {
    final pcm = renderer.render(map: map, exercises: exercises());
    final wav = pcm16ToWav(pcm, sampleRate: sr);
    expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
    expect(wav.length, 44 + pcm.length * 2);
  });

  test('wavToPcm16 decodes exactly what pcm16ToWav encoded (M4 round-trip)',
      () {
    final pcm = renderer.render(map: map, exercises: exercises());
    final wav = pcm16ToWav(pcm, sampleRate: sr);
    final decoded = wavToPcm16(wav);

    expect(decoded.sampleRate, sr);
    expect(decoded.channels, 1);
    expect(decoded.samples, pcm);
  });

  test('wavToPcm16 skips an unrecognized chunk before fmt/data', () {
    final pcm = renderer.render(map: map, exercises: exercises());
    final wav = pcm16ToWav(pcm, sampleRate: sr);

    // Splice in a bogus 6-byte 'JUNK' chunk (with its odd-size pad byte)
    // right after the RIFF/WAVE header, mimicking chunks a native recorder
    // might add that this codec's own encoder never produces.
    final junk = <int>[
      ...('JUNK'.codeUnits),
      5, 0, 0, 0, // chunk size = 5 (odd -> one pad byte follows)
      1, 2, 3, 4, 5, 0,
    ];
    final spliced = <int>[
      ...wav.sublist(0, 12),
      ...junk,
      ...wav.sublist(12),
    ];
    final decoded = wavToPcm16(Uint8List.fromList(spliced));

    expect(decoded.sampleRate, sr);
    expect(decoded.samples, pcm);
  });
}
