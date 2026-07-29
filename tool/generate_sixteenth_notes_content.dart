// Generates content/skills/sixteenth_notes.json (roadmap title
// "Sixteenth Notes", design doc §21).
//
// Research (Vic Firth WebRhythms Lessons 3B-3D & 4, cross-checked against
// Alfred's Drum Method and Drumeo): sixteenth notes are introduced in this
// exact sequence —
//   3B: a full "1 e and a" group of 4 sixteenths, against an already-known
//       eighth-pair backdrop.
//   3C: two sixteenths + an eighth ("the FIRST eighth of a pair broken").
//   3D: an eighth + two sixteenths ("the SECOND eighth broken") — unlike
//       Skill 4's excluded reverse offbeat shape, both orders here are real,
//       audibly distinct, genuinely taught figures — neither is redundant.
//   4:  sixteenth RESTS. Vic Firth is explicit: "sixteenths always follow
//       RLRL […] regardless of rest placement" — i.e. the FIXED-GRID
//       "ghost stroke" model (Skill 2's model for quarter rests), not the
//       "plain sequential alternation" correction from Skill 3. The
//       difference: a beat of sixteenths is always a genuine 4-slot grid,
//       whether all 4 sound or some are rests — unlike Skill 3's density
//       levels, which mixed different-length notes with no shared grid.
//
// Dotted-eighth-and-sixteenth combinations (Vic Firth Lesson 5) are
// deliberately NOT included here — user decision, kept for a dedicated
// later skill (mirrors how Skill 5 was carved out of Skill 3's leftover
// scope) rather than growing this skill further.
//
// Levels 5-7 (full 16-note stream: steady alternation, lead-hand switching,
// doubles) reapply Skill 3's already-validated full-stream sticking
// sub-curriculum (design doc §17) one subdivision level up.
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

