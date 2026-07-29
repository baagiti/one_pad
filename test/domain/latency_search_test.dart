import 'package:flutter_test/flutter_test.dart';
import 'package:one_pad/domain/analysis/latency_search.dart';

void main() {
  const sr = 44100;
  int ms(double milliseconds) => (sr * milliseconds / 1000).round();

  test('finds the exact offset for a uniformly-shifted, perfectly detected '
      'take', () {
    final expected = [0, sr, 2 * sr, 3 * sr, 4 * sr];
    const trueOffsetMs = 160.0;
    final detected = expected.map((s) => s + ms(trueOffsetMs)).toList();

    final best = findBestLatencySamples(
      expectedSamples: expected,
      detectedSamples: detected,
      searchToSamples: sr * 2,
    );
    expect((best * 1000 / sr), closeTo(trueOffsetMs, 10));
  });

  test('is robust to a missed first onset (the exact bug this exists to '
      'fix, 2026-07-27)', () {
    // The detector missed the very first hit entirely -- a naive
    // index-by-index pairing (detected[i] <-> expected[i]) would then be
    // off by one for EVERY remaining note, making the true offset look
    // roughly one full note-interval larger than it really is.
    final expected = [0, sr, 2 * sr, 3 * sr, 4 * sr, 5 * sr];
    const trueOffsetMs = 160.0;
    final detected =
        expected.skip(1).map((s) => s + ms(trueOffsetMs)).toList();

    final best = findBestLatencySamples(
      expectedSamples: expected,
      detectedSamples: detected,
      searchToSamples: sr * 2,
    );
    expect((best * 1000 / sr), closeTo(trueOffsetMs, 10));
  });

  test('tolerates a little human timing jitter around the true offset', () {
    final expected = [0, sr, 2 * sr, 3 * sr, 4 * sr, 5 * sr, 6 * sr];
    const trueOffsetMs = 300.0;
    final jitterMs = [0, 20, -15, 30, -25, 10, -5];
    final detected = [
      for (var i = 0; i < expected.length; i++)
        expected[i] + ms(trueOffsetMs) + ms(jitterMs[i].toDouble()),
    ];

    final best = findBestLatencySamples(
      expectedSamples: expected,
      detectedSamples: detected,
      searchToSamples: sr * 2,
    );
    expect((best * 1000 / sr), closeTo(trueOffsetMs, 30));
  });
}
