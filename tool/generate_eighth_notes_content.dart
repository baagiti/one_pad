// Generates content/skills/eighth_notes.json.
//
// Why a generator instead of hand-typing the JSON: dozens of templates
// across 7 levels, each needing correct rhythm + sticking + duplicate-free
// ids — doing that by hand invites arithmetic mistakes. This script derives
// everything mechanically so the content is provably consistent with the
// model (design doc §17). Re-run with
// `dart run tool/generate_eighth_notes_content.dart` after editing the
// parameters below; it overwrites the content file.
//
// Density levels (1-4, mixed quarter/eighth measures) use PLAIN sequential
// alternation (see buildDensityTemplate) — an earlier draft used a fixed
// 8-slot "ghost" grid (the same trick Skill 2 uses for rests), but a held
// quarter note isn't a silent placeholder the way a rest is, and that model
// produced artefacts like four same-hand hits in a row that no real
// beginner method asks for. Full-stream levels (5-7) still use the raw
// alternating/doubles bases below, since there's no "holding" involved once
// every slot is an eighth note.
import 'dart:convert';
import 'dart:io';

const baseA = ['R', 'L', 'R', 'L', 'R', 'L', 'R', 'L'];
const baseB = ['L', 'R', 'L', 'R', 'L', 'R', 'L', 'R'];

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

/// "How to Count: Eighth Notes" — Level 0, a reading-only intro (design
/// doc, "Sayma (Counting) Giriş Dersleri", 2026-07-27): one measure of
/// straight eighths with "1 & 2 & 3 & 4 &" printed under the notes instead
/// of sticking. No video needed — the app's own notation IS the lesson.
Map<String, dynamic> howToCountLevel() {
  const syllables = ['1', '&', '2', '&', '3', '&', '4', '&'];
  Tpl tpl(String id, List<String> sticking) => Tpl(
        id,
        List.filled(8, 'e'),
        sticking,
        1,
        countingLabels: syllables,
      );
  return {
    'level': 0,
    'name': 'How to Count: Eighth Notes',
    'generation': {
      'strategy': 'pool_shuffle',
      'noAdjacentRepeat': false,
      'difficultyRamp': false,
      'minVariety': 1,
      'sessionFixed': true,
    },
    'templates': [tpl('hc0_a', baseA), tpl('hc0_b', baseB)]
        .map((t) => t.toJson())
        .toList(),
  };
}

/// [beatIsEighth] has one bool per beat (4 beats); true = eighth pair
/// (two struck notes), false = quarter (one struck note).
///
/// Sticking is simple sequential alternation across whatever actually
/// gets struck — NOT the fixed 8-slot "ghost" grid used for rests
/// (design doc §17, revised 2026-07-20). A held quarter note isn't a
/// silent placeholder the way a rest is; there's nothing to "ghost", so
/// forcing one produces artefacts like four same-hand hits in a row that
/// no real beginner method asks for. Plain alternation keeps these
/// exercises testing what they're meant to test — reading *where* the
/// subdivision falls — without an unrelated sticking-endurance demand.
Tpl buildDensityTemplate(
    String id, List<bool> beatIsEighth, String startHand) {
  final rhythm = <String>[];
  final sticking = <String>[];
  var hand = startHand;
  String other(String h) => h == 'R' ? 'L' : 'R';
  for (final isEighth in beatIsEighth) {
    final strokes = isEighth ? 2 : 1;
    rhythm.addAll(List.filled(strokes, isEighth ? 'e' : 'q'));
    for (var s = 0; s < strokes; s++) {
      sticking.add(hand);
      hand = other(hand);
    }
  }
  return Tpl(id, rhythm, sticking, 1);
}

int maxRun(List<String> sticking) {
  var best = 1, cur = 1;
  for (var i = 1; i < sticking.length; i++) {
    if (sticking[i] == sticking[i - 1]) {
      cur++;
      if (cur > best) best = cur;
    } else {
      cur = 1;
    }
  }
  return best;
}

Map<String, dynamic> densityLevel({
  required int level,
  required String name,
  required List<List<int>> eighthPositions, // which beat indices are eighth
  required int minVariety,
}) {
  final templates = <Tpl>[];
  for (final positions in eighthPositions) {
    for (final start in ['R', 'L']) {
      final beatIsEighth =
          List.generate(4, (b) => positions.contains(b));
      final posLabel = positions.map((p) => p + 1).join('');
      templates.add(buildDensityTemplate(
          'en${level}_${start.toLowerCase()}_e$posLabel',
          beatIsEighth,
          start));
    }
  }
  return {
    'level': level,
    'name': name,
    'generation': {
      'strategy': 'pool_shuffle',
      'noAdjacentRepeat': true,
      // Sticking is now uniform (plain alternation, see
      // buildDensityTemplate) — nothing to ramp; the only real axis of
      // difficulty across a level is the rhythmic position itself, which
      // pool_shuffle already varies without needing a difficulty tier.
      'difficultyRamp': false,
      'minVariety': minVariety,
    },
    'templates': templates.map((t) => t.toJson()).toList(),
  };
}

