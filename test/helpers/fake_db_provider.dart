import 'package:workout_planner/models/routine.dart';
import 'package:workout_planner/models/workout_session.dart';
import 'package:workout_planner/resource/db_provider_interface.dart';

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

  @override
  Future<WorkoutSession?> getLatestIncompleteSession({int? routineId}) async =>
      null;
}
