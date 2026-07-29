// Generates content/skills/roll_rudiments.json (roadmap title "Rudiments:
// Roll Family", design doc §28) — added after the user asked "aren't
// there more complex rudiments?" following Skill 12 (Triplets).
//
// Research (PAS 40 International Drum Rudiments, "Double Stroke Open Roll
// Rudiments" family): the 5/7/9-Stroke Rolls are the standard "Tier 2"
// rudiments taught right after Single/Double Stroke Roll — each is N-1
// double strokes followed by one ACCENTED single stroke that continues
// the natural alternation (e.g. 5-Stroke = RRLLR). Genuinely a timing
// skill (every stroke, including doubles, has its own distinct onset —
// unlike a flam's grace note, which has no rhythmic value of its own,
// design doc §27) — uses NO new architecture: the accent notation (§20)
// and measure-half building-block method (§19/§24/§27) already cover it.
//
// Duration construction (confirmed against standard notation): each roll
// is built from sixteenth-note doubles/singles, with the FINAL accented
// stroke lengthened to fill out a clean 2-beat half (or, for the 9-stroke
// roll, a full 4-beat measure) — e.g. 5-Stroke = 4 sixteenths (1 beat) +
// 1 accented QUARTER (1 beat) = 2 beats, mirrored for the second half.
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

Map<String, dynamic> level({
  required int levelNum,
  required String name,
  required List<Tpl> templates,
}) {
  return {
    'level': levelNum,
    'name': name,
    'generation': {
      'strategy': 'pool_shuffle',
      'noAdjacentRepeat': false,
      'difficultyRamp': false,
      'minVariety': 2,
      'sessionFixed': true,
    },
    'templates': templates.map((t) => t.toJson()).toList(),
  };
}

/// Double Stroke Roll (PAS rudiment #6): a full measure of sustained open
/// doubles — "RRLLRRLL..." — with NO accent, unlike the 5/7/9-Stroke Rolls
/// below. The building block those rolls are made of, but never taught on
/// its own in this curriculum until now (2026-07-27 gap-analysis addition,
/// added as Level 1 — real method books teach it before 5-Stroke Roll).
/// 16 sixteenths fill exactly one measure, mirroring Skill 7's full-group
/// pattern.
Tpl buildDoubleStrokeRoll(String id, String startHand) {
  final rhythm = <String>[];
  final sticking = <String>[];
  var hand = startHand;
  for (var i = 0; i < 8; i++) {
    sticking.addAll([hand, hand]);
    rhythm.addAll(['s', 's']);
    hand = other(hand);
  }
  return Tpl(id, rhythm, sticking, 1);
}

/// One roll half: [doubles] pairs of doubled strokes, then one accented
/// single that continues the alternation (e.g. RR,LL then R -> RRLLR).
(List<String>, List<String>) rollHalf(
    String lead, int doubleCount, String accentedDuration) {
  final sticking = <String>[];
  final rhythm = <String>[];
  var hand = lead;
  for (var i = 0; i < doubleCount; i++) {
    sticking.addAll([hand, hand]);
    rhythm.addAll(['s', 's']);
    hand = other(hand);
  }
  sticking.add(hand);
  rhythm.add('$accentedDuration>');
  return (rhythm, sticking);
}

/// Builds a roll that fills exactly one measure-half (2 beats): mirrored
/// so the second half starts with the opposite lead, matching every other
/// paradiddle-family template in this project (§19/§20/§25).
Tpl buildHalfRoll(
    String id, String startHand, int doubleCount, String accentedDuration) {
  final (rhythm1, sticking1) = rollHalf(startHand, doubleCount, accentedDuration);
  final (rhythm2, sticking2) =
      rollHalf(other(startHand), doubleCount, accentedDuration);
  return Tpl(id, [...rhythm1, ...rhythm2], [...sticking1, ...sticking2], 1);
}

/// The 9-Stroke Roll fills a whole measure by itself (4 doubles + 1
/// accented half note = 4 beats) — no mirrored second half needed.
Tpl buildNineStrokeRoll(String id, String startHand) {
  final (rhythm, sticking) = rollHalf(startHand, 4, 'h');
  return Tpl(id, rhythm, sticking, 1);
}

void main() {
  final level1 = level(
    levelNum: 1,
    name: 'Double Stroke Roll',
    templates: [
      buildDoubleStrokeRoll('rr0_r', 'R'),
      buildDoubleStrokeRoll('rr0_l', 'L'),
    ],
  );

  final level2 = level(
    levelNum: 2,
    name: '5-Stroke Roll',
    templates: [
      buildHalfRoll('rr1_r', 'R', 2, 'q'),
      buildHalfRoll('rr1_l', 'L', 2, 'q'),
    ],
  );

  final level3 = level(
    levelNum: 3,
    name: '7-Stroke Roll',
    templates: [
      buildHalfRoll('rr2_r', 'R', 3, 'e'),
      buildHalfRoll('rr2_l', 'L', 3, 'e'),
    ],
  );

  final level4 = level(
    levelNum: 4,
    name: '9-Stroke Roll',
    templates: [
      buildNineStrokeRoll('rr3_r', 'R'),
      buildNineStrokeRoll('rr3_l', 'L'),
    ],
  );

  final skill = {
    'schemaVersion': 1,
    'skillId': 'roll_rudiments',
    'name': 'Rudiments: Roll Family',
    'timeSignature': '4/4',
    'bpmDefault': 60,
    'bpmRange': [30, 120],
    'levels': [level1, level2, level3, level4],
  };

  final out = File('content/skills/roll_rudiments.json');
  out.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(skill));
  stdout.writeln('Wrote ${out.path}');
}
