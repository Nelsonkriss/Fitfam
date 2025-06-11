// resource/db_provider_io.dart
import 'dart:async';
// import 'dart:convert'; // Not needed here if models handle JSON internally
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:collection/collection.dart'; // Keep if models use it

// Import corrected models and interface
import 'package:workout_planner/models/routine.dart'; // Assumes this handles its JSON/DB mapping
import 'package:workout_planner/models/workout_session.dart'; // Assumes handles its DB mapping (excluding exercises)
import 'package:workout_planner/models/exercise_performance.dart';
import 'package:workout_planner/models/set_performance.dart';
import 'db_provider_interface.dart';

class DBProviderIO implements DbProviderInterface {
  Database? _db;
  bool _isInitializing = false;
  final Completer<void> _initCompleter = Completer<void>();

  // --- Database Initialization ---
  Future<Database> get db async {
    if (_db != null) return _db!;
    if (_isInitializing) {
      await _initCompleter.future;
      if (_db == null) throw Exception("DB Initialization failed after waiting.");
      return _db!;
    }
    _isInitializing = true;
    try {
      _db = await _initDBInternal();
      _initCompleter.complete();
      _isInitializing = false;
      debugPrint("[DBProviderIO] Database reference obtained.");
      return _db!;
    } catch (e, s) {
      _isInitializing = false;
      if (!_initCompleter.isCompleted) {
        _initCompleter.completeError(e, s);
      }
      debugPrint("[DBProviderIO] CRITICAL: Database initialization failed: $e\n$s");
      rethrow;
    }
  }

  Future<Database> _initDBInternal() async {
    try {
      Directory documentsDirectory = await getApplicationDocumentsDirectory();
      final path = join(documentsDirectory.path, 'workout_planner_v3.db'); // Example: Increment version name if schema changed
      debugPrint("[DBProviderIO] Database path: $path");

      // Define DB version - increment this when schema changes require migration
      const int dbVersion = 3; // Incremented version for workoutType column

      return await openDatabase(path, version: dbVersion,
          onOpen: (db) async {
            await db.execute('PRAGMA foreign_keys = ON'); // Enable foreign keys
            final currentVersion = await db.getVersion();
            debugPrint("[DBProviderIO] Database opened (version $currentVersion) with foreign keys ON.");
          },
          onCreate: _onCreateDB,
          onUpgrade: _onUpgradeDB // Implement migrations here if needed
      );
    } catch (e, s) {
      debugPrint("[DBProviderIO] Error opening/creating database: $e\n$s");
      rethrow;
    }
  }

