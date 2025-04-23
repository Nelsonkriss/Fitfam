import 'package:workout_planner/models/routine.dart';
import 'package:workout_planner/models/workout_session.dart';

abstract class DbProviderInterface {
  // Routine methods
  Future<int> newRoutine(Routine routine);
  Future<void> updateRoutine(Routine routine);
  Future<void> deleteRoutine(Routine routine);
  Future<List<Routine>> getAllRoutines();
  Future<List<Routine>> getAllRecRoutines();
  Future<void> addAllRoutines(List<Routine> routines);
  Future<void> deleteAllRoutines();

  // Workout session methods
  Future<void> saveWorkoutSession(WorkoutSession session);
  Future<List<WorkoutSession>> getWorkoutSessions();
  Future<WorkoutSession?> getWorkoutSessionById(String id);
  Future<void> deleteWorkoutSession(String id);
  
  // Initialization
  Future<void> initDB();
}