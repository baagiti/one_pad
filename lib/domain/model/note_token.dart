/// A single rhythmic token inside a measure: a note or a rest with a duration.
///
/// String encoding (used in content JSON):
///   w h q e s x -> whole, half, quarter, eighth, sixteenth, 32nd note
///   r prefix    -> rest (e.g. "rq" = quarter rest)
///   . suffix    -> dotted (e.g. "q." = dotted quarter)
///   > suffix    -> accented, after the dot if both present (e.g. "e>")
///   ~ suffix    -> tied FROM the previous token (no new attack), after
///                  the dot/accent if present (e.g. "q~") — design doc §24
///   t suffix    -> triplet (one of 3 notes filling the space normally
///                  taken by 2 of the same base duration — "3 in the time
///                  of 2"), the outermost/last suffix (e.g. "et") — design
///                  doc §27
///   d suffix    -> duplet (one of 2 notes filling the space normally
///                  taken by 3 of the same base duration — "2 in the time
///                  of 3", the triplet's mirror image; only meaningful in a
///                  compound meter, where the natural pulse subdivides in
///                  3 — e.g. "ed" in 6/8), same outermost position as
///                  triplet (mutually exclusive with it)
///
/// Version 1 content only uses "q", but the model supports the full set so
/// future skills are a content change, not a code change.
class NoteToken {
  final NoteDuration duration;
  final bool isRest;
  final bool isDotted;
  final bool isAccented;
  final bool isTied;
  final bool isTriplet;
  final bool isDuplet;

  const NoteToken({
    required this.duration,
    this.isRest = false,
    this.isDotted = false,
    this.isAccented = false,
    this.isTied = false,
    this.isTriplet = false,
    this.isDuplet = false,
  });

  /// Length of this token in units of one beat of the given [beatUnit]
  /// (the denominator of the time signature, e.g. 4 in 4/4). A triplet
  /// note is 2/3 of its base duration — three of them sum to exactly what
  /// two non-triplet notes of the same duration would (design doc §27). A
  /// duplet note is the mirror image, 3/2 of its base duration — two of
  /// them sum to exactly what three non-duplet notes would (i.e. one full
  /// compound pulse).
  double lengthInBeats(int beatUnit) {
    final base = beatUnit / duration.denominator;
    final dotted = isDotted ? base * 1.5 : base;
    if (isTriplet) return dotted * 2 / 3;
    if (isDuplet) return dotted * 3 / 2;
    return dotted;
  }

  /// True for a token that gets its own stick attack — a rest has no
  /// sound at all, and a tied token continues the PREVIOUS token's sound
  /// with no new attack (design doc §24), so neither gets a sticking
  /// assignment or a reference-hit/click at its own onset.
  bool get isStruck => !isRest && !isTied;

  static NoteToken parse(String code) {
    var s = code.trim();
    final isRest = s.startsWith('r');
    if (isRest) s = s.substring(1);
    final isTriplet = s.endsWith('t');
    if (isTriplet) s = s.substring(0, s.length - 1);
    final isDuplet = !isTriplet && s.endsWith('d');
    if (isDuplet) s = s.substring(0, s.length - 1);
    final isTied = s.endsWith('~');
    if (isTied) s = s.substring(0, s.length - 1);
    final isAccented = s.endsWith('>');
    if (isAccented) s = s.substring(0, s.length - 1);
    final isDotted = s.endsWith('.');
    if (isDotted) s = s.substring(0, s.length - 1);
    final duration = NoteDuration.fromCode(s);
    return NoteToken(
        duration: duration,
        isRest: isRest,
        isDotted: isDotted,
        isAccented: isAccented,
        isTied: isTied,
        isTriplet: isTriplet,
        isDuplet: isDuplet);
  }

  String get code =>
      '${isRest ? 'r' : ''}${duration.code}${isDotted ? '.' : ''}${isAccented ? '>' : ''}${isTied ? '~' : ''}${isTriplet ? 't' : ''}${isDuplet ? 'd' : ''}';

  @override
  bool operator ==(Object other) =>
      other is NoteToken &&
      other.duration == duration &&
      other.isRest == isRest &&
      other.isDotted == isDotted &&
      other.isAccented == isAccented &&
      other.isTied == isTied &&
      other.isTriplet == isTriplet &&
      other.isDuplet == isDuplet;

  @override
  int get hashCode => Object.hash(
      duration, isRest, isDotted, isAccented, isTied, isTriplet, isDuplet);

  @override
  String toString() => code;
}

enum NoteDuration {
  whole('w', 1),
  half('h', 2),
  quarter('q', 4),
  eighth('e', 8),
  sixteenth('s', 16),
  thirtySecond('x', 32);

  final String code;

  /// 1 = whole, 2 = half, 4 = quarter...
  final int denominator;

  const NoteDuration(this.code, this.denominator);

  static NoteDuration fromCode(String code) =>
      values.firstWhere((d) => d.code == code,
          orElse: () => throw FormatException('Unknown duration code: $code'));
}
