import 'package:flutter_test/flutter_test.dart';
import 'package:one_pad/application/tempo/tap_tempo_calculator.dart';

void main() {
  test('first tap produces no estimate', () {
    final calc = TapTempoCalculator();
    expect(calc.tap(DateTime(2026, 1, 1, 0, 0, 0)), isNull);
  });

  test('two taps 500ms apart estimate 120 BPM', () {
    final calc = TapTempoCalculator();
    final t0 = DateTime(2026, 1, 1, 0, 0, 0);
    calc.tap(t0);
    final bpm = calc.tap(t0.add(const Duration(milliseconds: 500)));
    expect(bpm, 120);
  });

  test('averages the last few intervals (smooths a single mistimed tap)',
      () {
    final calc = TapTempoCalculator();
    var t = DateTime(2026, 1, 1);
    calc.tap(t);
    for (var i = 0; i < 3; i++) {
      t = t.add(const Duration(milliseconds: 500)); // steady 120 BPM
      calc.tap(t);
    }
    // one slightly off interval
    t = t.add(const Duration(milliseconds: 520));
    final bpm = calc.tap(t);
    expect(bpm, closeTo(119, 1));
  });

  test('a long gap resets the sequence', () {
    final calc = TapTempoCalculator();
    var t = DateTime(2026, 1, 1);
    calc.tap(t);
    t = t.add(const Duration(milliseconds: 500));
    calc.tap(t); // 120 BPM established

    t = t.add(const Duration(seconds: 3)); // gap > resetGap
    expect(calc.tap(t), isNull); // sequence restarted, only one tap so far

    final bpm = calc.tap(t.add(const Duration(milliseconds: 750))); // 80 BPM
    expect(bpm, 80);
  });

  test('reset clears the sequence explicitly', () {
    final calc = TapTempoCalculator();
    calc.tap(DateTime(2026, 1, 1));
    calc.reset();
    expect(calc.tap(DateTime(2026, 1, 1, 0, 0, 1)), isNull);
  });

  test('only keeps the last maxSamples+1 taps', () {
    final calc = TapTempoCalculator(maxSamples: 2);
    var t = DateTime(2026, 1, 1);
    calc.tap(t);
    t = t.add(const Duration(milliseconds: 1000)); // 60 BPM
    calc.tap(t);
    t = t.add(const Duration(milliseconds: 500)); // 120 BPM
    calc.tap(t);
    t = t.add(const Duration(milliseconds: 500)); // 120 BPM
    // window should now only contain the two most recent 120-BPM intervals
    final bpm = calc.tap(t);
    expect(bpm, 120);
  });
}
