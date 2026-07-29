// Generates content/skills/thirty_second_notes.json (roadmap title "32nd
// Notes", design doc §9.3).
//
// Research (Vic Firth WebRhythms Lesson 13, 2026-07-27 gap-analysis
// addition): 32nd notes divide each sixteenth into two equal parts — the
// same "hand-speed doubling" step that took Eighth Notes to Sixteenth
// Notes, one tier further. Scoped deliberately small (2 levels, not
// Sixteenth Notes' 7): this is a niche, advanced topic even in most method
// books (a single lesson, not a multi-lesson unit), and the sticking
// sub-curriculum (steady alternation, lead-hand switching, doubles) was
// already exhaustively covered at the eighth- and sixteenth-note tiers —
// repeating all of it a third time just for extra hand speed adds bulk
// without teaching anything new.
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

/// [figureBeat] (0..3) marks which of the 4 beats is a full 32nd-note
/// group (8 strokes); the other 3 beats are full sixteenth-note groups (4
/// strokes each) — the already-secure "background" content, same
/// "isolate the new sound, one beat at a time" structure used throughout
/// this project.
Tpl buildFigureTemplate(String id, int figureBeat, String startHand) {
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
      for (var i = 0; i < 8; i++) {
        strike('x');
      }
    } else {
      for (var i = 0; i < 4; i++) {
        strike('s');
      }
    }
  }
  return Tpl(id, rhythm, sticking, 1);
}

void main() {
  final level1 = {
    'level': 1,
    'name': 'Full 32nd-Note Group',
    'generation': {
      'strategy': 'pool_shuffle',
      'noAdjacentRepeat': true,
      'difficultyRamp': false,
      'minVariety': 4,
      'sessionFixed': false,
    },
    'note': "Vary the BPM as you practice — don't skip the slow tempos, "
        "they're where timing actually gets built.",
    'templates': [
      for (var beat = 0; beat < 4; beat++)
        for (final start in ['R', 'L'])
          buildFigureTemplate('x1_${start.toLowerCase()}_b${beat + 1}', beat, start),
    ].map((t) => t.toJson()).toList(),
  };

  final baseA = List.generate(32, (i) => i.isEven ? 'R' : 'L');
  final baseB = List.generate(32, (i) => i.isEven ? 'L' : 'R');

  final level2 = {
    'level': 2,
    'name': 'Full Stream: Steady Alternation',
    'generation': {
      'strategy': 'pool_shuffle',
      'noAdjacentRepeat': false,
      'difficultyRamp': false,
      'minVariety': 2,
      'sessionFixed': true,
    },
    'templates': [
      Tpl('x2_a', List.filled(32, 'x'), baseA, 1).toJson(),
      Tpl('x2_b', List.filled(32, 'x'), baseB, 1).toJson(),
    ],
  };

  final skill = {
    'schemaVersion': 1,
    'skillId': 'thirty_second_notes',
    'name': '32nd Notes',
    'timeSignature': '4/4',
    'bpmDefault': 25,
    'bpmRange': [10, 50],
    'levels': [level1, level2],
  };

  final out = File('content/skills/thirty_second_notes.json');
  out.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(skill));
  stdout.writeln('Wrote ${out.path}');
}
