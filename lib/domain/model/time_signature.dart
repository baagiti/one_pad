class TimeSignature {
  /// Beats per measure (numerator), e.g. 4 in 4/4, 7 in 7/8.
  final int beats;

  /// Beat unit (denominator): 4 = quarter note, 8 = eighth note.
  final int beatUnit;

  const TimeSignature(this.beats, this.beatUnit)
      : assert(beats > 0),
        assert(beatUnit > 0);

  static const fourFour = TimeSignature(4, 4);

  /// Compound meter (e.g. 6/8, 9/8, 12/8): the numerator is a multiple of 3
  /// greater than 3, meaning the REAL pulse is numerator/3 dotted notes,
  /// each subdividing into 3 — not `numerator` separate simple beats (3/4
  /// is simple triple, not compound, despite also being divisible by 3;
  /// design doc §25). This changes beam grouping: simple meters group by 1
  /// numerator-beat by default (2 eighths in 4/4), but a compound meter's
  /// natural group is the 3-numerator-beat compound pulse (3 eighths, or 6
  /// sixteenths, per dotted-quarter-equivalent).
  bool get isCompound => beats > 3 && beats % 3 == 0;

  static TimeSignature parse(String s) {
    final parts = s.split('/');
    if (parts.length != 2) {
      throw FormatException('Invalid time signature: $s');
    }
    return TimeSignature(int.parse(parts[0]), int.parse(parts[1]));
  }

  @override
  bool operator ==(Object other) =>
      other is TimeSignature && other.beats == beats && other.beatUnit == beatUnit;

  @override
  int get hashCode => Object.hash(beats, beatUnit);

  @override
  String toString() => '$beats/$beatUnit';
}
