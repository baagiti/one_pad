// Generates content/skills/alternate_meters.json (roadmap title
// "Alternate Meters", design doc §25).
//
// Research (Alfred's Drum Method Lessons 15 "3/4" / 33 "6/8 in 2 with
// Rolls", Vic Firth WebRhythms Lessons 6 "Time Signatures and Meter" / 7
// "Odd Meter Time Signatures", Drumeo): 3/4 and 6/8 are pedagogically far
// apart — Alfred's puts 18 lessons between them — because they are
// DIFFERENT KINDS of meter, not just "more beats":
//
//   3/4 is SIMPLE triple: 3 quarter-note beats, each divides in 2 (same
//   subdivision logic as 4/4, just 3 beats instead of 4). No new reading
//   skill beyond "count to 3, not 4."
//
//   6/8 is COMPOUND duple: the numerator (6) is NOT the felt beat count —
//   there are really 2 pulses (dotted quarters), each dividing in 3. This
//   is a genuinely new subdivision concept ("surprisingly complicated...
//   always hard for drummers to get the hang of at first," multiple
//   sources agree) and is why this skill's levels are grouped simple (3/4)
//   then compound (6/8), not interleaved.
//
// Architectural fix made BEFORE this content (design doc §25):
// NotationLayout's beam-width formula assumed simple-meter "1 numerator
// beat" as the default grouping unit. For 6/8, 1 numerator-beat is a
// single eighth note, which would leave everything unbeamed. Compound
// meters now always group by the 3-numerator-beat compound pulse
// (TimeSignature.isCompound), which also happens to correctly beam the
// Double Paradiddle's 6-stroke cells (Level 5 below) — the rudiment
// deferred from Skill 6 (8th-note speed, needed 2 measures) and Skill 8
// (16th-note speed, needed 3 beats, not a whole 4/4 measure): 12
// sixteenth notes = exactly one 6/8 measure, the rudiment's true home.
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

