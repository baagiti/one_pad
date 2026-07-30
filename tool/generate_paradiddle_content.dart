// Generates content/skills/paradiddle_eighth_notes.json (roadmap title
// "Rudiments (Eighth Notes)", design doc §20).
//
// Research (Alfred's Drum Method, Drumeo, Vic Firth, PAS 40 Essential
// Rudiments): the Single Paradiddle (RLRR LRLL) is the foundational
// rudiment, conventionally practiced first as an eighth-note stream before
// the traditional sixteenth-note speed (confirms roadmap ordering: this
// skill before "Sixteenth Notes"). It is genuinely new content, not a
// repeat of Skill 3 Level 7 "Doubles" — that level only covered pure
// alternation (RLRL) and pure doubles (RRLL); the paradiddle's
// single-single-double combination is a distinct shape.
//
// Multiple sources stress that the accent on the first stroke of each
// 4-note group ("para-DIDDLE") is what gives the rudiment its identity —
// "a paradiddle with no accents sounds like a mush of even notes." This is
// the first skill to use NoteToken.isAccented + the notation's new accent
// mark (added alongside this content).
//
// Architectural constraint found while first designing this (2026-07-20):
// ExerciseTemplate could then only be exactly one measure (validateAgainst
// enforced total length == timeSignature.beats). The Triple Paradiddle (16
// strokes = 2 measures) did not fit, so Level 3 instead stayed inside one
// measure by mixing a paradiddle group with a plain-alternation group
// across the two measure-halves (same "measure half" building-block method
// as Skill 5, §19).
//
// 2026-07-21 update: ExerciseTemplate/TimelineMap/NotationLayout were all
// generalized to support multi-measure templates (design doc §23), so the
// Triple Paradiddle is added back here as Level 4 — the first content to
// actually exercise that architecture.
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

/// A measure-half building block: 'P' = paradiddle group (single, single,
/// double-on-lead-hand, accent on the lead stroke), 'A' = plain alternation
/// group (four notes toggling hands, no accent).
///
/// The hand pointer threads continuously across groups so the whole
/// template reads as one natural sticking stream (plain sequential
/// alternation model, validated for Skills 3-5 — no "ghost slot" grid).
(List<String>, List<String>) buildFromGroups(
    List<String> groupTypes, String startHand) {
  final rhythm = <String>[];
  final sticking = <String>[];
  var hand = startHand;

  for (final type in groupTypes) {
    if (type == 'P') {
      final lead = hand;
      rhythm.addAll(['e>', 'e', 'e', 'e']);
      sticking.addAll([lead, other(lead), lead, lead]);
      hand = other(lead); // continues naturally from the double's hand
    } else {
      for (var i = 0; i < 4; i++) {
        rhythm.add('e');
        sticking.add(hand);
        hand = other(hand);
      }
    }
  }
  return (rhythm, sticking);
}

Tpl buildTemplate(String id, List<String> groupTypes, String startHand) {
  final (rhythm, sticking) = buildFromGroups(groupTypes, startHand);
  return Tpl(id, rhythm, sticking, 1);
}

String other(String h) => h == 'R' ? 'L' : 'R';

/// One 8-stroke Triple Paradiddle half at eighth-note speed: 6 alternating
/// strokes then a double on the lead hand (e.g. lead=R -> R,L,R,L,R,L,R,R).
List<String> tripleParadiddleHalf(String lead) {
  final s = <String>[];
  var hand = lead;
  for (var i = 0; i < 6; i++) {
    s.add(hand);
    hand = other(hand);
  }
  s.add(hand);
  s.add(hand);
  return s;
}

/// Triple Paradiddle at eighth-note speed: 16 strokes = 2 measures — the
/// first content to need a multi-measure ExerciseTemplate (design doc §23).
Tpl buildTripleParadiddle(String id, String startHand) {
  final half1 = tripleParadiddleHalf(startHand);
  final half2 = tripleParadiddleHalf(other(startHand));
  final sticking = [...half1, ...half2];
  final rhythm = [
    for (var i = 0; i < 16; i++) (i == 0 || i == 8) ? 'e>' : 'e',
  ];
  return Tpl(id, rhythm, sticking, 1);
}

Map<String, dynamic> level({
  required int levelNum,
  required String name,
  required List<List<String>> groupCombos,
  bool sessionFixed = false,
}) {
  final templates = <Tpl>[];
  for (final groups in groupCombos) {
    for (final start in ['R', 'L']) {
      final label = groups.join().toLowerCase();
      templates.add(buildTemplate(
          'pd${levelNum}_${start.toLowerCase()}_$label', groups, start));
    }
  }
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
    groupCombos: [
      ['P', 'P'],
    ],
    sessionFixed: true,
  );

  final level2 = level(
    levelNum: 2,
    name: 'Single Paradiddle (Switching Lead)',
    groupCombos: [
      ['P', 'P'],
    ],
  );

  final level3 = level(
    levelNum: 3,
    name: 'Paradiddle + Alternation Mix',
    groupCombos: [
      ['P', 'A'],
      ['A', 'P'],
    ],
  );

  // Level 4: Triple Paradiddle at eighth-note speed — 16 strokes = 2
  // measures, the first content needing a multi-measure template (§23).
  // sessionFixed for the same reason as every other 2-template level in
  // this project (Skill 3 L5, Skill 5 L3, Skill 6 L1): with only 2
  // templates, unconstrained pool_shuffle and forced alternation are
  // statistically indistinguishable.
  final level4 = {
    'level': 4,
    'name': 'Triple Paradiddle',
    'generation': {
      'strategy': 'pool_shuffle',
      'noAdjacentRepeat': false,
      'difficultyRamp': false,
      'minVariety': 2,
      'sessionFixed': true,
    },
    'templates': [
      buildTripleParadiddle('pd4_r', 'R'),
      buildTripleParadiddle('pd4_l', 'L'),
    ].map((t) => t.toJson()).toList(),
  };

  final skill = {
    'schemaVersion': 1,
    'skillId': 'paradiddle_eighth_notes',
    'name': 'Rudiments (Eighth Notes)',
    'timeSignature': '4/4',
    'bpmDefault': 60,
    'bpmRange': [30, 240],
    'levels': [level1, level2, level3, level4],
  };

  final out = File('content/skills/paradiddle_eighth_notes.json');
  out.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(skill));
  stdout.writeln('Wrote ${out.path}');
}
