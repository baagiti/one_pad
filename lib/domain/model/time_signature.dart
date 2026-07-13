class TimeSignature {
  /// Beats per measure (numerator), e.g. 4 in 4/4, 7 in 7/8.
  final int beats;

  /// Beat unit (denominator): 4 = quarter note, 8 = eighth note.
  final int beatUnit;

  const TimeSignature(this.beats, this.beatUnit)
      : assert(beats > 0),
        assert(beatUnit > 0);

  static const fourFour = TimeSignature(4, 4);

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
