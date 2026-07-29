// Generates content/skills/paradiddle_sixteenth_notes.json (roadmap title
// "Rudiments (Sixteenth Notes)", design doc §22).
//
// Continues Skill 6's Single Paradiddle at the traditional sixteenth-note
// speed (PAS 40 rudiment order: #16 Single, #17 Double, #18 Triple, #19
// Single Paradiddle-Diddle). Architecture check done BEFORE picking the
// level list: ExerciseTemplate is always exactly one 4/4 measure.
//   - Single Paradiddle = 8 strokes = 2 beats (half a measure) — fill the
//     measure by stating it twice, same as Skill 6 Level 1/2 but at 16th
//     density instead of 8th.
//   - Triple Paradiddle = 16 strokes = 4 beats = EXACTLY one measure. This
//     is the first time it fits — at 8th-note speed (Skill 6) it needed 2
//     measures and was dropped for that reason.
//   - Double Paradiddle and Single Paradiddle-Diddle = 12 strokes = 3
//     beats each — still don't fit a 4/4 measure. Their natural home is
//     6/8 (12 sixteenths = one full 6/8 measure), i.e. the future
//     "Alternate Meters" skill (§15 item 10) — deferred again, same
//     reasoning as Skill 6's Double Paradiddle omission.
//
// Beaming note: reference engraving confirms sixteenth notes ALWAYS beam
// in groups of 4 (per beat) — even the triple paradiddle's accent (every
// 2 beats) does not widen the beam group the way it does for eighth notes
// (design doc §20/§22). NotationLayout.notesOf()'s beam-width formula was
// generalized to `4 * noteLengthInBeats` (instead of a hardcoded 2.0) to
// get this right before this content existed.
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

String other(String h) => h == 'R' ? 'L' : 'R';

/// Single Paradiddle stated twice (fills one measure at sixteenth speed):
/// lead,other,lead,lead | other,lead,other,other | lead,other,lead,lead |
/// other,lead,other,other — accent on the first stroke of each 4-note
/// group, same shape as Skill 6's buildFromGroups(['P','P'],...) but with
/// 4 groups instead of 2 (measure is twice as long in note-count terms).
Tpl buildSingleParadiddleMeasure(String id, String startHand) {
  final rhythm = <String>[];
  final sticking = <String>[];
  var hand = startHand;
  for (var g = 0; g < 4; g++) {
    final lead = hand;
    rhythm.addAll(['s>', 's', 's', 's']);
    sticking.addAll([lead, other(lead), lead, lead]);
    hand = other(lead);
  }
  return Tpl(id, rhythm, sticking, 1);
}

/// One 8-stroke Triple Paradiddle half: 6 alternating strokes then a
/// double on the lead hand (e.g. lead=R -> R,L,R,L,R,L,R,R).
List<String> tripleParadiddleHalf(String lead) {
  final s = <String>[];
  var hand = lead;
  for (var i = 0; i < 6; i++) {
    s.add(hand);
    hand = other(hand);
  }
  s.add(hand); // 7th stroke continues the alternation
  s.add(hand); // 8th stroke repeats it (the "diddle")
  return s;
}

Tpl buildTripleParadiddleMeasure(String id, String startHand) {
  final half1 = tripleParadiddleHalf(startHand);
  final half2 = tripleParadiddleHalf(other(startHand));
  final sticking = [...half1, ...half2];
  final rhythm = [
    for (var i = 0; i < 16; i++)
      (i == 0 || i == 8) ? 's>' : 's',
  ];
  return Tpl(id, rhythm, sticking, 1);
}

Map<String, dynamic> level({
  required int levelNum,
  required String name,
  required List<Tpl> templates,
  required bool sessionFixed,
}) {
  return {
    'level': levelNum,
    'name': name,
    'generation': {
      'strategy': 'pool_shuffle',
      'noAdjacentRepeat': !sessionFixed,
      'difficultyRamp': false,
      'minVariety': 2,
      'sessionFixed': sessionFixed,
    },
    'templates': templates.map((t) => t.toJson()).toList(),
  };
}

void main() {
  final level1 = level(
    levelNum: 1,
    name: 'Single Paradiddle (Fixed Lead)',
    templates: [
      buildSingleParadiddleMeasure('psn1_r', 'R'),
      buildSingleParadiddleMeasure('psn1_l', 'L'),
    ],
    sessionFixed: true,
  );

  final level2 = level(
    levelNum: 2,
    name: 'Single Paradiddle (Switching Lead)',
    templates: [
      buildSingleParadiddleMeasure('psn2_r', 'R'),
      buildSingleParadiddleMeasure('psn2_l', 'L'),
    ],
    sessionFixed: false,
  );

  final level3 = level(
    levelNum: 3,
    name: 'Triple Paradiddle',
    templates: [
      buildTripleParadiddleMeasure('psn3_r', 'R'),
      buildTripleParadiddleMeasure('psn3_l', 'L'),
    ],
    sessionFixed: true,
  );

  final skill = {
    'schemaVersion': 1,
    'skillId': 'paradiddle_sixteenth_notes',
    'name': 'Rudiments (Sixteenth Notes)',
    'timeSignature': '4/4',
    'bpmDefault': 35,
    'bpmRange': [20, 80],
    'levels': [level1, level2, level3],
  };

  final out = File('content/skills/paradiddle_sixteenth_notes.json');
  out.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(skill));
  stdout.writeln('Wrote ${out.path}');
}
