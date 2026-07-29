import 'package:flutter_test/flutter_test.dart';
import 'package:one_pad/domain/progress/progress_policy.dart';

void main() {
  test('no tier below 1 rep', () {
    expect(tierFor(0), ProgressTier.none);
  });

  test('tier boundaries match the 2026-07-27 spec (1/6/16/31/51)', () {
    expect(tierFor(1), ProgressTier.practicing);
    expect(tierFor(5), ProgressTier.practicing);
    expect(tierFor(6), ProgressTier.solid);
    expect(tierFor(15), ProgressTier.solid);
    expect(tierFor(16), ProgressTier.mastered);
    expect(tierFor(30), ProgressTier.mastered);
    expect(tierFor(31), ProgressTier.virtuoso);
    expect(tierFor(50), ProgressTier.virtuoso);
    expect(tierFor(51), ProgressTier.legend);
    expect(tierFor(200), ProgressTier.legend);
  });

  test('labels match the agreed tier names', () {
    expect(ProgressTier.practicing.label, 'Practicing');
    expect(ProgressTier.solid.label, 'Solid');
    expect(ProgressTier.mastered.label, 'Mastered');
    expect(ProgressTier.virtuoso.label, 'Virtuoso');
    expect(ProgressTier.legend.label, 'Legend');
  });
}
