// Generates content/skills/offbeat_eighth_notes.json (roadmap title
// "Eighth Notes + Rests", design doc §18).
//
// Pedagogy (researched against Vic Firth's WebRhythms Lesson 03A): the
// eighth rest is introduced by REPLACING the first eighth of an already-
// familiar pair, producing a "rest then note" offbeat/push feel — not by
// mixing rests into plain quarters. The audibly-equivalent "note then
// rest" shape (indistinguishable from a plain quarter note) is
// deliberately omitted; it teaches notation trivia, not rhythm.
//
// Levels follow the same position-permutation methodology as Skill 2
// (rests) and Skill 3 (eighth density): level = how many of the 4 beats
// are offbeat. Unlike those two skills, adjacency does NOT get its own
// split here — see the comment on level2 below for why.
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

/// [beatIsOffbeat] has one bool per beat; true = offbeat (rest on the
/// downbeat, single note on the "and"), false = a plain eighth-note pair.
/// Sticking is plain sequential alternation across whatever actually gets
/// struck (see design doc §17's correction — no "ghost slot" grid).
Tpl buildTemplate(String id, List<bool> beatIsOffbeat, String startHand) {
  final rhythm = <String>[];
  final sticking = <String>[];
  var hand = startHand;
  String other(String h) => h == 'R' ? 'L' : 'R';
  void strike() {
    sticking.add(hand);
    hand = other(hand);
  }

  for (final offbeat in beatIsOffbeat) {
    if (offbeat) {
      rhythm..add('re')..add('e'); // rest, then the single "and" note
      strike();
    } else {
      rhythm..add('e')..add('e'); // plain eighth-note pair
      strike();
      strike();
    }
  }
  return Tpl(id, rhythm, sticking, 1);
}

Map<String, dynamic> level({
  required int levelNum,
  required String name,
  required List<List<int>> offbeatPositions,
  required int minVariety,
  bool sessionFixed = false,
}) {
  final templates = <Tpl>[];
  for (final positions in offbeatPositions) {
    for (final start in ['R', 'L']) {
      final beatIsOffbeat = List.generate(4, (b) => positions.contains(b));
      final posLabel = positions.map((p) => p + 1).join('');
      templates.add(buildTemplate(
          'ob${levelNum}_${start.toLowerCase()}_o$posLabel',
          beatIsOffbeat,
          start));
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
    name: 'One Offbeat',
    offbeatPositions: [
      [0],
      [1],
      [2],
      [3],
    ],
    minVariety: 5,
  );

  // Two offbeats: spread and consecutive positions were originally two
  // separate levels (mirroring Skill 2/3's adjacency axis), but that axis
  // doesn't transfer here — unlike a full rest or a full eighth-pair, an
  // offbeat beat is only ever "half full" (rest, then note), so two
  // adjacent offbeat beats never compound into a longer unbroken silence
  // or a longer unbroken eighth-stream the way adjacent rests/pairs did.
  // Confirmed by inspection (both arrangements land on 6 hits / 2 rests
  // in an 8-slot measure, just at different offsets) and by the user
  // being unable to tell the two levels apart in practice. Merged into
  // one level covering all 6 two-offbeat positions.
  final level2 = level(
    levelNum: 2,
    name: 'Two Offbeats',
    offbeatPositions: [
      [0, 2],
      [0, 3],
      [1, 3],
      [0, 1],
      [1, 2],
      [2, 3],
    ],
    minVariety: 6,
  );

  final level3 = level(
    levelNum: 3,
    name: 'Three Offbeats',
    offbeatPositions: [
      [1, 2, 3],
      [0, 2, 3],
      [0, 1, 3],
      [0, 1, 2],
    ],
    minVariety: 5,
  );

  // Level 4: every beat offbeat ("all and's") — one lead hand for the
  // whole session, same sessionFixed rationale as Eighth Notes Level 5
  // (design doc §17): with only 2 templates, unconstrained pool_shuffle
  // and forced switching are statistically indistinguishable.
  final level4 = level(
    levelNum: 4,
    name: 'Full Offbeat ("And" Count)',
    offbeatPositions: [
      [0, 1, 2, 3],
    ],
    minVariety: 2,
    sessionFixed: true,
  );

  final skill = {
    'schemaVersion': 1,
    'skillId': 'offbeat_eighth_notes',
    'name': 'Eighth Notes + Rests',
    'timeSignature': '4/4',
    'bpmDefault': 70,
    'bpmRange': [30, 240],
    'levels': [level1, level2, level3, level4],
  };

  final out = File('content/skills/offbeat_eighth_notes.json');
  out.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(skill));
  stdout.writeln('Wrote ${out.path}');
}
