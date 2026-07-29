/// Finds the constant offset that best aligns [detectedSamples] onto
/// [expectedSamples]: tries candidate offsets across the search range and
/// picks the one that matches the most notes (greedy nearest-unused within
/// [matchWindowSamples], the same rule [TimingScorer] uses for its own
/// note-by-note matching) — ties broken by the smallest total deviation
/// among those matches.
///
/// Exists because a single upfront device calibration ([CalibrationService])
/// turned out not to reliably predict a real take's actual required offset
/// (2026-07-27: an 8-click calibration track measured ~271ms round-trip on
/// one machine, but a real ~38s Record-mode session needed ~870-900ms to
/// align its hits with the expected rhythm — the exact cause of that gap
/// wasn't pinned down, likely something about how a much longer loaded
/// buffer starts playing versus a short one). Rather than trust a number
/// measured under different conditions than the take being scored, this
/// derives the offset from the take's own data directly.
int findBestLatencySamples({
  required List<int> expectedSamples,
  required List<int> detectedSamples,
  int searchFromSamples = 0,
  required int searchToSamples,
  int stepSamples = 441, // 10ms @ 44100
  int matchWindowSamples = 3528, // 80ms @ 44100 ("Good" band)
}) {
  var bestOffset = searchFromSamples;
  var bestMatchCount = -1;
  var bestTotalAbsDeviation = 0;

  for (var offset = searchFromSamples;
      offset <= searchToSamples;
      offset += stepSamples) {
    final adjusted =
        detectedSamples.map((s) => s - offset).toList(growable: false);
    final used = List<bool>.filled(adjusted.length, false);
    var matchCount = 0;
    var totalAbsDeviation = 0;

    for (final expected in expectedSamples) {
      var bestIndex = -1;
      var bestDelta = 0;
      for (var i = 0; i < adjusted.length; i++) {
        if (used[i]) continue;
        final delta = adjusted[i] - expected;
        if (delta.abs() > matchWindowSamples) continue;
        if (bestIndex == -1 || delta.abs() < bestDelta.abs()) {
          bestIndex = i;
          bestDelta = delta;
        }
      }
      if (bestIndex != -1) {
        used[bestIndex] = true;
        matchCount++;
        totalAbsDeviation += bestDelta.abs();
      }
    }

    if (matchCount > bestMatchCount ||
        (matchCount == bestMatchCount &&
            totalAbsDeviation < bestTotalAbsDeviation)) {
      bestMatchCount = matchCount;
      bestTotalAbsDeviation = totalAbsDeviation;
      bestOffset = offset;
    }
  }
  return bestOffset;
}