  /// Logic for creating database tables ONLY when the DB is first created.
  Future<void> _onCreateDB(Database db, int version) async {
    debugPrint("[DBProviderIO] Creating database tables (version $version)...");
    await db.execute('PRAGMA foreign_keys = ON'); // Ensure foreign keys are on

    // Routines Table
    await db.execute("CREATE TABLE Routines ("
        "id INTEGER PRIMARY KEY AUTOINCREMENT,"
        "routineName TEXT NOT NULL,"
        "mainTargetedBodyPart INTEGER," // Enum index
        "parts TEXT NOT NULL," // JSON List<Map>
        "createdDate TEXT NOT NULL," // ISO8601 String
        "lastCompletedDate TEXT," // ISO8601 String or NULL
        "completionCount INTEGER DEFAULT 0 NOT NULL,"
        "weekdays TEXT NOT NULL," // JSON List<int>
        "routineHistory TEXT NOT NULL," // JSON List<int> timestamps
        "isAiGenerated INTEGER DEFAULT 0 NOT NULL" // New column, 0 for false, 1 for true
        ")");
    debugPrint("[DBProviderIO] Created Routines table.");

    // WorkoutSessions Table (Normalized - NO exercises column)
    await db.execute("CREATE TABLE WorkoutSessions ("
        "id TEXT PRIMARY KEY," // Session UUID String
        "routineId INTEGER NOT NULL," // FK to Routines.id
        "startTime TEXT NOT NULL," // ISO8601 String
        "endTime TEXT," // ISO8601 String or NULL
        "isCompleted INTEGER DEFAULT 0 NOT NULL," // 0 = false, 1 = true
        "FOREIGN KEY (routineId) REFERENCES Routines(id) ON DELETE CASCADE"
        ")");
    debugPrint("[DBProviderIO] Created WorkoutSessions table (normalized).");

    // ExercisePerformances Table
    await db.execute("CREATE TABLE ExercisePerformances ("
        "id INTEGER PRIMARY KEY AUTOINCREMENT,"
        "sessionId TEXT NOT NULL," // FK to WorkoutSessions.id
        "exerciseName TEXT NOT NULL,"
        "workoutType TEXT NOT NULL," // Enum as string (Weight, Cardio, Timed)
        "restPeriod INTEGER," // Duration in seconds or NULL
        "FOREIGN KEY (sessionId) REFERENCES WorkoutSessions(id) ON DELETE CASCADE"
        ")");
    debugPrint("[DBProviderIO] Created ExercisePerformances table.");

    // SetPerformances Table
    await db.execute("CREATE TABLE SetPerformances ("
        "id INTEGER PRIMARY KEY AUTOINCREMENT,"
        "exerciseId INTEGER NOT NULL," // FK to ExercisePerformances.id
        "targetReps INTEGER DEFAULT 0 NOT NULL,"
        "targetWeight REAL DEFAULT 0 NOT NULL,"
        "actualReps INTEGER DEFAULT 0 NOT NULL,"
        "actualWeight REAL DEFAULT 0 NOT NULL,"
        "isCompleted INTEGER DEFAULT 0 NOT NULL," // 0 or 1
        "FOREIGN KEY (exerciseId) REFERENCES ExercisePerformances(id) ON DELETE CASCADE"
        ")");
    debugPrint("[DBProviderIO] Created SetPerformances table.");
    debugPrint("[DBProviderIO] Database tables created successfully.");
  }

  /// Logic for handling database upgrades (schema changes) when version increases.
  Future<void> _onUpgradeDB(Database db, int oldVersion, int newVersion) async {
    debugPrint("[DBProviderIO] Upgrading database from $oldVersion to $newVersion...");
    if (oldVersion < 2) {
      await db.execute("ALTER TABLE Routines ADD COLUMN isAiGenerated INTEGER DEFAULT 0 NOT NULL;");
      debugPrint("[DBProviderIO] Added 'isAiGenerated' column to Routines table.");
    }
    if (oldVersion < 3) {
      await db.execute("ALTER TABLE ExercisePerformances ADD COLUMN workoutType TEXT NOT NULL DEFAULT 'Weight';");
      debugPrint("[DBProviderIO] Added 'workoutType' column to ExercisePerformances table.");
    }
  }

  @override
  Future<void> initDB() async {
    await db; // Access getter to ensure initialization completes
    debugPrint("[DBProviderIO] initDB() complete.");
  }

  // --- Routine Methods ---
  // (Implementations for newRoutine, updateRoutine, deleteRoutine, getAllRoutines, etc.)
  // These rely on Routine.toMapForDb() and Routine.fromMap() correctly handling
  // JSON encoding/decoding for list fields (parts, weekdays, routineHistory)
  // and correct type mapping (enum index, dates as strings).

  @override
  Future<int> newRoutine(Routine routine) async {
    final dbClient = await db;
    final map = routine.toMapForDb();
    map.remove('id'); // Let DB handle auto-increment
    try {
      int id = await dbClient.insert('Routines', map, conflictAlgorithm: ConflictAlgorithm.replace);
      debugPrint("[DBProviderIO] Inserted Routine with ID: $id");
      return id;
    } catch (e, s) { debugPrint("[DBProviderIO] Error inserting new routine: $e\n$s\nMap: $map"); rethrow; }
  }

