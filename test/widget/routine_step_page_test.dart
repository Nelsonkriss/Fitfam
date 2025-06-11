import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:workout_planner/bloc/workout_session_bloc.dart';
import 'package:workout_planner/models/routine.dart';
import 'package:workout_planner/ui/routine_step_page.dart';
import 'package:workout_planner/models/part.dart';
import 'package:workout_planner/models/exercise.dart';
import 'package:workout_planner/models/main_targeted_body_part.dart';
import 'package:workout_planner/resource/db_provider_interface.dart';

class MockDbProvider implements DbProviderInterface {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('RoutineStepPage handles timed exercise correctly', (WidgetTester tester) async {
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

    // Create a mock WorkoutSessionBloc
    final workoutSessionBloc = WorkoutSessionBloc(dbProvider: MockDbProvider());

    // Build the RoutineStepPage widget
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<WorkoutSessionBloc>.value(value: workoutSessionBloc),
        ],
        child: MaterialApp(
          home: RoutineStepPage(
            routine: routine,
          ),
        ),
      ),
    );

    // Verify exercise name is displayed
    expect(find.text('Plank'), findsOneWidget);

    // Verify time is displayed with 'sec' suffix
    expect(find.text('30 sec'), findsOneWidget);

    // Verify set counter is displayed
    expect(find.text('Set 1/3'), findsOneWidget);

    // Tap the continue button
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();

    // Verify set counter increments
    expect(find.text('Set 2/3'), findsOneWidget);
  });

  testWidgets('RoutineStepPage handles regular exercise correctly', (WidgetTester tester) async {
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

    // Create a mock WorkoutSessionBloc
    final workoutSessionBloc = WorkoutSessionBloc(dbProvider: MockDbProvider());

    // Build the RoutineStepPage widget
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<WorkoutSessionBloc>.value(value: workoutSessionBloc),
        ],
        child: MaterialApp(
          home: RoutineStepPage(
            routine: routine,
          ),
        ),
      ),
    );

    // Verify exercise name is displayed
    expect(find.text('Bench Press'), findsOneWidget);

    // Verify reps are displayed without suffix
    expect(find.text('10'), findsOneWidget);

    // Verify set counter is displayed
    expect(find.text('Set 1/3'), findsOneWidget);

    // Tap the continue button
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();

    // Verify set counter increments
    expect(find.text('Set 2/3'), findsOneWidget);
  });

  testWidgets('RoutineStepPage completes workout correctly', (WidgetTester tester) async {
    // Create a timed exercise
    final exercise = Exercise(
      name: 'Plank',
      weight: 0,
      sets: 2,
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

    // Create a mock WorkoutSessionBloc
    final workoutSessionBloc = WorkoutSessionBloc(dbProvider: MockDbProvider());

    // Build the RoutineStepPage widget
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<WorkoutSessionBloc>.value(value: workoutSessionBloc),
        ],
        child: MaterialApp(
          home: RoutineStepPage(
            routine: routine,
          ),
        ),
      ),
    );

    // Complete first set
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();

    // Verify second set is shown
    expect(find.text('Set 2/2'), findsOneWidget);

    // Complete second set
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();

    // Verify workout completion
    expect(find.text('Workout Complete!'), findsOneWidget);
  });

  testWidgets('RoutineStepPage displays exercise details correctly', (WidgetTester tester) async {
    // Create an exercise with specific details
    final exercise = Exercise(
      name: 'Crunches',
      weight: 0,
      sets: 3,
      reps: '30',
      workoutType: WorkoutType.Timed,
    );

    // Create a part containing the exercise
    final part = Part(
      targetedBodyPart: TargetedBodyPart.Abs,
      setType: SetType.Regular,
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

    // Create a mock WorkoutSessionBloc
    final workoutSessionBloc = WorkoutSessionBloc(dbProvider: MockDbProvider());

    // Build the RoutineStepPage widget
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<WorkoutSessionBloc>.value(value: workoutSessionBloc),
        ],
        child: MaterialApp(
          home: RoutineStepPage(
            routine: routine,
          ),
        ),
      ),
    );

    // Verify exercise details are displayed correctly
    expect(find.text('Crunches'), findsOneWidget);
    expect(find.text('3'), findsOneWidget); // Sets
    expect(find.text('30'), findsOneWidget); // Time in seconds
    expect(find.text('Set 1/3'), findsOneWidget); // Set counter
  });

  testWidgets('RoutineStepPage handles long exercise names without overflow', (WidgetTester tester) async {
    // Create an exercise with a long name
    final exercise = Exercise(
      name: 'Very Long Exercise Name That Should Not Overflow The UI Layout',
      weight: 0,
      sets: 3,
      reps: '30',
      workoutType: WorkoutType.Timed,
    );

    // Create a part containing the exercise
    final part = Part(
      targetedBodyPart: TargetedBodyPart.Abs,
      setType: SetType.Regular,
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

    // Create a mock WorkoutSessionBloc
    final workoutSessionBloc = WorkoutSessionBloc(dbProvider: MockDbProvider());

    // Build the RoutineStepPage widget
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(400, 800)), // Simulate phone screen
          child: MultiProvider(
            providers: [
              Provider<WorkoutSessionBloc>.value(value: workoutSessionBloc),
            ],
            child: RoutineStepPage(
              routine: routine,
            ),
          ),
        ),
      ),
    );

    // Verify no overflow errors occur
    expect(tester.takeException(), isNull);
  });
}
