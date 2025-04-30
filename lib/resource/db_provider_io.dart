// resource/db_provider_io.dart
import 'dart:async';
import 'dart:convert'; // Keep for debugging, though model should handle encoding/decoding
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:collection/collection.dart'; // Keep if needed by models

// Import corrected models and interface
import 'package:workout_planner/models/routine.dart'; // Assumes this handles JSON correctly
import 'package:workout_planner/models/workout_session.dart'; // ** ACTION REQUIRED: Ensure this handles JSON for 'exercises' list **
import 'db_provider_interface.dart';

class DBProviderIO implements DbProviderInterface {
  Database? _db;
  bool _isInitializing = false;
  final Completer<void> _initCompleter = Completer<void>();

  // --- Database Initialization ---
  Future<Database> get db async {
    if (_db != null) return _db!;
    if (_isInitializing) { await _initCompleter.future; return _db!; }
    _isInitializing = true;
    try {
      _db = await _initDBInternal();
      _initCompleter.complete();
      _isInitializing = false;
      debugPrint("[DBProviderIO] Database reference obtained.");
      return _db!;
    } catch (e,s) {
      _isInitializing = false;
      _initCompleter.completeError(e, s); // Complete with error and stacktrace
      debugPrint("[DBProviderIO] CRITICAL: Database initialization failed: $e\n$s");
      rethrow;
    }
  }

  Future<Database> _initDBInternal() async {
    try {
      Directory documentsDirectory = await getApplicationDocumentsDirectory();
      final path = join(documentsDirectory.path, 'workout_planner_v2.db'); // Incremented version name example
      debugPrint("[DBProviderIO] Database path: $path");

      return await openDatabase(path, version: 1, // Manage versions carefully for migrations
          onOpen: (db) {
            debugPrint("[DBProviderIO] Database opened (version ${db.getVersion()})");
          },
          onCreate: _onCreateDB, // Separate function for creation logic
          onUpgrade: _onUpgradeDB // Separate function for upgrade logic
      );
    } catch (e, s) {
      debugPrint("[DBProviderIO] Error opening/creating database: $e\n$s");
      rethrow;
    }
  }

  /// Logic for creating database tables on first creation.
  Future<void> _onCreateDB(Database db, int version) async {
    debugPrint("[DBProviderIO] Creating database tables (version $version)...");
    await db.execute("CREATE TABLE Routines ("
        "id INTEGER PRIMARY KEY AUTOINCREMENT,"
        "routineName TEXT NOT NULL,"
        "mainTargetedBodyPart INTEGER," // Storing enum index
        "parts TEXT," // Storing JSON string
        "createdDate TEXT NOT NULL," // Storing ISO8601 string
        "lastCompletedDate TEXT,"
        "completionCount INTEGER DEFAULT 0 NOT NULL," // Added NOT NULL
        "weekdays TEXT NOT NULL," // Storing JSON string, Added NOT NULL
        "routineHistory TEXT NOT NULL" // Storing JSON string, Added NOT NULL
        ")");
    debugPrint("[DBProviderIO] Created Routines table.");

    await db.execute("CREATE TABLE WorkoutSessions ("
        "id TEXT PRIMARY KEY," // Session UUID
        "routineId INTEGER NOT NULL,"
        "startTime TEXT NOT NULL,"
        "endTime TEXT,"
        "isCompleted INTEGER DEFAULT 0 NOT NULL," // 0 or 1
        "exercises TEXT NOT NULL," // JSON List<ExercisePerformance>, Added NOT NULL
        "FOREIGN KEY (routineId) REFERENCES Routines(id) ON DELETE CASCADE"
        ")");
    debugPrint("[DBProviderIO] Created WorkoutSessions table.");
    debugPrint("[DBProviderIO] Database tables created successfully.");
  }

  /// Logic for handling database upgrades (schema changes).
  Future<void> _onUpgradeDB(Database db, int oldVersion, int newVersion) async {
    debugPrint("[DBProviderIO] Upgrading database from $oldVersion to $newVersion...");
    // Example: if (oldVersion < 2) { await db.execute("ALTER TABLE Routines ADD COLUMN description TEXT;"); }
    // Add migration logic here as your schema evolves.
  }


  @override
  Future<void> initDB() async {
    await db; // Access getter to ensure initialization completes
    debugPrint("[DBProviderIO] initDB() complete.");
  }


  // --- Routine Methods ---