Map<String, dynamic> fullStreamLevel({
  required int level,
  required String name,
  required List<Tpl> templates,
  required bool noAdjacentRepeat,
  required bool difficultyRamp,
  required int minVariety,
  bool sessionFixed = false,
}) {
  return {
    'level': level,
    'name': name,
    'generation': {
      'strategy': 'pool_shuffle',
      'noAdjacentRepeat': noAdjacentRepeat,
      'difficultyRamp': difficultyRamp,
      'minVariety': minVariety,
      'sessionFixed': sessionFixed,
    },
    'templates': templates.map((t) => t.toJson()).toList(),
  };
}

Tpl fullStreamTpl(String id, List<String> sticking) =>
    Tpl(id, List.filled(8, 'e'), sticking, maxRun(sticking));

void main() {
  // Level 1: exactly one beat is an eighth-pair (4 positions).
  final level1 = densityLevel(
    level: 1,
    name: 'One Eighth-Pair',
    eighthPositions: [
      [0],
      [1],
      [2],
      [3],
    ],
    minVariety: 5,
  );

  // Level 2: two NON-adjacent beats are eighth-pairs.
  final level2 = densityLevel(
    level: 2,
    name: 'Two Eighth-Pairs (Spread)',
    eighthPositions: [
      [0, 2],
      [0, 3],
      [1, 3],
    ],
    minVariety: 4,
  );

  // Level 3: two ADJACENT beats are eighth-pairs (4 consecutive 8th notes).
  final level3 = densityLevel(
    level: 3,
    name: 'Two Eighth-Pairs (Consecutive)',
    eighthPositions: [
      [0, 1],
      [1, 2],
      [2, 3],
    ],
    minVariety: 4,
  );

  // Level 4: three beats are eighth-pairs, one plain quarter remains.
  final level4 = densityLevel(
    level: 4,
    name: 'Three Eighth-Pairs',
    eighthPositions: [
      [1, 2, 3],
      [0, 2, 3],
      [0, 1, 3],
      [0, 1, 2],
    ],
    minVariety: 5,
  );

  // Level 5: full stream, steady alternation — ONE lead hand for the whole
  // session (sessionFixed), so it's genuinely distinct from Level 6's
  // forced per-measure switching rather than differing only by a flag that
  // barely changes the odds with a 2-template pool.
  final steadyA = fullStreamTpl('en5_a', baseA);
  final steadyB = fullStreamTpl('en5_b', baseB);
  final level5 = fullStreamLevel(
    level: 5,
    name: 'Full Stream: Steady Alternation',
    templates: [steadyA, steadyB],
    noAdjacentRepeat: false,
    difficultyRamp: false,
    minVariety: 2,
    sessionFixed: true,
  );

  // Level 6: full stream, forced lead-hand switching measure to measure.
  final level6 = fullStreamLevel(
    level: 6,
    name: 'Full Stream: Lead-Hand Switching',
    templates: [
      fullStreamTpl('en6_a', baseA),
      fullStreamTpl('en6_b', baseB),
    ],
    noAdjacentRepeat: true,
    difficultyRamp: false,
    minVariety: 2,
  );

  // Level 7: full stream, doubles (2x the 4-note doubles patterns).
  final doubles4 = ['RRLL', 'LLRR', 'RLLR', 'LRRL'];
  final level7Templates = [
    for (final p in doubles4)
      fullStreamTpl(
          'en7_${p.toLowerCase()}', (p + p).split(''))
  ];
  final level7 = fullStreamLevel(
    level: 7,
    name: 'Full Stream: Doubles',
    templates: level7Templates,
    noAdjacentRepeat: true,
    difficultyRamp: false,
    minVariety: 3,
  );

  // No Level 8. An earlier draft added a "free sticking reading" level
  // (arbitrary 8-note R/L combinations) here, mirroring Skill 1's Level 4.
  // Checked against real beginner method books (Alfred's Drum Method) and
  // course curricula (Drumeo) — none teach arbitrary sticking combinations
  // at eighth-note introduction; they use straight alternation, then
  // doubles, then move to *named* rudiments (our future dedicated
  // Rudiments skill). Removed rather than kept "for completeness" — see
  // design doc §17.

  final skill = {
    'schemaVersion': 1,
    'skillId': 'eighth_notes',
    'name': 'Eighth Notes',
    'timeSignature': '4/4',
    'bpmDefault': 60,
    'bpmRange': [30, 140],
    'levels': [
      howToCountLevel(),
      {
        ...level1,
        // 2026-07-27: was a forced 30->100 BPM ramp (curriculumBpm); user
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

  final out = File('content/skills/eighth_notes.json');
  out.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(skill));
  stdout.writeln('Wrote ${out.path}');
}
