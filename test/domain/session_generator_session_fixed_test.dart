import 'package:flutter_test/flutter_test.dart';
import 'package:one_pad/domain/generation/session_generator.dart';
import 'package:one_pad/domain/model/exercise.dart';
import 'package:one_pad/domain/model/note_token.dart';
import 'package:one_pad/domain/model/session.dart';
import 'package:one_pad/domain/model/skill.dart';
import 'package:one_pad/domain/model/sticking.dart';
import 'package:one_pad/domain/model/time_signature.dart';

void main() {
  ExerciseTemplate tpl(String id, List<Hand> sticking) => ExerciseTemplate(
        id: id,
        rhythm: List.filled(4, NoteToken.parse('q')),
        sticking: sticking,
        difficulty: 1,
      );

  final skill = Skill(
    id: 'test_skill',
    name: 'Test Skill',
    timeSignature: TimeSignature.fourFour,
    bpmDefault: 60,
    bpmMin: 30,
    bpmMax: 180,
    levels: [
      Level(
        level: 1,
        name: 'Session-Fixed Level',
        generation: const GenerationSpec(
          strategy: GenerationStrategy.poolShuffle,
          noAdjacentRepeat: false,
          sessionFixed: true,
        ),
        templates: [
          tpl('a', const [Hand.right, Hand.left, Hand.right, Hand.left]),
          tpl('b', const [Hand.left, Hand.right, Hand.left, Hand.right]),
        ],
      ),
    ],
  );

  test('sessionFixed repeats the SAME template across all 16 exercises', () {
    final session =
        SessionGenerator(seed: 1).generate(skill: skill, levelNumber: 1);
    final ids = session.exercises.map((e) => e.templateId).toSet();
    expect(ids, hasLength(1));
    expect(session.exercises, hasLength(Session.exerciseCount));
  });

  test('sessionFixed still varies WHICH template across different sessions',
      () {
    final chosenIds = {
      for (var seed = 0; seed < 20; seed++)
        SessionGenerator(seed: seed)
            .generate(skill: skill, levelNumber: 1)
            .exercises
            .first
            .templateId
    };
    // With 20 seeds over a 2-template pool, both should show up.
    expect(chosenIds, {'a', 'b'});
  });

  test('sessionFixed does not require noAdjacentRepeat validation (a '
      '1-template pool would otherwise throw)', () {
    final singleTemplateSkill = Skill(
      id: 's',
      name: 'S',
      timeSignature: TimeSignature.fourFour,
      bpmDefault: 60,
      bpmMin: 30,
      bpmMax: 180,
      levels: [
        Level(
          level: 1,
          name: 'L',
          generation: const GenerationSpec(
            strategy: GenerationStrategy.poolShuffle,
            sessionFixed: true,
          ),
          templates: [tpl('only', const [Hand.right, Hand.left, Hand.right, Hand.left])],
        ),
      ],
    );
    expect(
      () => SessionGenerator(seed: 0)
          .generate(skill: singleTemplateSkill, levelNumber: 1),
      returnsNormally,
    );
  });
}
