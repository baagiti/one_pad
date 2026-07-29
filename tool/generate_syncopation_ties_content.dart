// Generates content/skills/syncopation_ties.json (roadmap title
// "Syncopation / Ties", design doc §24).
//
// Research (Vic Firth WebRhythms Lesson 10, Alfred's Drum Method Lessons
// 36 "Syncopation" / 38 "Tied Notes", Ted Reed's Progressive Steps to
// Syncopation): syncopation and ties are taught as two related but
// distinct concepts — this skill covers both, in order of complexity:
//
//   Level 1 — "Eighth + Dotted Quarter": the reverse ordering deferred
//   from Skill 5 (design doc §19) — a genuine, simpler (2-onset)
//   syncopation figure. Fits within one measure-half, no tie needed.
//
//   Level 2 — "Eighth-Quarter-Eighth": the classic syncopation figure
//   (Vic Firth's foundational example) — "the longest note on the 'and'
//   syllable of the first count." 3 onsets, still fits one measure-half,
//   still no tie needed (a plain quarter note, not dotted).
//
//   Level 3 — a genuine TIE: a note starting on the "and" of beat 2 and
//   held across beat 3 to the "and" of beat 3 (1.5 beats) CANNOT be
//   written as a single dotted note without obscuring beat 3's downbeat
//   (confirmed via research: ties are used specifically so the strong
//   beat-3 midpoint of a 4/4 measure stays visible). Written as an eighth
//   (struck, lands exactly on beat 3's "and"... — landing at the "and" of
//   beat 2) TIED TO a quarter (no new attack, spans beat 3). This is the
//   first content to use NoteToken.isTied + the notation's new tie-curve
//   render (added alongside this content, design doc §24).
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

/// Measure-half building block: 'SYNC' plays [figureCodes] (a syncopation
/// figure spanning exactly 2 beats), 'Q' is a plain two-quarter backdrop.
/// Sticking is plain sequential alternation across whatever is actually
/// struck (the model validated for Skills 3-5/7 — no "ghost slot" grid).
Tpl buildSyncopationTemplate(String id, List<String> halves,
    List<String> figureCodes, String startHand) {
  final rhythm = <String>[];
  final sticking = <String>[];
  var hand = startHand;
  void strike(String code) {
    rhythm.add(code);
    sticking.add(hand);
    hand = other(hand);
  }

  for (final half in halves) {
    if (half == 'SYNC') {
      for (final code in figureCodes) {
        strike(code);
      }
    } else {
      strike('q');
      strike('q');
    }
  }
  return Tpl(id, rhythm, sticking, 1);
}

Map<String, dynamic> syncopationLevel({
  required int levelNum,
  required String name,
  required List<String> figureCodes,
}) {
  final templates = <Tpl>[];
  for (final halves in [
    ['SYNC', 'Q'],
    ['Q', 'SYNC'],
  ]) {
    for (final start in ['R', 'L']) {
      final label = halves.join().toLowerCase();
      templates.add(buildSyncopationTemplate(
          'st${levelNum}_${start.toLowerCase()}_$label',
          halves,
          figureCodes,
          start));
    }
  }
  return {
    'level': levelNum,
    'name': name,
    'generation': {
      'strategy': 'pool_shuffle',
      'noAdjacentRepeat': true,
      'difficultyRamp': false,
      'minVariety': 2,
      'sessionFixed': false,
    },
    'templates': templates.map((t) => t.toJson()).toList(),
  };
}

/// Level 3: a real tie. Beats 1 + the first half of beat 2 are a plain
/// eighth-note backdrop (already comfortable content); the "and" of beat 2
/// is struck and held (tied) across beat 3 to the "and" of beat 3; beat 4
/// closes with a plain eighth-note pair. The tied quarter has NO sticking
/// entry and does NOT advance the hand pointer's turn (same "skip it like
/// a rest" model already used for ghost-stroke/tie-free content).
Tpl buildTieTemplate(String id, String startHand) {
  const rhythm = ['e', 'e', 'e', 'e', 'q~', 'e', 'e'];
  final sticking = <String>[];
  var hand = startHand;
  for (var i = 0; i < 4; i++) {
    sticking.add(hand);
    hand = other(hand);
  }
  // the tied quarter (rhythm[4]) gets no sticking entry.
  for (var i = 0; i < 2; i++) {
    sticking.add(hand);
    hand = other(hand);
  }
  return Tpl(id, rhythm, sticking, 1);
}

void main() {
  final level1 = syncopationLevel(
    levelNum: 1,
    name: 'Eighth + Dotted Quarter',
    figureCodes: ['e', 'q.'],
  );

  final level2 = syncopationLevel(
    levelNum: 2,
    name: 'Eighth-Quarter-Eighth',
    figureCodes: ['e', 'q', 'e'],
  );

  final level3 = {
    'level': 3,
    'name': 'Tied Across Beat 3',
    'generation': {
      'strategy': 'pool_shuffle',
      'noAdjacentRepeat': false,
      'difficultyRamp': false,
      'minVariety': 2,
      'sessionFixed': true,
    },
    'templates': [
      buildTieTemplate('st3_r', 'R'),
      buildTieTemplate('st3_l', 'L'),
    ].map((t) => t.toJson()).toList(),
  };

  final skill = {
    'schemaVersion': 1,
    'skillId': 'syncopation_ties',
    'name': 'Syncopation / Ties',
    'timeSignature': '4/4',
    'bpmDefault': 60,
    'bpmRange': [30, 140],
    'levels': [level1, level2, level3],
  };

  final out = File('content/skills/syncopation_ties.json');
  out.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(skill));
  stdout.writeln('Wrote ${out.path}');
}
