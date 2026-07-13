/// A single rhythmic token inside a measure: a note or a rest with a duration.
///
/// String encoding (used in content JSON):
///   w h q e s   -> whole, half, quarter, eighth, sixteenth note
///   r prefix    -> rest (e.g. "rq" = quarter rest)
///   . suffix    -> dotted (e.g. "q." = dotted quarter)
///
/// Version 1 content only uses "q", but the model supports the full set so
/// future skills are a content change, not a code change.
class NoteToken {
  final NoteDuration duration;
  final bool isRest;
  final bool isDotted;

  const NoteToken({
    required this.duration,
    this.isRest = false,
    this.isDotted = false,
  });

  /// Length of this token in units of one beat of the given [beatUnit]
  /// (the denominator of the time signature, e.g. 4 in 4/4).
  double lengthInBeats(int beatUnit) {
    final base = beatUnit / duration.denominator;
    return isDotted ? base * 1.5 : base;
  }

  static NoteToken parse(String code) {
    var s = code.trim();
    final isRest = s.startsWith('r');
    if (isRest) s = s.substring(1);
    final isDotted = s.endsWith('.');
    if (isDotted) s = s.substring(0, s.length - 1);
    final duration = NoteDuration.fromCode(s);
    return NoteToken(duration: duration, isRest: isRest, isDotted: isDotted);
  }

  String get code =>
      '${isRest ? 'r' : ''}${duration.code}${isDotted ? '.' : ''}';

  @override
  bool operator ==(Object other) =>
      other is NoteToken &&
      other.duration == duration &&
      other.isRest == isRest &&
      other.isDotted == isDotted;

  @override
  int get hashCode => Object.hash(duration, isRest, isDotted);

  @override
  String toString() => code;
}

enum NoteDuration {
  whole('w', 1),
  half('h', 2),
  quarter('q', 4),
  eighth('e', 8),
  sixteenth('s', 16);

  final String code;

  /// 1 = whole, 2 = half, 4 = quarter...
  final int denominator;

  const NoteDuration(this.code, this.denominator);

  static NoteDuration fromCode(String code) =>
      values.firstWhere((d) => d.code == code,
          orElse: () => throw FormatException('Unknown duration code: $code'));
}
