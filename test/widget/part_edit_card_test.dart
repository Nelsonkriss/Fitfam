import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_planner/models/routine.dart';
import 'package:workout_planner/ui/components/part_edit_card.dart';
import 'package:workout_planner/models/part.dart';
import 'package:workout_planner/models/exercise.dart';
import 'package:workout_planner/models/main_targeted_body_part.dart';

void main() {
  testWidgets('PartEditCard displays timed exercise correctly', (WidgetTester tester) async {
    // Create a timed exercise
    final exercise = Exercise(
      name: 'Plank',
      weight: 0,
      sets: 3,
      reps: '30',
      workoutType: WorkoutType.Timed,
    );

    // Create a part containing the exercise
    final part = Part(
      targetedBodyPart: TargetedBodyPart.Abs,
      setType: SetType.Super,
      exercises: [exercise],
    );

    // Create a routine containing the part
    final routine = Routine(
      routineName: 'Test Routine',
      parts: [part],
      weekdays: [1, 3, 5],
      mainTargetedBodyPart: MainTargetedBodyPart.Abs,
      createdDate: DateTime.now(),
    );

    // Build the PartEditCard widget
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PartEditCard(
            part: part,
            curRoutine: routine,
            onDelete: () {},
            onEdit: () {},
          ),
        ),
      ),
    );

    // Verify header shows "Reps/Time"
    expect(find.text('Reps/Time'), findsOneWidget);

    // Verify exercise shows time with 's' suffix
    expect(find.text('30s'), findsOneWidget);
  });

  testWidgets('PartEditCard displays regular exercise correctly', (WidgetTester tester) async {
    // Create a regular weight exercise
    final exercise = Exercise(
      name: 'Bench Press',
      weight: 100,
      sets: 3,
      reps: '10',
      workoutType: WorkoutType.Weight,
    );

    // Create a part containing the exercise
    final part = Part(
      targetedBodyPart: TargetedBodyPart.Chest,
      setType: SetType.Regular,
      exercises: [exercise],
    );

    // Create a routine containing the part
    final routine = Routine(
      routineName: 'Test Routine',
      parts: [part],
      weekdays: [1, 3, 5],
      mainTargetedBodyPart: MainTargetedBodyPart.Chest,
      createdDate: DateTime.now(),
    );

    // Build the PartEditCard widget
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PartEditCard(
            part: part,
            curRoutine: routine,
            onDelete: () {},
            onEdit: () {},
          ),
        ),
      ),
    );

    // Verify header shows "Reps/Time"
    expect(find.text('Reps/Time'), findsOneWidget);

    // Verify exercise shows reps without 's' suffix
    expect(find.text('10'), findsOneWidget);
  });
}
