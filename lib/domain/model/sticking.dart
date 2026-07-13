enum Hand {
  right('R'),
  left('L');

  final String label;
  const Hand(this.label);

  static Hand parse(String s) => switch (s.trim().toUpperCase()) {
        'R' => Hand.right,
        'L' => Hand.left,
        _ => throw FormatException('Unknown hand: $s'),
      };

  Hand get opposite => this == Hand.right ? Hand.left : Hand.right;
}
