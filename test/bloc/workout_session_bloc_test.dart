import 'package:flutter_test/flutter_test.dart';
import 'package:workout_planner/bloc/workout_session_bloc.dart';
import 'package:workout_planner/models/main_targeted_body_part.dart';
import 'package:workout_planner/models/routine.dart';
import '../helpers/fake_db_provider.dart';

Routine _buildTestRoutine() {
  return Routine(
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
}

void main() {
  group('WorkoutSessionBloc Rest Timer Tests', () {
    late WorkoutSessionBloc bloc;

    setUp(() {
      bloc = WorkoutSessionBloc(dbProvider: FakeDbProvider());
    });

    tearDown(() async {
      await bloc.close();
    });

    test('Rest timer starts correctly when set is completed', () async {
      final routine = _buildTestRoutine();
      bloc.add(WorkoutSessionStartNew(routine));
      bloc.add(
        WorkoutSetMarkedComplete(
          exerciseIndex: 0,
          setIndex: 0,
          actualReps: 10,
          actualWeight: 50,
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(bloc.state.session, isNotNull);
      expect(bloc.state.isResting, isTrue);
      expect(bloc.state.displayDuration.inSeconds, greaterThan(0));
    });

    test('Rest timer counts down over time', () async {
      final routine = _buildTestRoutine();
      bloc.add(WorkoutSessionStartNew(routine));
      bloc.add(
        WorkoutSetMarkedComplete(
          exerciseIndex: 0,
          setIndex: 0,
          actualReps: 10,
          actualWeight: 50,
        ),
      );

      await Future<void>.delayed(const Duration(seconds: 3));

      expect(bloc.state.isResting, isTrue);
      expect(bloc.state.displayDuration.inSeconds, lessThan(60));
      expect(bloc.state.displayDuration.inSeconds, greaterThan(0));
    });

    test('Rest timer cancels correctly when workout is finished', () async {
      final routine = _buildTestRoutine();
      bloc.add(WorkoutSessionStartNew(routine));
      bloc.add(
        WorkoutSetMarkedComplete(
          exerciseIndex: 0,
          setIndex: 0,
          actualReps: 10,
          actualWeight: 50,
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 600));
      bloc.add(WorkoutSessionFinishAttempt());
      await Future<void>.delayed(const Duration(milliseconds: 600));

      expect(bloc.state.isLoading, isFalse);
      expect(bloc.state.isResting, isFalse);
      expect(bloc.state.session?.isCompleted, isTrue);
    });
  });
}