  @override
  Future<int> newRoutine(Routine routine) async {
    final dbClient = await db;
    // Rely on routine.toMapForDb() to provide correctly encoded map
    final map = routine.toMapForDb();
    // ID is handled by AUTOINCREMENT, ensure it's not in the map
    map.remove('id');
    try {
      debugPrint("[DBProviderIO] Inserting Routine: ${map['routineName']}");
      int id = await dbClient.insert( 'Routines', map, conflictAlgorithm: ConflictAlgorithm.replace );
      debugPrint("[DBProviderIO] Inserted Routine with ID: $id");
      return id;
    } catch (e, s) {
      debugPrint("[DBProviderIO] Error inserting new routine: $e\n$s");
      debugPrint("[DBProviderIO] Failed Map content for insert: $map");
      rethrow;
    }
  }

  @override
  Future<void> updateRoutine(Routine routine) async {
    if (routine.id == null) { debugPrint("[DBProviderIO] Cannot update routine without ID."); return; }
    final dbClient = await db;
    // Rely on routine.toMapForDb() to provide correctly encoded map
    final map = routine.toMapForDb();
    try {
      debugPrint("[DBProviderIO] Updating Routine ID: ${routine.id}");
      int count = await dbClient.update( 'Routines', map, where: 'id = ?', whereArgs: [routine.id], );
      if (count == 0) { debugPrint("[DBProviderIO] Warning: Routine ${routine.id} not found for update."); }
      else { debugPrint("[DBProviderIO] Updated Routine ID: ${routine.id}"); }
    } catch (e, s) {
      debugPrint("[DBProviderIO] Error updating routine ${routine.id}: $e\n$s");
      debugPrint("[DBProviderIO] Failed Map content for update: $map");
      rethrow;
    }
  }

  @override
  Future<void> deleteRoutine(Routine routine) async {
    if (routine.id == null) { debugPrint("[DBProviderIO] Cannot delete routine without ID."); return; }
    final dbClient = await db;
    try {
      debugPrint("[DBProviderIO] Deleting Routine ID: ${routine.id}");
      int count = await dbClient.delete( 'Routines', where: 'id = ?', whereArgs: [routine.id], );
      debugPrint("[DBProviderIO] Deleted $count routine(s) with ID: ${routine.id}. Cascade delete should handle sessions.");
    } catch (e, s) {
      debugPrint("[DBProviderIO] Error deleting routine ${routine.id}: $e\n$s");
      rethrow;
    }
  }

  @override
  Future<List<Routine>> getAllRoutines() async {
    final dbClient = await db;
    try {
      final List<Map<String, dynamic>> maps = await dbClient.query('Routines', orderBy: 'routineName ASC');
      // Rely on Routine.fromMap() to handle JSON decoding
      final routines = maps.map((map) {
        try {
          return Routine.fromMap(map);
        } catch (e, s) {
          debugPrint("[DBProviderIO] Error parsing routine map during getAllRoutines: $e\n$s\nMap: $map");
          return null; // Skip routines that fail to parse
        }
      }).whereNotNull().toList();
      debugPrint("[DBProviderIO] Fetched ${routines.length} routines.");
      return routines;
    } catch (e, s) {
      debugPrint("[DBProviderIO] Error getting all routines: $e\n$s");
      return [];
    }
  }

  @override
  Future<List<Routine>> getAllRecRoutines() async { return []; } // Placeholder

  @override
  Future<void> addAllRoutines(List<Routine> routines) async {
    final dbClient = await db;
    Batch batch = dbClient.batch();
    int count = 0;
    for (var routine in routines) {
      // Rely on routine.toMapForDb()
      final map = routine.toMapForDb();
      map.remove('id'); // Let DB assign IDs
      batch.insert('Routines', map, conflictAlgorithm: ConflictAlgorithm.ignore);
      count++;
    }
    try {
      await batch.commit(noResult: true);
      debugPrint("[DBProviderIO] Batch added $count routines.");
    } catch (e, s) {
      debugPrint("[DBProviderIO] Error batch adding routines: $e\n$s");
      rethrow;
    }
  }

  @override
  Future<void> deleteAllRoutines() async {
    final dbClient = await db;
    try {
      debugPrint("[DBProviderIO] Deleting all user routines...");
      int count = await dbClient.delete('Routines');
      debugPrint("[DBProviderIO] Deleted $count routines. Sessions may be cascade deleted.");
      // Optionally clear sessions table explicitly if cascade isn't reliable/used
      // await dbClient.delete('WorkoutSessions');
    } catch (e, s) {
      debugPrint("[DBProviderIO] Error deleting all routines: $e\n$s");
      rethrow;
    }
  }

