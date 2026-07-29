import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fftea/fftea.dart';

/// Offline onset detection for one recorded take (design doc §9, M4):
/// spectral flux (the sum of positive per-bin magnitude increases between
/// consecutive STFT frames) with adaptive-threshold peak-picking. This is
/// the standard approach for percussive attacks (drum-pad hits) — pitch and
/// timbre don't matter here, only "did the energy jump."
///
/// Runs once over a whole finished recording — not real-time streaming — so
/// there's no need for `flutter_recorder`'s own live FFT/PCMFormat.f32le
/// path; this reads the already-saved WAV file straight from PCM.
///
/// Deliberately blind to WHERE the metronome click was supposed to land —
/// separating "sound vs. no sound" is this class's only job. A recording
/// made without headphones will also show the metronome as onsets here
/// (confirmed 2026-07-27: its acoustic path through a speaker+mic loopback
/// reshapes the click's spectrum too unpredictably for a frequency-based
/// filter to reject reliably). Rejecting those is [TimingScorer]'s job,
/// which already knows the click's exact scheduled sample positions and can
/// exclude onsets that land on them — a much more precise signal than
/// anything this detector could infer from the audio alone.
class OnsetDetector {
  final int sampleRate;
  final int fftSize;
  final int hopSize;

  OnsetDetector({
    required this.sampleRate,
    this.fftSize = 1024,
    this.hopSize = 256,
  });

  /// Sample offsets of detected onsets (frame-start position — coarser than
  /// the ~1 sample of the underlying audio, but well within the tens-of-ms
  /// tolerance [TimingScorer] matches against).
  List<int> detect(Float64List samples) {
    final stft = STFT(fftSize, Window.hanning(fftSize));
    final flux = <double>[];
    Float64List? prevMag;

    stft.run(samples, (Float64x2List freq) {
      final mag = freq.discardConjugates().magnitudes();
      if (prevMag == null) {
        flux.add(0);
      } else {
        var sum = 0.0;
        final prev = prevMag!;
        for (var i = 0; i < mag.length; i++) {
          final d = mag[i] - prev[i];
          if (d > 0) sum += d;
        }
        flux.add(sum);
      }
      prevMag = mag;
    }, hopSize);

    return _pickPeaks(flux);
  }

  List<int> _pickPeaks(List<double> flux) {
    if (flux.isEmpty) return const [];

    // Adaptive threshold: local mean + k * local std over a sliding window,
    // so a quiet passage's onsets aren't drowned by an earlier loud one.
    const windowRadius = 20;
    const k = 3.0;
    const minGapFrames = 4; // debounce: no two onsets closer than this

    // A relative-adaptive threshold alone still fires on pure noise: a noise
    // floor's flux is itself a random process, and some of its frames will
    // look "several std above the local mean" purely by chance. Requiring
    // every peak to also clear a fraction of the WHOLE recording's loudest
    // flux value rejects those — real attacks dwarf noise-floor fluctuation
    // in absolute terms, even where both look "elevated" relative to their
    // own tiny local baseline.
    var globalMax = 0.0;
    for (final f in flux) {
      if (f > globalMax) globalMax = f;
    }
    final floor = globalMax * 0.15;

    final onsets = <int>[];
    var lastPeak = -minGapFrames * 2;

    for (var i = 0; i < flux.length; i++) {
      final lo = math.max(0, i - windowRadius);
      final hi = math.min(flux.length - 1, i + windowRadius);
      final count = hi - lo + 1;

      var mean = 0.0;
      for (var j = lo; j <= hi; j++) {
        mean += flux[j];
      }
      mean /= count;

      var variance = 0.0;
      for (var j = lo; j <= hi; j++) {
        final d = flux[j] - mean;
        variance += d * d;
      }
      final std = math.sqrt(variance / count);
      final threshold = math.max(mean + k * std, floor);

      final isLocalMax = (i == 0 || flux[i] >= flux[i - 1]) &&
          (i == flux.length - 1 || flux[i] >= flux[i + 1]);

      if (flux[i] > threshold &&
          isLocalMax &&
          i - lastPeak >= minGapFrames) {
        onsets.add(i * hopSize);
        lastPeak = i;
      }
    }
    return onsets;
  }
}
