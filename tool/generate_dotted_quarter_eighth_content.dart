// Generates content/skills/dotted_quarter_eighth.json (roadmap title
// "Dotted Quarter + Eighth", design doc §19).
//
// Replaces the originally-planned "Quarter & Eighth Combinations" item —
// research (Alfred's Drum Method Lesson 6, following eighth notes/rests)
// showed that combination was already fully covered by Skill 3's density
// levels. The real next step in real method books is the dotted
// quarter+eighth rhythm: widely documented as one of the hardest rhythms
// for beginners, since the first note is held through the "and" of beat 1
// into beat 2 — a 1.5-beat gap before the next onset, longer than anything
// in Skills 1-4.
//
// The dotted-quarter+eighth pair (D) spans exactly 2 beats — half a 4/4
// measure — so the natural building block here is a measure HALF, not a
// single beat like Skills 2-4. Each half is one of:
//   Q = two plain quarters (simplest backdrop)
//   E = four eighth notes (busier backdrop, Skill 3 territory)
//   D = dotted quarter + eighth (the new element)
import 'dart:convert';
import 'dart:io';

class Tpl {
  final String id;
  final List<String> rhythm;
  final List<String> sticking;
  final int difficulty;
  Tpl(this.id, this.rhythm, this.sticking, this.difficulty);
  Map<String, dynamic> toJson() => {
        'id': id,
        'rhythm': rhythm,
        'sticking': sticking,
        'difficulty': difficulty,
      };
}

/// [halves] has exactly 2 entries, each 'Q', 'E', or 'D'. Sticking is
/// plain sequential alternation across whatever actually gets struck
/// (the model validated for Skills 3-4 — no "ghost slot" grid).
Tpl buildTemplate(String id, List<String> halves, String startHand) {
  final rhythm = <String>[];
  final sticking = <String>[];
  var hand = startHand;
  String other(String h) => h == 'R' ? 'L' : 'R';
  void strike() {
    sticking.add(hand);
    hand = other(hand);
  }

  for (final half in halves) {
    switch (half) {
      case 'Q':
        rhythm..add('q')..add('q');
        strike();
        strike();
      case 'E':
        rhythm..add('e')..add('e')..add('e')..add('e');
        strike();
        strike();
        strike();
        strike();
      case 'D':
        rhythm..add('q.')..add('e'); // dotted quarter, then the "and" eighth
        strike();
        strike();
    }
  }
  return Tpl(id, rhythm, sticking, 1);
}

Map<String, dynamic> level({
  required int levelNum,
  required String name,
  required List<List<String>> halfCombos,
  required int minVariety,
  bool sessionFixed = false,
}) {
  final templates = <Tpl>[];
  for (final halves in halfCombos) {
    for (final start in ['R', 'L']) {
      final label = halves.join().toLowerCase();
      templates.add(buildTemplate(
          'dq${levelNum}_${start.toLowerCase()}_$label', halves, start));
    }
  }
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

void main() {
  final level1 = level(
    levelNum: 1,
    name: 'Dotted Quarter Against Quarters',
    halfCombos: [
      ['D', 'Q'],
      ['Q', 'D'],
    ],
    minVariety: 2,
  );

  final level2 = level(
    levelNum: 2,
    name: 'Dotted Quarter Against Eighths',
    halfCombos: [
      ['D', 'E'],
      ['E', 'D'],
    ],
    minVariety: 2,
  );

  final level3 = level(
    levelNum: 3,
    name: 'Full Dotted Quarter',
    halfCombos: [
      ['D', 'D'],
    ],
    minVariety: 2,
    sessionFixed: true,
  );

  final skill = {
    'schemaVersion': 1,
    'skillId': 'dotted_quarter_eighth',
    'name': 'Dotted Quarter + Eighth',
    'timeSignature': '4/4',
    'bpmDefault': 60,
    'bpmRange': [30, 240],
    'levels': [level1, level2, level3],
  };

  final out = File('content/skills/dotted_quarter_eighth.json');
  out.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(skill));
  stdout.writeln('Wrote ${out.path}');
}
