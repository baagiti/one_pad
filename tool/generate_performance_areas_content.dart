// Generates the 4 performance_*.json files (roadmap title "Performance:
// <cluster>", design doc §29).
//
// Research (Alfred's Drum Method "solo" pages — RECENT, related lessons
// combined at the end of a section, never the whole book at once) plus the
// user's own instinct ("16 skills is too many to mix all at once — group
// them 2-3 at a time"): Performance Areas is split into small, thematic
// clusters instead of one giant mixed pool.
//
// Architecture: NO new domain code needed. ExerciseTemplate doesn't know
// or care which skill it came from — a "Performance Area" is just a Skill
// whose ONE level's template pool is the UNION of a few already-generated,
// already-validated skills' templates (all pulled from skills sharing the
// same time signature — Session/TimelineMap/NotationLayout all assume one
// timeSignature per session, so meter skills (3/4, 6/8, 5/4, 7/8) stay
// standalone, never mixed into a Performance Area, design doc §29).
import 'dart:convert';
import 'dart:io';

Map<String, dynamic> loadSkillJson(String skillFile) =>
    json.decode(File('content/skills/$skillFile.json').readAsStringSync())
        as Map<String, dynamic>;

/// Every template from every level of [skillFiles], pooled into one list.
/// Template ids are already globally unique per-skill (each generator
/// script prefixes its own ids), so no rewriting is needed. Level 0 ("How
/// to Count" reading intros, 2026-07-27) is deliberately excluded — its
/// templates are trivial repetitive-reading content, not real practice
/// material, and would dilute a Performance Area's capstone pool.
List<Map<String, dynamic>> pooledTemplates(List<String> skillFiles) {
  final templates = <Map<String, dynamic>>[];
  for (final file in skillFiles) {
    final skill = loadSkillJson(file);
    for (final level in (skill['levels'] as List).cast<Map<String, dynamic>>()) {
      if (level['level'] == 0) continue;
      templates.addAll((level['templates'] as List).cast<Map<String, dynamic>>());
    }
  }
  return templates;
}

Map<String, dynamic> performanceArea({
  required String skillId,
  required String name,
  required List<String> skillFiles,
  required int bpmDefault,
  required List<int> bpmRange,
}) {
  return {
    'schemaVersion': 1,
    'skillId': skillId,
    'name': name,
    'timeSignature': '4/4',
    'bpmDefault': bpmDefault,
    'bpmRange': bpmRange,
    'levels': [
      {
        'level': 1,
        'name': name,
        'generation': {
          'strategy': 'pool_shuffle',
          'noAdjacentRepeat': true,
          'difficultyRamp': false,
          'minVariety': 10,
          'sessionFixed': false,
        },
        'templates': pooledTemplates(skillFiles),
      },
    ],
  };
}

void main() {
  final areas = [
    (
      performanceArea(
        skillId: 'performance_foundations',
        name: 'Performance: Foundations',
        skillFiles: [
          'quarter_note_pulse',
          'quarter_note_rests',
          'eighth_notes',
        ],
        bpmDefault: 60,
        bpmRange: [30, 140],
      ),
      'performance_foundations.json',
    ),
    (
      performanceArea(
        skillId: 'performance_syncopated_feel',
        name: 'Performance: Syncopated Feel',
        skillFiles: [
          'offbeat_eighth_notes',
          'dotted_quarter_eighth',
          'syncopation_ties',
        ],
        bpmDefault: 60,
        bpmRange: [30, 140],
      ),
      'performance_syncopated_feel.json',
    ),
    (
      performanceArea(
        skillId: 'performance_fast_subdivision',
        name: 'Performance: Fast Subdivision',
        skillFiles: [
          'sixteenth_notes',
          'triplets',
          // 2026-07-27: added alongside its own new skill (32nd Notes) —
          // same hand-speed-tier family as sixteenth notes/triplets, same
          // 4/4 time signature. bpmRange narrows to the 3-way intersection
          // ([20,100] ∩ [30,140] ∩ [10,50]); default drops to match.
          'thirty_second_notes',
        ],
        bpmDefault: 30,
        bpmRange: [30, 50],
      ),
      'performance_fast_subdivision.json',
    ),
    (
      performanceArea(
        skillId: 'performance_rudiment_workout',
        name: 'Performance: Rudiment Workout',
        skillFiles: [
          'paradiddle_eighth_notes',
          'paradiddle_sixteenth_notes',
          'roll_rudiments',
        ],
        bpmDefault: 35,
        bpmRange: [30, 80],
      ),
      'performance_rudiment_workout.json',
    ),
  ];

  for (final (skill, filename) in areas) {
    final out = File('content/skills/$filename');
    out.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(skill));
    stdout.writeln(
        'Wrote ${out.path} (${(skill['levels'] as List).first['templates'].length} templates)');
  }
}
