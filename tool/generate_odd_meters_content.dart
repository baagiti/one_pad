// Generates content/skills/odd_meters_54.json and odd_meters_78.json
// (roadmap title "Odd Meters", design doc §26).
//
// Research (Vic Firth WebRhythms Lesson 6 "Time Signatures and Meter" /
// Lesson 7 "Odd Meter Time Signatures", Drumeo, DrumGearAdvisor): 5/4 and
// 7/8 need genuinely different treatment, split into two Skill objects
// (Skill.timeSignature is one value per skill, design doc §25) just like
// 3/4 vs 6/8 was:
//
//   5/4 is a SIMPLE meter with an odd quarter-note count — grouped 3+2 or
//   2+3, but quarter notes aren't beamed at all, so this needs NO new
//   notation architecture — same "count further" idea as 3/4.
//
//   7/8 has NO single derivable grouping — Vic Firth is explicit: "a bar
//   of seven-eight...can be phrased as 2+2+3, 2+3+2, or 3+2+2 ... the
//   phrasing of each measure is conveyed to you by the beams." This is
//   why Skill.beatGroupPattern (design doc §26) was added: the grouping
//   must be stated by content, not derived. "2+2+3" is the most commonly
//   cited default phrasing, so that's what this content uses throughout.
import 'dart:convert';
import 'dart:io';

class Tpl {
  final String id;
  final List<String> rhythm;
  final List<String> sticking;
  final int difficulty;
  final List<String>? countingLabels;
  Tpl(this.id, this.rhythm, this.sticking, this.difficulty,
      {this.countingLabels});
  Map<String, dynamic> toJson() => {
        'id': id,
        'rhythm': rhythm,
        'sticking': sticking,
        'difficulty': difficulty,
        if (countingLabels != null) 'countingLabels': countingLabels,
      };
}

String other(String h) => h == 'R' ? 'L' : 'R';

/// "How to Count: 7/8" — Level 0, a reading-only intro (design doc, "Sayma
/// (Counting) Giriş Dersleri", 2026-07-27): one measure of straight
/// eighths with "1 & 2 & 3 & a" printed under the notes — the last group
/// of 3 counted with a compound-style "a" (matching this skill's own
/// beatGroupPattern 2+2+3, and Vic Firth's "the beams convey the
/// phrasing" grouping — see file header).
Map<String, dynamic> howToCount78Level() {
  const syllables = ['1', '&', '2', '&', '3', '&', 'a'];
  Tpl tpl(String id, List<String> sticking) => Tpl(
        id,
        List.filled(7, 'e'),
        sticking,
        1,
        countingLabels: syllables,
      );
  final baseA = List.generate(7, (i) => i.isEven ? 'R' : 'L');
  final baseB = List.generate(7, (i) => i.isEven ? 'L' : 'R');
  return {
    'level': 0,
    'name': 'How to Count: 7/8',
    'generation': {
      'strategy': 'pool_shuffle',
      'noAdjacentRepeat': false,
      'difficultyRamp': false,
      'minVariety': 1,
      'sessionFixed': true,
    },
    'templates':
        [tpl('hc0_a', baseA), tpl('hc0_b', baseB)].map((t) => t.toJson()).toList(),
  };
}

Map<String, dynamic> level({
  required int levelNum,
  required String name,
  required List<Tpl> templates,
  required bool sessionFixed,
  int minVariety = 2,
}) {
  return {
    'level': levelNum,
    'name': name,
    'generation': {
      'strategy': 'pool_shuffle',
      'noAdjacentRepeat': !sessionFixed,
      'difficultyRamp': false,
      'minVariety': minVariety,
      'sessionFixed': sessionFixed,
    },
    'templates': templates.map((t) => t.toJson()).toList(),
  };
}

// --- 5/4 (simple, odd count) -------------------------------------------

