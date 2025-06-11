import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:workout_planner/bloc/workout_session_bloc.dart';
import 'package:workout_planner/models/routine.dart';
import 'package:workout_planner/models/exercise_performance.dart';
import 'package:workout_planner/models/set_performance.dart';
import 'package:workout_planner/resource/db_provider_interface.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

@GenerateMocks([DbProviderInterface])
void main() {
  group('WorkoutSessionBloc Rest Timer Tests', () {
    late WorkoutSessionBloc bloc;
    late MockDbProviderInterface mockDb;

    setUp(() {
      mockDb = MockDbProviderInterface();
      bloc = WorkoutSessionBloc(dbProvider: mockDb);
    });

    tearDown(() {
      bloc.close();
    });

    blocTest<WorkoutSessionBloc, WorkoutSessionState>(
      'Rest timer starts correctly when set is completed',
      build: () => bloc,
      act: (bloc) {
        // Create a test routine with rest period
        final routine = Routine(
          routineName: 'Test Routine',
          exercises: [
            ExercisePerformance(
              exerciseName: 'Test Exercise',
              sets: [
                SetPerformance(targetReps: 10, targetWeight: 50),
                SetPerformance(targetReps: 10, targetWeight: 50),
              ],
              restPeriod: const Duration(seconds: 30),
            ),
          ],
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
        predicate<WorkoutSessionState>((state) =>
            state.isResting &&
            state.displayDuration == const Duration(seconds: 30)),
      ],
    );

    blocTest<WorkoutSessionBloc, WorkoutSessionState>(
      'Rest timer counts down correctly',
      build: () => bloc,
      act: (bloc) {
        final routine = Routine(
          routineName: 'Test Routine',
          exercises: [
            ExercisePerformance(
              exerciseName: 'Test Exercise',
              sets: [
                SetPerformance(targetReps: 10, targetWeight: 50),
                SetPerformance(targetReps: 10, targetWeight: 50),
              ],
              restPeriod: const Duration(seconds: 3), // Short duration for testing
            ),
          ],
        );

        bloc.add(WorkoutSessionStartNew(routine));
        bloc.add(WorkoutSetMarkedComplete(
          exerciseIndex: 0,
          setIndex: 0,
          actualReps: 10,
          actualWeight: 50,
        ));
      },
      wait: const Duration(seconds: 4), // Wait for timer to complete
      expect: () => [
        // Initial state
        predicate<WorkoutSessionState>((state) =>
            state.session != null &&
            state.displayDuration == Duration.zero &&
            !state.isResting),
        // Rest timer starts
        predicate<WorkoutSessionState>((state) =>
            state.isResting &&
            state.displayDuration == const Duration(seconds: 3)),
        // Timer counts down
        predicate<WorkoutSessionState>((state) =>
            state.isResting &&
            state.displayDuration == const Duration(seconds: 2)),
        // Timer counts down
        predicate<WorkoutSessionState>((state) =>
            state.isResting &&
            state.displayDuration == const Duration(seconds: 1)),
        // Timer counts down
        predicate<WorkoutSessionState>((state) =>
            state.isResting &&
            state.displayDuration == Duration.zero),
        // Timer ends, returns to session timer
        predicate<WorkoutSessionState>((state) =>
            !state.isResting &&
            state.displayDuration.inSeconds >= 0),
      ],
    );

    blocTest<WorkoutSessionBloc, WorkoutSessionState>(
      'Rest timer cancels correctly when workout is finished',
      build: () => bloc,
      act: (bloc) {
        final routine = Routine(
          routineName: 'Test Routine',
          exercises: [
            ExercisePerformance(
              exerciseName: 'Test Exercise',
              sets: [
                SetPerformance(targetReps: 10, targetWeight: 50),
                SetPerformance(targetReps: 10, targetWeight: 50),
              ],
              restPeriod: const Duration(seconds: 30),
            ),
          ],
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
        // Rest timer starts
        predicate<WorkoutSessionState>((state) =>
            state.isResting &&
            state.displayDuration == const Duration(seconds: 30)),
        // Loading state when finishing
        predicate<WorkoutSessionState>((state) =>
            state.isLoading && !state.isResting),
      ],
    );
  });
}
