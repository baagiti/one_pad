import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_pad/domain/analysis/onset_detector.dart';

/// A quiet noise floor with short broadband noise bursts (decaying
/// envelope) spliced in at [positions] — stands in for real drum-pad
/// attacks, which are broadband transients, not pure tones.
Float64List _syntheticClicks(List<int> positions, int length,
    {int burstLength = 3000}) {
  final rng = Random(42);
  final out = Float64List(length);
  for (var i = 0; i < length; i++) {
    out[i] = (rng.nextDouble() - 0.5) * 0.001;
  }
  for (final pos in positions) {
    for (var i = 0; i < burstLength && pos + i < length; i++) {
      final decay = exp(-i / (burstLength / 6));
      out[pos + i] += (rng.nextDouble() - 0.5) * decay;
    }
  }
  return out;
}

void main() {
  const sampleRate = 44100;

  test('detects synthetic click bursts near their true sample positions', () {
    final positions = [5000, 20000, 40000];
    final signal = _syntheticClicks(positions, 50000);
    final onsets = OnsetDetector(sampleRate: sampleRate).detect(signal);

    expect(onsets, hasLength(3));
    for (var i = 0; i < positions.length; i++) {
      expect((onsets[i] - positions[i]).abs(), lessThan(1000),
          reason: 'onset $i (${onsets[i]}) vs expected (${positions[i]})');
    }
  });

  test('silence produces no onsets', () {
    final signal = Float64List(20000);
    final onsets = OnsetDetector(sampleRate: sampleRate).detect(signal);
    expect(onsets, isEmpty);
  });

  test('a single burst\'s decaying ring registers as one onset, not several',
      () {
    // One burst's resonance/decay tail must not be mistaken for a second
    // hit — the whole point of debouncing.
    final signal = _syntheticClicks([5000], 20000, burstLength: 3000);
    final onsets = OnsetDetector(sampleRate: sampleRate).detect(signal);
    expect(onsets, hasLength(1));
  });
}