/// "How to Count: Sixteenth Notes" — Level 0, a reading-only intro (design
/// doc, "Sayma (Counting) Giriş Dersleri", 2026-07-27): one measure of
/// straight sixteenths with "1 e & a 2 e & a..." printed under the notes
/// instead of sticking.
Map<String, dynamic> howToCountLevel() {
  const syllables = [
    '1', 'e', '&', 'a', '2', 'e', '&', 'a',
    '3', 'e', '&', 'a', '4', 'e', '&', 'a',
  ];
  Tpl tpl(String id, List<String> sticking) => Tpl(
        id,
        List.filled(16, 's'),
        sticking,
        1,
        countingLabels: syllables,
      );
  final baseA = List.generate(16, (i) => i.isEven ? 'R' : 'L');
  final baseB = List.generate(16, (i) => i.isEven ? 'L' : 'R');
  return {
    'level': 0,
    'name': 'How to Count: Sixteenth Notes',
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

/// Levels 1-3: one beat carries the new figure, the other 3 beats are
/// plain eighth-pairs. Sticking is plain sequential alternation across
/// whatever is actually struck (Skill 3's corrected model, design doc §17)
/// — these beats have different note counts (2 vs 3 vs 4 strokes), so
/// there's no shared grid to ghost through.
Tpl buildFigureTemplate(
    String id, int figureBeat, List<String> figureNotes, String startHand) {
  final rhythm = <String>[];
  final sticking = <String>[];
  var hand = startHand;
  void strike(String code) {
    rhythm.add(code);
    sticking.add(hand);
    hand = other(hand);
  }

  for (var b = 0; b < 4; b++) {
    if (b == figureBeat) {
      for (final code in figureNotes) {
        strike(code);
      }
    } else {
      strike('e');
      strike('e');
    }
  }
  return Tpl(id, rhythm, sticking, 1);
}

Map<String, dynamic> figureLevel({
  required int level,
  required String name,
  required List<String> figureNotes,
  required int minVariety,
}) {
  final templates = <Tpl>[];
  for (var beat = 0; beat < 4; beat++) {
    for (final start in ['R', 'L']) {
      templates.add(buildFigureTemplate(
          'sn${level}_${start.toLowerCase()}_b${beat + 1}',
          beat,
          figureNotes,
          start));
    }
  }
  return {
    'level': level,
    'name': name,
    'generation': {
      'strategy': 'pool_shuffle',
      'noAdjacentRepeat': true,
      'difficultyRamp': false,
      'minVariety': minVariety,
    },
    'templates': templates.map((t) => t.toJson()).toList(),
  };
}

/// Level 4: sixteenth rests. ONE beat uses a 4-slot fixed-grid figure
/// (some slots rested); [restSlots] marks which of the 4 sixteenth slots
/// in that beat are silent. Sticking is the "ghost stroke" model — the
/// hand pointer advances through EVERY slot (rested or not), only the
/// struck slots get a sticking entry — matching quarter_note_rests.json's
/// model and Vic Firth's explicit fixed-RLRL rule for sixteenth rests.
Tpl buildRestTemplate(
    String id, int figureBeat, List<bool> restSlots, String startHand) {
  final rhythm = <String>[];
  final sticking = <String>[];
  var hand = startHand;
  for (var b = 0; b < 4; b++) {
    if (b == figureBeat) {
      for (final isRest in restSlots) {
        if (isRest) {
          rhythm.add('rs');
        } else {
          rhythm.add('s');
          sticking.add(hand);
        }
        hand = other(hand); // ghost: the pointer advances regardless
      }
    } else {
      rhythm.add('e');
      sticking.add(hand);
      hand = other(hand);
      rhythm.add('e');
      sticking.add(hand);
      hand = other(hand);
    }
  }
  return Tpl(id, rhythm, sticking, 1);
}

Map<String, dynamic> restLevel() {
  // Two canonical single-rest figures (Vic Firth Lesson 4's leading and
  // trailing examples) — not the full combinatorial rest-position space,
  // matching how Skill 4 also picked specific taught figures over
  // exhaustive combinatorics.
  const figures = {
    'lead': [true, false, false, false], // rest, s, s, s (rest on "1")
    'trail': [false, false, false, true], // s, s, s, rest (rest on "a")
  };
  final templates = <Tpl>[];
  for (var beat = 0; beat < 4; beat++) {
    for (final entry in figures.entries) {
      for (final start in ['R', 'L']) {
        templates.add(buildRestTemplate(
            'sn4_${start.toLowerCase()}_b${beat + 1}_${entry.key}',
            beat,
            entry.value,
            start));
      }
    }
  }
  return {
    'level': 4,
    'name': 'Sixteenth Rests',
    'generation': {
      'strategy': 'pool_shuffle',
      'noAdjacentRepeat': true,
      'difficultyRamp': false,
      'minVariety': 6,
    },
    'templates': templates.map((t) => t.toJson()).toList(),
  };
}

Map<String, dynamic> fullStreamLevel({
  required int level,
  required String name,
  required List<Tpl> templates,
  required bool noAdjacentRepeat,
  required int minVariety,
  bool sessionFixed = false,
}) {
  return {
    'level': level,
    'name': name,
    'generation': {
      'strategy': 'pool_shuffle',
      'noAdjacentRepeat': noAdjacentRepeat,
      'difficultyRamp': false,
      'minVariety': minVariety,
      'sessionFixed': sessionFixed,
    },
    'templates': templates.map((t) => t.toJson()).toList(),
  };
}

Tpl fullStreamTpl(String id, List<String> sticking) =>
    Tpl(id, List.filled(16, 's'), sticking, 1);

void main() {
  final level1 = figureLevel(
    level: 1,
    name: 'Full Sixteenth Group',
    figureNotes: ['s', 's', 's', 's'],
    minVariety: 5,
  );

  final level2 = figureLevel(
    level: 2,
    name: 'Two Sixteenths + Eighth',
    figureNotes: ['s', 's', 'e'],
    minVariety: 5,
  );

  final level3 = figureLevel(
    level: 3,
    name: 'Eighth + Two Sixteenths',
    figureNotes: ['e', 's', 's'],
    minVariety: 5,
  );

  final level4 = restLevel();

  final baseA = List.generate(16, (i) => i.isEven ? 'R' : 'L');
  final baseB = List.generate(16, (i) => i.isEven ? 'L' : 'R');

  final level5 = fullStreamLevel(
    level: 5,
    name: 'Full Stream: Steady Alternation',
    templates: [
      fullStreamTpl('sn5_a', baseA),
      fullStreamTpl('sn5_b', baseB),
    ],
    noAdjacentRepeat: false,
    minVariety: 2,
    sessionFixed: true,
  );

  final level6 = fullStreamLevel(
    level: 6,
    name: 'Full Stream: Lead-Hand Switching',
    templates: [
      fullStreamTpl('sn6_a', baseA),
      fullStreamTpl('sn6_b', baseB),
    ],
    noAdjacentRepeat: true,
    minVariety: 2,
  );

  final doubles4 = ['RRLL', 'LLRR', 'RLLR', 'LRRL'];
  final level7 = fullStreamLevel(
    level: 7,
    name: 'Full Stream: Doubles',
    templates: [
      for (final p in doubles4)
        fullStreamTpl('sn7_${p.toLowerCase()}', (p + p + p + p).split('')),
    ],
    noAdjacentRepeat: true,
    minVariety: 3,
  );

  final skill = {
    'schemaVersion': 1,
    'skillId': 'sixteenth_notes',
    'name': 'Sixteenth Notes',
    'timeSignature': '4/4',
    'bpmDefault': 50,
    'bpmRange': [20, 100],
    'levels': [
      howToCountLevel(),
      {
        ...level1,
        // 2026-07-27: was a forced 20->55 BPM ramp (curriculumBpm); user
        // asked for free BPM control like every other level. The advice
        // behind the ramp is now just a practice tip (design doc, "Tempo
        // Müfredatı" section).
        'note': "Vary the BPM as you practice — don't skip the slow "
            "tempos, they're where timing actually gets built.",
      },
      level2,
      level3,
      level4,
      level5,
      level6,
      level7,
    ],
  };

  final out = File('content/skills/sixteenth_notes.json');
  out.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(skill));
  stdout.writeln('Wrote ${out.path}');
}