  @override
  Future<void> updateRoutine(Routine routine) async {
    if (routine.id == null) { debugPrint("[DBProviderIO] Cannot update routine without ID."); return; }
    final dbClient = await db;
    final map = routine.toMapForDb(); // Assumes map includes ID for update context if needed by model
    try {
      int count = await dbClient.update('Routines', map, where: 'id = ?', whereArgs: [routine.id]);
      debugPrint("[DBProviderIO] Updated $count Routine(s) with ID: ${routine.id}");
      if (count == 0) { debugPrint("[DBProviderIO] Warning: Routine ${routine.id} not found for update."); }
    } catch (e, s) { debugPrint("[DBProviderIO] Error updating routine ${routine.id}: $e\n$s\nMap: $map"); rethrow; }
  }

  @override
  Future<void> deleteRoutine(Routine routine) async {
    if (routine.id == null) { debugPrint("[DBProviderIO] Cannot delete routine without ID."); return; }
    final dbClient = await db;
    try {
      int count = await dbClient.delete('Routines', where: 'id = ?', whereArgs: [routine.id]);
      debugPrint("[DBProviderIO] Deleted $count routine(s) with ID: ${routine.id}.");
    } catch (e, s) { debugPrint("[DBProviderIO] Error deleting routine ${routine.id}: $e\n$s"); rethrow; }
  }

  @override
  Future<List<Routine>> getAllRoutines() async {
    final dbClient = await db;
    try {
      final List<Map<String, dynamic>> maps = await dbClient.query('Routines', orderBy: 'routineName ASC');
      final routines = maps.map((map) {
        try { return Routine.fromMap(map); } // Relies on robust Routine.fromMap
        catch (e, s) { debugPrint("[DBProviderIO] Error parsing routine map: $e\n$s\nMap: $map"); return null; }
      }).whereNotNull().toList();
      debugPrint("[DBProviderIO] Fetched ${routines.length} routines.");
      return routines;
    } catch (e, s) { debugPrint("[DBProviderIO] Error getting all routines: $e\n$s"); return []; }
  }

  @override
  Future<Routine?> getRoutineById(int id) async {
    final dbClient = await db;
    try {
      final List<Map<String, dynamic>> maps = await dbClient.query('Routines', where: 'id = ?', whereArgs: [id], limit: 1);
      if (maps.isEmpty) return null;
      return Routine.fromMap(maps.first); // Relies on robust Routine.fromMap
    } catch (e, s) { debugPrint("[DBProviderIO] Error getting routine by ID $id: $e\n$s"); return null; }
  }

  // --- Workout Session Methods (Normalized) ---

  @override
  Future<void> saveWorkoutSession(WorkoutSession session) async {
    final dbClient = await db;
    try {
      await dbClient.transaction((txn) async {
        // 1. Save main session record (uses session.toMapForDb which EXCLUDES exercises)
        final sessionMap = session.toMapForDb();
        await txn.insert('WorkoutSessions', sessionMap, conflictAlgorithm: ConflictAlgorithm.replace);
        debugPrint("[DBProviderIO] Saved WorkoutSession main record ID: ${session.id}");

        // 2. Delete existing children for this session ID to handle updates correctly
        await txn.delete('ExercisePerformances', where: 'sessionId = ?', whereArgs: [session.id]);
        // Cascade delete should handle SetPerformances linked to the deleted ExercisePerformances

        // 3. Insert new exercises and their sets
        for (final exercise in session.exercises) {
          final exerciseMap = {
            'sessionId': session.id, // Link to parent session
            'exerciseName': exercise.exerciseName,
            'workoutType': exercise.workoutType.name, // Store enum as string
            'restPeriod': exercise.restPeriod?.inSeconds,
          };
          // Insert exercise and get its new DB ID
          final exerciseId = await txn.insert('ExercisePerformances', exerciseMap);

          // 4. Insert sets for this exercise
          for (final setPerf in exercise.sets) {
            final setMap = {
              'exerciseId': exerciseId, // Link to parent exercise
              'targetReps': setPerf.targetReps,
              'targetWeight': setPerf.targetWeight,
              'actualReps': setPerf.actualReps,
              'actualWeight': setPerf.actualWeight,
              'isCompleted': setPerf.isCompleted ? 1 : 0,
            };
            await txn.insert('SetPerformances', setMap);
          }
          debugPrint("[DBProviderIO] Saved ${exercise.sets.length} SetPerformances for ExercisePerformance ID: $exerciseId");
        }
      });
      debugPrint("[DBProviderIO] Successfully saved/updated WorkoutSession ID: ${session.id} and its children via transaction.");
    } catch (e, s) {
      debugPrint("[DBProviderIO] Error saving workout session ${session.id} transaction: $e\n$s");
      rethrow; // Rethrow to be caught by BLoC
    }
  }