Tpl buildPulse54(String id, String startHand) {
  final sticking = <String>[];
  var hand = startHand;
  for (var i = 0; i < 5; i++) {
    sticking.add(hand);
    hand = other(hand);
  }
  return Tpl(id, List.filled(5, 'q'), sticking, 1);
}

/// [eighthBeat] (0..4) marks which of the 5 beats is an eighth-pair; the
/// rest are plain quarters. Plain sequential alternation (design doc §17).
Tpl buildEighthTransfer54(String id, int eighthBeat, String startHand) {
  final rhythm = <String>[];
  final sticking = <String>[];
  var hand = startHand;
  void strike(String code) {
    rhythm.add(code);
    sticking.add(hand);
    hand = other(hand);
  }

  for (var b = 0; b < 5; b++) {
    if (b == eighthBeat) {
      strike('e');
      strike('e');
    } else {
      strike('q');
    }
  }
  return Tpl(id, rhythm, sticking, 1);
}

// --- 7/8 (asymmetric, 2+2+3) --------------------------------------------

Tpl buildEighthStream78(String id, String startHand) {
  final sticking = <String>[];
  var hand = startHand;
  for (var i = 0; i < 7; i++) {
    sticking.add(hand);
    hand = other(hand);
  }
  return Tpl(id, List.filled(7, 'e'), sticking, 1);
}

/// One note per group (q, q, q.) — 2+2+3 numerator-beats, exactly filling
/// 7/8 — teaches reading the 3 GROUP pulses instead of every eighth.
Tpl buildGroupPulse78(String id, String startHand) {
  final sticking = [
    startHand,
    other(startHand),
    other(other(startHand)),
  ];
  return Tpl(id, ['q', 'q', 'q.'], sticking, 1);
}

void main() {
  final level1_54 = level(
    levelNum: 1,
    name: 'Quarter-Note Pulse in 5/4',
    templates: [
      buildPulse54('om1_r', 'R'),
      buildPulse54('om1_l', 'L'),
    ],
    sessionFixed: true,
  );

  final level2_54 = level(
    levelNum: 2,
    name: 'Eighth-Note Pairs in 5/4',
    templates: [
      for (var beat = 0; beat < 5; beat++)
        for (final start in ['R', 'L'])
          buildEighthTransfer54(
              'om2_${start.toLowerCase()}_b${beat + 1}', beat, start),
    ],
    sessionFixed: false,
    minVariety: 5,
  );

  final level1_78 = level(
    levelNum: 1,
    name: 'Full Eighth Stream in 7/8 (2+2+3)',
    templates: [
      buildEighthStream78('om3_r', 'R'),
      buildEighthStream78('om3_l', 'L'),
    ],
    sessionFixed: true,
  );

  final level2_78 = level(
    levelNum: 2,
    name: 'Feeling the Groups (2+2+3 Pulse)',
    templates: [
      buildGroupPulse78('om4_r', 'R'),
      buildGroupPulse78('om4_l', 'L'),
    ],
    sessionFixed: true,
  );

  final skill54 = {
    'schemaVersion': 1,
    'skillId': 'odd_meters_54',
    'name': 'Odd Meters',
    'timeSignature': '5/4',
    'bpmDefault': 80,
    'bpmRange': [30, 180],
    'levels': [level1_54, level2_54],
  };

  final skill78 = {
    'schemaVersion': 1,
    'skillId': 'odd_meters_78',
    'name': 'Odd Meters',
    'timeSignature': '7/8',
    'beatGroupPattern': [2, 2, 3],
    'bpmDefault': 60,
    'bpmRange': [30, 140],
    'levels': [howToCount78Level(), level1_78, level2_78],
  };

  for (final (skill, filename) in [
    (skill54, 'odd_meters_54.json'),
    (skill78, 'odd_meters_78.json'),
  ]) {
    final out = File('content/skills/$filename');
    out.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(skill));
    stdout.writeln('Wrote ${out.path}');
  }
}