/// "How to Count: 6/8" — Level 0, a reading-only intro (design doc, "Sayma
/// (Counting) Giriş Dersleri", 2026-07-27): one measure of straight
/// eighths with "1 & a 2 & a" printed under the notes — DELIBERATELY
/// different from 4/4 sixteenth notes' "1 e & a" (superficially similar,
/// genuinely different pulse — see file header's compound-meter research),
/// so this needs its own explicit lesson, not a reused one.
Map<String, dynamic> howToCount68Level() {
  const syllables = ['1', '&', 'a', '2', '&', 'a'];
  Tpl tpl(String id, List<String> sticking) => Tpl(
        id,
        List.filled(6, 'e'),
        sticking,
        1,
        countingLabels: syllables,
      );
  final baseA = List.generate(6, (i) => i.isEven ? 'R' : 'L');
  final baseB = List.generate(6, (i) => i.isEven ? 'L' : 'R');
  return {
    'level': 0,
    'name': 'How to Count: 6/8',
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

// --- 3/4 (simple triple) ---------------------------------------------

Tpl buildPulse34(String id, String startHand) {
  final sticking = <String>[];
  var hand = startHand;
  for (var i = 0; i < 3; i++) {
    sticking.add(hand);
    hand = other(hand);
  }
  return Tpl(id, ['q', 'q', 'q'], sticking, 1);
}

/// [eighthBeat] (0,1,2) marks which of the 3 beats is an eighth-pair; the
/// other two beats are plain quarters. Plain sequential alternation across
/// whatever is actually struck (Skill 3's corrected model, design doc §17).
Tpl buildEighthTransfer34(String id, int eighthBeat, String startHand) {
  final rhythm = <String>[];
  final sticking = <String>[];
  var hand = startHand;
  void strike(String code) {
    rhythm.add(code);
    sticking.add(hand);
    hand = other(hand);
  }

  for (var b = 0; b < 3; b++) {
    if (b == eighthBeat) {
      strike('e');
      strike('e');
    } else {
      strike('q');
    }
  }
  return Tpl(id, rhythm, sticking, 1);
}

// --- 6/8 (compound duple) ---------------------------------------------

Tpl buildEighthStream68(String id, String startHand) {
  final sticking = <String>[];
  var hand = startHand;
  for (var i = 0; i < 6; i++) {
    sticking.add(hand);
    hand = other(hand);
  }
  return Tpl(id, List.filled(6, 'e'), sticking, 1);
}

Tpl buildDottedQuarterPulse68(String id, String startHand) {
  final sticking = [startHand, other(startHand)];
  return Tpl(id, ['q.', 'q.'], sticking, 1);
}

/// One 6-stroke Double Paradiddle half: 4 alternating strokes then a
/// double on the lead hand (e.g. lead=R -> R,L,R,L,R,R).
List<String> doubleParadiddleHalf(String lead) {
  final s = <String>[];
  var hand = lead;
  for (var i = 0; i < 4; i++) {
    s.add(hand);
    hand = other(hand);
  }
  s.add(hand);
  s.add(hand);
  return s;
}

/// Double Paradiddle at sixteenth-note speed: 12 strokes = exactly one 6/8
/// measure (its natural home — see file header).
Tpl buildDoubleParadiddle(String id, String startHand) {
  final half1 = doubleParadiddleHalf(startHand);
  final half2 = doubleParadiddleHalf(other(startHand));
  final sticking = [...half1, ...half2];
  final rhythm = [
    for (var i = 0; i < 12; i++) (i == 0 || i == 6) ? 's>' : 's',
  ];
  return Tpl(id, rhythm, sticking, 1);
}

/// One 6-stroke Single Paradiddle-Diddle half: two singles then two
/// doubles ("para-diddle-diddle" — PAS: "two single strokes and two
/// double strokes, the first single stroke accented"), e.g. lead=R ->
/// R,L,R,R,L,L. Same 6-stroke cell size as the Double Paradiddle, so it
/// fits 6/8 identically — deferred alongside it (design doc §20/§25),
/// added here to close that gap.
List<String> paradiddleDiddleHalf(String lead) {
  final o = other(lead);
  return [lead, o, lead, lead, o, o];
}

Tpl buildParadiddleDiddle(String id, String startHand) {
  final half1 = paradiddleDiddleHalf(startHand);
  final half2 = paradiddleDiddleHalf(other(startHand));
  final sticking = [...half1, ...half2];
  final rhythm = [
    for (var i = 0; i < 12; i++) (i == 0 || i == 6) ? 's>' : 's',
  ];
  return Tpl(id, rhythm, sticking, 1);
}

/// Duplet: 2 EVEN notes filling one compound pulse instead of the usual 3
/// — "against the grain" of 6/8's natural triplet feel (Vic Firth
/// WebRhythms Lesson 15, 2026-07-27 gap-analysis addition). [dupletPulse]
/// (0 or 1) marks which of the 2 compound pulses is the duplet; the other
/// stays a plain dotted-quarter pulse (Level 2's representation) so the
/// new sound is isolated, same "introduce it alone first" structure used
/// throughout this project.
Tpl buildDuplet68(String id, int dupletPulse, String startHand) {
  final rhythm = <String>[];
  final sticking = <String>[];
  var hand = startHand;
  void strike(String code) {
    rhythm.add(code);
    sticking.add(hand);
    hand = other(hand);
  }

  for (var p = 0; p < 2; p++) {
    if (p == dupletPulse) {
      strike('ed');
      strike('ed');
    } else {
      strike('q.');
    }
  }
  return Tpl(id, rhythm, sticking, 1);
}

void main() {
  final level1 = level(
    levelNum: 1,
    name: 'Quarter-Note Pulse in 3/4',
    templates: [
      buildPulse34('am1_r', 'R'),
      buildPulse34('am1_l', 'L'),
    ],
    sessionFixed: true,
  );

  final level2 = level(
    levelNum: 2,
    name: 'Eighth-Note Pairs in 3/4',
    templates: [
      for (var beat = 0; beat < 3; beat++)
        for (final start in ['R', 'L'])
          buildEighthTransfer34(
              'am2_${start.toLowerCase()}_b${beat + 1}', beat, start),
    ],
    sessionFixed: false,
    minVariety: 3,
  );

  final level3 = level(
    levelNum: 3,
    name: 'Full Eighth Stream in 6/8',
    templates: [
      buildEighthStream68('am3_r', 'R'),
      buildEighthStream68('am3_l', 'L'),
    ],
    sessionFixed: true,
  );

  final level4 = level(
    levelNum: 4,
    name: 'Dotted-Quarter Pulse (Feeling the 2)',
    templates: [
      buildDottedQuarterPulse68('am4_r', 'R'),
      buildDottedQuarterPulse68('am4_l', 'L'),
    ],
    sessionFixed: true,
  );

  final level5 = level(
    levelNum: 5,
    name: 'Double Paradiddle',
    templates: [
      buildDoubleParadiddle('am5_r', 'R'),
      buildDoubleParadiddle('am5_l', 'L'),
    ],
    sessionFixed: true,
  );

  final level6 = level(
    levelNum: 6,
    name: 'Single Paradiddle-Diddle',
    templates: [
      buildParadiddleDiddle('am6_r', 'R'),
      buildParadiddleDiddle('am6_l', 'L'),
    ],
    sessionFixed: true,
  );

  final level7 = level(
    levelNum: 7,
    name: 'Duplets (2 Against the Grain)',
    templates: [
      for (var pulse = 0; pulse < 2; pulse++)
        for (final start in ['R', 'L'])
          buildDuplet68(
              'am7_${start.toLowerCase()}_p${pulse + 1}', pulse, start),
    ],
    sessionFixed: false,
    minVariety: 2,
  );

  final skill34 = {
    'schemaVersion': 1,
    'skillId': 'alternate_meters_34',
    'name': 'Alternate Meters',
    'timeSignature': '3/4',
    'bpmDefault': 80,
    'bpmRange': [30, 180],
    'levels': [level1, level2],
  };

  final skill68 = {
    'schemaVersion': 1,
    'skillId': 'alternate_meters_68',
    'name': 'Alternate Meters',
    'timeSignature': '6/8',
    'bpmDefault': 60,
    'bpmRange': [30, 140],
    'levels': [
      howToCount68Level(),
      {...level3, 'level': 1},
      {...level4, 'level': 2},
      {...level5, 'level': 3},
      {...level6, 'level': 4},
      {...level7, 'level': 5},
    ],
  };

  for (final (skill, filename) in [
    (skill34, 'alternate_meters_34.json'),
    (skill68, 'alternate_meters_68.json'),
  ]) {
    final out = File('content/skills/$filename');
    out.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(skill));
    stdout.writeln('Wrote ${out.path}');
  }
}