  @override
  Future<List<WorkoutSession>> getWorkoutSessions() async {
    final dbClient = await db;
    try {
      // 1. Get all base session records
      final List<Map<String, dynamic>> sessionMaps = await dbClient.query('WorkoutSessions', orderBy: 'startTime DESC');
      final List<WorkoutSession> sessions = [];

      // 2. For each session, fetch its routine and then its exercises/sets
      for (var sessionMap in sessionMaps) {
        final routineId = sessionMap['routineId'] as int;
        final routine = await getRoutineById(routineId);
        if (routine == null) {
          debugPrint("[DBProviderIO] Warning: Skipping session ${sessionMap['id']} because Routine $routineId not found.");
          continue;
        }

        // Create the base session object (initializes exercises = [])
        final session = WorkoutSession.fromMap(sessionMap, routine);

        // 3. Fetch exercises linked to this session
        final exerciseMaps = await dbClient.query('ExercisePerformances', where: 'sessionId = ?', whereArgs: [session.id], orderBy: 'id ASC');
        final List<ExercisePerformance> exercisesForThisSession = [];

        for (var exerciseMap in exerciseMaps) {
          final exerciseId = exerciseMap['id'] as int;

          // 4. Fetch sets linked to this exercise
          final setMaps = await dbClient.query('SetPerformances', where: 'exerciseId = ?', whereArgs: [exerciseId], orderBy: 'id ASC');
          final List<SetPerformance> setsForThisExercise = setMaps.map((setMap) {
            try {
              return SetPerformance(
                targetReps: setMap['targetReps'] as int? ?? 0,
                targetWeight: (setMap['targetWeight'] as num?)?.toDouble() ?? 0.0,
                actualReps: setMap['actualReps'] as int? ?? 0,
                actualWeight: (setMap['actualWeight'] as num?)?.toDouble() ?? 0.0,
                isCompleted: (setMap['isCompleted'] as int? ?? 0) == 1,
              );
            } catch(e,s) { debugPrint("[DBProviderIO] Error parsing set map for exercise $exerciseId: $e\n$s\nMap: $setMap"); return null; }
          }).whereNotNull().toList();

          // 5. Create the ExercisePerformance object WITH its sets
          try {
            final exercisePerformance = ExercisePerformance(
              id: exerciseId, // Pass the DB ID
              exerciseName: exerciseMap['exerciseName'] as String? ?? 'Unknown Exercise',
              sets: setsForThisExercise, // Assign the fetched sets
              restPeriod: exerciseMap['restPeriod'] != null ? Duration(seconds: exerciseMap['restPeriod'] as int) : null,
              workoutType: WorkoutType.values.firstWhere(
                (e) => e.name == (exerciseMap['workoutType'] as String? ?? 'Weight'),
                orElse: () => WorkoutType.Weight,
              ),
            );
            exercisesForThisSession.add(exercisePerformance);
          } catch (e,s) { debugPrint("[DBProviderIO] Error creating ExercisePerformance object for exercise $exerciseId: $e\n$s"); }
        } // End exercise loop

        // 6. Add the populated list of exercises to the session object
        // We need a way to update the immutable session object. Using copyWith:
        sessions.add(session.copyWith(exercises: exercisesForThisSession));

      } // End session loop

      debugPrint("[DBProviderIO] Fetched ${sessions.length} workout sessions with details.");
      return sessions;
    } catch (e, s) {
      debugPrint("[DBProviderIO] Error getting workout sessions: $e\n$s");
      return [];
    }
  }

