// Generates content/skills/triplets.json (roadmap title "Triplets", design
// doc §27) — a skill added mid-session after a deliberate gap-analysis
// pass (user: "don't just think of the current menu as the curriculum —
// add a skill if research shows we need one").
//
// Research (Vic Firth WebRhythms Lesson 8 "Eighth Note Triplets" / Lesson 9
// "Quarter Note Triplets", Alfred's Drum Method Lessons 22-23): triplets
// are "3 in the time of 2" — the only way to get 3 truly equal
// subdivisions of a beat (unlike an eighth+2 sixteenths, which also has 3
// strokes but isn't evenly spaced). Eighth-note triplets are taught first
// (fill one quarter-note beat); quarter-note triplets are sequenced after,
// as a harder derivative (fill two quarter-note beats).
//
// Deliberately excluded (see design doc §27 for the full reasoning):
// flams/drags/named-roll rudiments — confirmed via research to be tone/
// technique embellishments (a flam's grace note "has no rhythmic value"),
// not a timing-reading skill, and this app's whole premise is timing-only
// analysis (a microphone can't tell which hand struck). Swing/shuffle feel
// (same written eighths, different implied timing) is a genuinely
// different kind of concept — a reading CONVENTION, not new notation —
// noted as a possible future skill but out of scope here.
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

/// "How to Count: Triplets" — Level 0, a reading-only intro (design doc,
/// "Sayma (Counting) Giriş Dersleri", 2026-07-27): one measure of eighth-
/// note triplets with "1 trip-let 2 trip-let..." printed under the notes
/// instead of sticking.
Map<String, dynamic> howToCountLevel() {
  const syllables = [
    '1', 'trip', 'let', '2', 'trip', 'let',
    '3', 'trip', 'let', '4', 'trip', 'let',
  ];
  Tpl tpl(String id, List<String> sticking) => Tpl(
        id,
        List.filled(12, 'et'),
        sticking,
        1,
        countingLabels: syllables,
      );
  final baseA = List.generate(12, (i) => i.isEven ? 'R' : 'L');
  final baseB = List.generate(12, (i) => i.isEven ? 'L' : 'R');
  return {
    'level': 0,
    'name': 'How to Count: Triplets',
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
  required int minVariety,
}) {
  return {
    'level': levelNum,
    'name': name,
    'generation': {
      'strategy': 'pool_shuffle',
      'noAdjacentRepeat': true,
      'difficultyRamp': false,
      'minVariety': minVariety,
      'sessionFixed': false,
    },
    'templates': templates.map((t) => t.toJson()).toList(),
  };
}

/// [tripletBeat] (0..3) marks which of the 4 beats is an eighth-note
/// triplet (3 strokes); the other 3 beats are plain quarters. Plain
/// sequential alternation across whatever is actually struck (design doc
/// §17) — the odd (3-stroke) triplet beat naturally flips the lead hand
/// for the next beat, exactly as real triplet reading requires.
Tpl buildEighthTripletFigure(String id, int tripletBeat, String startHand) {
  final rhythm = <String>[];
  final sticking = <String>[];
  var hand = startHand;
  void strike(String code) {
    rhythm.add(code);
    sticking.add(hand);
    hand = other(hand);
  }

  for (var b = 0; b < 4; b++) {
    if (b == tripletBeat) {
      strike('et');
      strike('et');
      strike('et');
    } else {
      strike('q');
    }
  }
  return Tpl(id, rhythm, sticking, 1);
}

/// Measure-half building block: 'T' = 3 quarter-note triplets (fills the
/// whole half, 2 beats), 'Q' = two plain quarters. Same method as Skill 5
/// (§19) / Skill 9 (§24)'s measure-half figures.
Tpl buildQuarterTripletTemplate(
    String id, List<String> halves, String startHand) {
  final rhythm = <String>[];
  final sticking = <String>[];
  var hand = startHand;
  void strike(String code) {
    rhythm.add(code);
    sticking.add(hand);
    hand = other(hand);
  }

  for (final half in halves) {
    if (half == 'T') {
      strike('qt');
      strike('qt');
      strike('qt');
    } else {
      strike('q');
      strike('q');
    }
  }
  return Tpl(id, rhythm, sticking, 1);
}

/// [tripletBeat] (0..3) marks which of the 4 beats is a full sixteenth-note
/// triplet group ("sextuplet": 6 sixteenth-triplets fill the beat, the
/// natural next step after Level 1's eighth-triplet — same "isolate the new
/// sound in one beat, rest plain" structure, one hand-speed tier faster.
/// Vic Firth WebRhythms Lesson 11 confirms this is the standard next lesson
/// after basic (eighth/quarter) triplets are secure.
Tpl buildSixteenthTripletFigure(String id, int tripletBeat, String startHand) {
  final rhythm = <String>[];
  final sticking = <String>[];
  var hand = startHand;
  void strike(String code) {
    rhythm.add(code);
    sticking.add(hand);
    hand = other(hand);
  }

  for (var b = 0; b < 4; b++) {
    if (b == tripletBeat) {
      for (var i = 0; i < 6; i++) {
        strike('st');
      }
    } else {
      strike('q');
    }
  }
  return Tpl(id, rhythm, sticking, 1);
}

void main() {
  final level1 = level(
    levelNum: 1,
    name: 'Eighth-Note Triplets',
    templates: [
      for (var beat = 0; beat < 4; beat++)
        for (final start in ['R', 'L'])
          buildEighthTripletFigure(
              'tr1_${start.toLowerCase()}_b${beat + 1}', beat, start),
    ],
    minVariety: 4,
  );

  final level2 = level(
    levelNum: 2,
    name: 'Quarter-Note Triplets',
    templates: [
      for (final halves in [
        ['T', 'Q'],
        ['Q', 'T'],
      ])
        for (final start in ['R', 'L'])
          buildQuarterTripletTemplate(
              'tr2_${start.toLowerCase()}_${halves.join().toLowerCase()}',
              halves,
              start),
    ],
    minVariety: 2,
  );

  final level3 = level(
    levelNum: 3,
    name: 'Sixteenth-Note Triplets (Sextuplets)',
    templates: [
      for (var beat = 0; beat < 4; beat++)
        for (final start in ['R', 'L'])
          buildSixteenthTripletFigure(
              'tr3_${start.toLowerCase()}_b${beat + 1}', beat, start),
    ],
    minVariety: 4,
  );

  final skill = {
    'schemaVersion': 1,
    'skillId': 'triplets',
    'name': 'Triplets',
    'timeSignature': '4/4',
    'bpmDefault': 70,
    'bpmRange': [30, 240],
    'levels': [howToCountLevel(), level1, level2, level3],
  };

  final out = File('content/skills/triplets.json');
  out.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(skill));
  stdout.writeln('Wrote ${out.path}');
}