  // Helper to get single routine by ID - relies on Routine.fromMap
  Future<Routine?> _getRoutineById(int id) async {
    final dbClient = await db;
    try {
      final List<Map<String, dynamic>> maps = await dbClient.query(
        'Routines', where: 'id = ?', whereArgs: [id], limit: 1,
      );
      if (maps.isEmpty) return null;
      return Routine.fromMap(maps.first);
    } catch (e, s) {
      debugPrint("[DBProviderIO] Error getting routine by ID $id: $e\n$s");
      return null;
    }
  }

  // --- Workout Session Methods ---
  // ** These assume WorkoutSession.toMap/fromMap are CORRECTLY handling JSON **
  // ** encoding/decoding for the 'exercises' List<ExercisePerformance> field **

  @override
  Future<void> saveWorkoutSession(WorkoutSession session) async {
    final dbClient = await db;
    // ** WorkoutSession.toMap() MUST jsonEncode exercises list **
    final map = session.toMapForDb(); // Assuming a similar method exists or toMap handles it
    // map['isCompleted'] is already handled by WorkoutSession.toMap() likely
    try {
      debugPrint("[DBProviderIO] Saving WorkoutSession ID: ${session.id}");
      await dbClient.insert( 'WorkoutSessions', map, conflictAlgorithm: ConflictAlgorithm.replace, );
      debugPrint("[DBProviderIO] Saved WorkoutSession ID: ${session.id}");
    } catch (e, s) {
      debugPrint("[DBProviderIO] Error saving workout session ${session.id}: $e\n$s");
      debugPrint("[DBProviderIO] Failed Session Map content: $map");
      rethrow;
    }
  }

  @override
  Future<List<WorkoutSession>> getWorkoutSessions() async {
    final dbClient = await db;
    try {
      final List<Map<String, dynamic>> sessionMaps = await dbClient.query('WorkoutSessions', orderBy: 'startTime DESC');
      // Fetch all routines for efficient lookup
      final Map<int, Routine> routineMap = { for (var r in await getAllRoutines()) if (r.id != null) r.id!: r };

      final List<WorkoutSession> sessions = [];
      for (var map in sessionMaps) {
        final routineId = map['routineId'] as int?;
        if (routineId == null) { debugPrint('Skipping session ${map['id']} due to missing routineId'); continue; }
        final routine = routineMap[routineId];
        if (routine == null) { debugPrint('Skipping session ${map['id']} because routine $routineId was not found'); continue; }

        try {
          // ** WorkoutSession.fromMap() MUST jsonDecode 'exercises' field **
          final session = WorkoutSession.fromMap(map, routine);
          sessions.add(session);
        } catch(e, s) {
          debugPrint('[DBProviderIO] Error processing session ${map['id']} data: $e\n$s');
        }
      }
      debugPrint("[DBProviderIO] Fetched ${sessions.length} workout sessions.");
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
      final List<Map<String, dynamic>> maps = await dbClient.query( 'WorkoutSessions', where: 'id = ?', whereArgs: [id], limit: 1, );
      if (maps.isEmpty) return null;
      final map = maps.first;
      final routineId = map['routineId'] as int?;
      if (routineId == null) { /* ... */ return null; }
      final routine = await _getRoutineById(routineId);
      if (routine == null) { /* ... */ return null; }

      // ** WorkoutSession.fromMap() MUST jsonDecode 'exercises' field **
      return WorkoutSession.fromMap(map, routine);
    } catch (e, s) {
      debugPrint("[DBProviderIO] Error getting session by ID $id: $e\n$s");
      return null;
    }
  }

  @override
  Future<void> deleteWorkoutSession(String id) async {
    final dbClient = await db;
    try {
      debugPrint("[DBProviderIO] Deleting WorkoutSession ID: $id");
      int count = await dbClient.delete( 'WorkoutSessions', where: 'id = ?', whereArgs: [id], );
      debugPrint("[DBProviderIO] Deleted $count session(s) with ID: $id.");
    } catch (e, s) {
      debugPrint("[DBProviderIO] Error deleting session $id: $e\n$s");
      rethrow;
    }
  }

} // End DBProviderIO