  @override
  Future<WorkoutSession?> getWorkoutSessionById(String id) async {
    final dbClient = await db;
    try {
      // 1. Get the specific session record
      final List<Map<String, dynamic>> sessionMaps = await dbClient.query('WorkoutSessions', where: 'id = ?', whereArgs: [id], limit: 1);
      if (sessionMaps.isEmpty) { debugPrint("[DBProviderIO] Session ID $id not found."); return null; }
      final sessionMap = sessionMaps.first;

      // 2. Fetch associated Routine
      final routineId = sessionMap['routineId'] as int;
      final routine = await getRoutineById(routineId);
      if (routine == null) { debugPrint("[DBProviderIO] Routine $routineId for session $id not found."); return null; }

      // 3. Create base session object (exercises = [])
      final session = WorkoutSession.fromMap(sessionMap, routine);

      // 4. Fetch exercises and sets (similar logic to getWorkoutSessions loop)
      final exerciseMaps = await dbClient.query('ExercisePerformances', where: 'sessionId = ?', whereArgs: [session.id], orderBy: 'id ASC');
      final List<ExercisePerformance> exercisesForThisSession = [];
      for (var exerciseMap in exerciseMaps) {
        final exerciseId = exerciseMap['id'] as int;
        final setMaps = await dbClient.query('SetPerformances', where: 'exerciseId = ?', whereArgs: [exerciseId], orderBy: 'id ASC');
        final List<SetPerformance> setsForThisExercise = setMaps.map((setMap) => /* ... SetPerformance from setMap ... */ SetPerformance(targetReps: setMap['targetReps'] as int? ?? 0, targetWeight: (setMap['targetWeight'] as num?)?.toDouble() ?? 0.0, actualReps: setMap['actualReps'] as int? ?? 0, actualWeight: (setMap['actualWeight'] as num?)?.toDouble() ?? 0.0, isCompleted: (setMap['isCompleted'] as int? ?? 0) == 1)).toList(); // Simplified for brevity
        final exercisePerformance = ExercisePerformance(
          id: exerciseId,
          exerciseName: exerciseMap['exerciseName'] as String? ?? '',
          sets: setsForThisExercise,
          restPeriod: exerciseMap['restPeriod'] != null ? Duration(seconds: exerciseMap['restPeriod'] as int): null,
          workoutType: WorkoutType.values.firstWhere(
            (e) => e.name == (exerciseMap['workoutType'] as String? ?? 'Weight'),
            orElse: () => WorkoutType.Weight,
          ),
        );
        exercisesForThisSession.add(exercisePerformance);
      }

      // 5. Return the session with populated exercises
      return session.copyWith(exercises: exercisesForThisSession);

    } catch (e, s) {
      debugPrint("[DBProviderIO] Error getting session by ID $id: $e\n$s");
      return null;
    }
  }

  @override
  Future<void> deleteWorkoutSession(String id) async {
    final dbClient = await db;
    try {
      int count = await dbClient.delete('WorkoutSessions', where: 'id = ?', whereArgs: [id]);
      debugPrint("[DBProviderIO] Deleted $count session(s) with ID: $id. Cascade should handle children.");
    } catch (e, s) { debugPrint("[DBProviderIO] Error deleting session $id: $e\n$s"); rethrow; }
  }

  // --- Add other DB methods as needed (deleteAllRoutines, addAllRoutines etc) ---
  @override
  Future<List<Routine>> getAllRecRoutines() async { return []; } // Placeholder

  @override
  Future<void> addAllRoutines(List<Routine> routines) async { /* ... Batch insert ... */ }

  @override
  Future<void> deleteAllRoutines() async { /* ... Delete all routines ... */ }

} // End DBProviderIO