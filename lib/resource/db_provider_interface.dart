// resource/db_provider_interface.dart
import 'package:workout_planner/models/routine.dart';
import 'package:workout_planner/models/workout_session.dart';
// import 'package:sqflite/sqflite.dart'; // Only if keeping the 'db' getter

abstract class DbProviderInterface {
  // Option 1: Keep 'db' getter (Web must throw)
  // Future<Database> get db;

  // --- Common Methods ---
  Future<void> initDB();

  // Routine Methods
  Future<int> newRoutine(Routine routine);
  Future<void> updateRoutine(Routine routine);
  Future<void> deleteRoutine(Routine routine);
  Future<List<Routine>> getAllRoutines();
  Future<List<Routine>> getAllRecRoutines();
  Future<void> addAllRoutines(List<Routine> routines);
  Future<void> deleteAllRoutines();

  // Workout Session Methods
  Future<void> saveWorkoutSession(WorkoutSession session);
  Future<List<WorkoutSession>> getWorkoutSessions();
  // *** FIX: Remove the empty body {} and use a semicolon ; ***
  Future<WorkoutSession?> getWorkoutSessionById(String id);
  Future<void> deleteWorkoutSession(String id);

  // Add this method to fetch a routine by ID
  Future<Routine?> getRoutineById(int id);
}