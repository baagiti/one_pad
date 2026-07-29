/// Derives a BPM from a sequence of tap timestamps (design doc §14's
/// "Tap Tempo" control). Pure Dart, no UI/timer dependency — the caller
/// supplies timestamps (e.g. from `DateTime.now()` at each tap).
///
/// A gap longer than [resetGap] starts a fresh sequence, so an old rhythm
/// doesn't bleed into a new one. BPM is the average of the last
/// [maxSamples] inter-tap intervals, which smooths out a single mistimed
/// tap without lagging behind genuine tempo changes.
class TapTempoCalculator {
  final Duration resetGap;
  final int maxSamples;

  final List<DateTime> _taps = [];

  TapTempoCalculator({
    this.resetGap = const Duration(seconds: 2),
    this.maxSamples = 5,
  });

  /// Registers a tap and returns the estimated BPM, or null if at least two
  /// taps in the current sequence aren't available yet.
  int? tap(DateTime at) {
    if (_taps.isNotEmpty && at.difference(_taps.last) > resetGap) {
      _taps.clear();
    }
    _taps.add(at);
    if (_taps.length > maxSamples + 1) {
      _taps.removeAt(0);
    }
    if (_taps.length < 2) return null;

    final totalSpan = _taps.last.difference(_taps.first);
    final intervalCount = _taps.length - 1;
    final avgIntervalMs = totalSpan.inMicroseconds / intervalCount / 1000;
    if (avgIntervalMs <= 0) return null;

    return (60000 / avgIntervalMs).round();
  }

  void reset() => _taps.clear();
}
