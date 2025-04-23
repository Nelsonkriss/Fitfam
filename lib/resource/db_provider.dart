import 'package:flutter/foundation.dart';
import 'package:workout_planner/models/routine.dart';
import 'package:workout_planner/models/workout_session.dart';
import 'db_provider_interface.dart';

// Platform-specific implementations
import 'db_provider_io.dart' if (dart.library.io) 'db_provider_io.dart';
import 'db_provider_web.dart' if (dart.library.html) 'db_provider_web.dart';

abstract class DBProvider implements DbProviderInterface {
  factory DBProvider() {
    if (kIsWeb) {
      return DBProviderWeb();
    } else {
      return DBProviderIO();
    }
  }

  // Original routine methods remain unchanged
  @override
  Future<void> initDB();
  @override
  Future<int> newRoutine(Routine routine);
  @override
  Future<void> updateRoutine(Routine routine);
  @override
  Future<void> deleteRoutine(Routine routine);
  @override
  Future<List<Routine>> getAllRoutines();
  @override
  Future<List<Routine>> getAllRecRoutines();
  @override
  Future<void> addAllRoutines(List<Routine> routines);
  @override
  Future<void> deleteAllRoutines();

  // New workout session methods
  @override
  Future<void> saveWorkoutSession(WorkoutSession session);
  @override
  Future<List<WorkoutSession>> getWorkoutSessions();
  @override
  Future<WorkoutSession?> getWorkoutSessionById(String id);
  @override
  Future<void> deleteWorkoutSession(String id);
}

final dbProvider = DBProvider();
