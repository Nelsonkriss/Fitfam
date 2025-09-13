import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';

import 'package:workout_planner/bloc/workout_session_bloc.dart';
import 'package:workout_planner/resource/db_provider_interface.dart';
import 'package:workout_planner/models/workout_session.dart';

// Updated models
import 'package:workout_planner/models/routine.dart';
import 'package:workout_planner/models/part.dart';
import 'package:workout_planner/models/exercise.dart';
import 'package:workout_planner/models/main_targeted_body_part.dart';

// Lightweight in-memory fake implementation to avoid codegen/matchers
class FakeDbProvider implements DbProviderInterface {
  @override
  Future<void> initDB() async {}

  @override
  Future<void> addAllRoutines(List<Routine> routines) async {}

  @override
  Future<void> deleteAllRoutines() async {}

  @override
  Future<void> deleteRoutine(Routine routine) async {}

  @override
  Future<List<Routine>> getAllRecRoutines() async => [];

  @override
  Future<List<Routine>> getAllRoutines() async => [];

  @override
  Future<Routine?> getRoutineById(int id) async => null;

  @override
  Future<void> updateRoutine(Routine routine) async {}

  @override
  Future<int> newRoutine(Routine routine) async => 1;

  @override
  Future<void> saveWorkoutSession(WorkoutSession session) async {}

  @override
  Future<void> deleteWorkoutSession(String id) async {}

  @override
  Future<WorkoutSession?> getWorkoutSessionById(String id) async => null;

  @override
  Future<List<WorkoutSession>> getWorkoutSessions() async => [];
}

void main() {
  group('WorkoutSessionBloc Rest Timer Tests', () {
    late WorkoutSessionBloc bloc;
    late FakeDbProvider mockDb;

    setUp(() {
      mockDb = FakeDbProvider();
      bloc = WorkoutSessionBloc(dbProvider: mockDb);
    });

    tearDown(() {
      bloc.close();
    });

    blocTest<WorkoutSessionBloc, WorkoutSessionState>(
      'Rest timer starts correctly when set is completed',
      build: () => bloc,
      act: (bloc) {
        // Create a test routine using current models (Routine -> Part -> Exercise)
        final routine = Routine(
          routineName: 'Test Routine',
          mainTargetedBodyPart: MainTargetedBodyPart.FullBody,
          parts: [
            Part(
              setType: SetType.Regular,
              targetedBodyPart: TargetedBodyPart.FullBody,
              exercises: [
                const Exercise(
                  name: 'Test Exercise',
                  weight: 50,
                  sets: 2,
                  reps: '10',
                  workoutType: WorkoutType.Weight,
                ),
              ],
            ),
          ],
          createdDate: DateTime.now(),
        );

        // Start new session
        bloc.add(WorkoutSessionStartNew(routine));

        // Complete first set
        bloc.add(WorkoutSetMarkedComplete(
          exerciseIndex: 0,
          setIndex: 0,
          actualReps: 10,
          actualWeight: 50,
        ));
      },
      wait: const Duration(seconds: 1),
      expect: () => [
        // Initial state when session starts
        predicate<WorkoutSessionState>((state) =>
            state.session != null &&
            state.displayDuration == Duration.zero &&
            !state.isResting),
        // State after set completion - rest timer should start
        // Default planned rest is non-zero; verify isResting and duration > 0
        predicate<WorkoutSessionState>((state) =>
            state.isResting && state.displayDuration.inSeconds > 0),
      ],
    );

    blocTest<WorkoutSessionBloc, WorkoutSessionState>(
      'Rest timer counts down over time',
      build: () => bloc,
      act: (bloc) {
        final routine = Routine(
          routineName: 'Test Routine',
          mainTargetedBodyPart: MainTargetedBodyPart.FullBody,
          parts: [
            Part(
              setType: SetType.Regular,
              targetedBodyPart: TargetedBodyPart.FullBody,
              exercises: [
                const Exercise(
                  name: 'Test Exercise',
                  weight: 50,
                  sets: 2,
                  reps: '10',
                  workoutType: WorkoutType.Weight,
                ),
              ],
            ),
          ],
          createdDate: DateTime.now(),
        );

        bloc.add(WorkoutSessionStartNew(routine));
        bloc.add(WorkoutSetMarkedComplete(
          exerciseIndex: 0,
          setIndex: 0,
          actualReps: 10,
          actualWeight: 50,
        ));
      },
      wait: const Duration(seconds: 4),
      expect: () => [
        // Initial state
        predicate<WorkoutSessionState>((state) =>
            state.session != null &&
            state.displayDuration == Duration.zero &&
            !state.isResting),
        // Rest timer starts at a default duration (expected 60s)
        predicate<WorkoutSessionState>((state) =>
            state.isResting &&
            state.displayDuration.inSeconds == 60),
        // Timer counts down each second
        predicate<WorkoutSessionState>((state) =>
            state.isResting && state.displayDuration.inSeconds == 59),
        predicate<WorkoutSessionState>((state) =>
            state.isResting && state.displayDuration.inSeconds == 58),
        predicate<WorkoutSessionState>((state) =>
            state.isResting && state.displayDuration.inSeconds == 57),
      ],
    );

    blocTest<WorkoutSessionBloc, WorkoutSessionState>(
      'Rest timer cancels correctly when workout is finished',
      build: () => bloc,
      act: (bloc) {
        final routine = Routine(
          routineName: 'Test Routine',
          mainTargetedBodyPart: MainTargetedBodyPart.FullBody,
          parts: [
            Part(
              setType: SetType.Regular,
              targetedBodyPart: TargetedBodyPart.FullBody,
              exercises: [
                const Exercise(
                  name: 'Test Exercise',
                  weight: 50,
                  sets: 2,
                  reps: '10',
                  workoutType: WorkoutType.Weight,
                ),
              ],
            ),
          ],
          createdDate: DateTime.now(),
        );

        // Start session and trigger rest timer
        bloc.add(WorkoutSessionStartNew(routine));
        bloc.add(WorkoutSetMarkedComplete(
          exerciseIndex: 0,
          setIndex: 0,
          actualReps: 10,
          actualWeight: 50,
        ));

        // Wait briefly then finish workout
        Future.delayed(const Duration(seconds: 1), () {
          bloc.add(WorkoutSessionFinishAttempt());
        });
      },
      wait: const Duration(seconds: 2),
      expect: () => [
        // Initial state
        predicate<WorkoutSessionState>((state) =>
            state.session != null &&
            state.displayDuration == Duration.zero &&
            !state.isResting),
        // Rest timer starts (default expected 60s, but just check > 0)
        predicate<WorkoutSessionState>((state) =>
            state.isResting && state.displayDuration.inSeconds > 0),
        // Loading state when finishing
        predicate<WorkoutSessionState>((state) =>
            state.isLoading && !state.isResting),
      ],
    );
  });
}
