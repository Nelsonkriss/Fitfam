import 'package:flutter/foundation.dart';
import 'package:workout_planner/models/routine.dart';

// Platform-specific implementations
import 'db_provider_io.dart' if (dart.library.io) 'db_provider_io.dart';
import 'db_provider_web.dart' if (dart.library.html) 'db_provider_web.dart';

abstract class DBProvider {
  factory DBProvider() {
    if (kIsWeb) {
      return DBProviderWeb();
    } else {
      return DBProviderIO();
    }
  }

  Future<void> initDB();
  Future<int> newRoutine(Routine routine);
  Future<int> updateRoutine(Routine routine);
  Future<int> deleteRoutine(Routine routine);
  Future<int> deleteAllRoutines();
  Future<void> addAllRoutines(List<Routine> routines);
  Future<List<Routine>> getAllRoutines(); 
  Future<List<Routine>> getAllRecRoutines();
  Future<int> getLastId();
}

final dbProvider = DBProvider();
