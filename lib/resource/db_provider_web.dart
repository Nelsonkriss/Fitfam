// resource/db_provider_web.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_planner/models/routine.dart';
import 'package:workout_planner/models/workout_session.dart';
// import 'package:sqflite/sqflite.dart'; // Only if keeping 'db' getter in interface
import 'db_provider_interface.dart'; // Implement the INTERFACE

class DBProviderWeb implements DbProviderInterface {
  // @override // Only if 'db' getter is in the interface
  // Future<Database> get db async => throw UnsupportedError('Web platform does not use direct database access');

  static const String _routinesKey = 'workout_planner_routines';
  static const String _sessionsKey = 'workout_planner_sessions';
  static const String _recRoutinesKey = 'workout_planner_recommended_routines'; // Optional

  Future<SharedPreferences> get _prefs async => await SharedPreferences.getInstance();

  // --- Interface Implementation ---

  @override
  Future<void> initDB() async {
    // SharedPreferences initializes automatically on first use. No-op needed.
    debugPrint("DBProviderWeb initialized (SharedPreferences)");
  }

  // --- Routine Methods ---

  @override
  Future<int> newRoutine(Routine routine) async {
    final prefs = await _prefs;
    final routines = await getAllRoutines();
    // Assign a new unique ID (e.g., timestamp or find max existing ID)
    int nextId = 1;
    if (routines.isNotEmpty) {
      // Ensure IDs are not null before comparing
      final maxId = routines
          .map((r) => r.id ?? 0) // Default null IDs to 0 for comparison
          .reduce((max, current) => current > max ? current : max);
      nextId = maxId + 1;
    }
    // Use copyWith since Routine is likely immutable
    final routineWithId = routine.copyWith(id: nextId);
    routines.add(routineWithId);
    await _saveRoutinesList(prefs, routines);
    return nextId; // Return the assigned ID
  }

  @override
  Future<void> updateRoutine(Routine routine) async {
    if (routine.id == null) {
      debugPrint("Cannot update routine without an ID.");
      return;
    }
    final prefs = await _prefs;
    final routines = await getAllRoutines();
    final index = routines.indexWhere((r) => r.id == routine.id);
    if (index != -1) {
      routines[index] = routine; // Replace with the updated immutable routine
      await _saveRoutinesList(prefs, routines);
    } else {
      debugPrint("Routine with ID ${routine.id} not found for update.");
    }
  }

  @override
  Future<void> deleteRoutine(Routine routine) async { // Keep parameter type for now
    if (routine.id == null) {
      debugPrint("Cannot delete routine without an ID.");
      return;
    }
    final prefs = await _prefs;
    final routines = await getAllRoutines();
    final initialLength = routines.length;
    routines.removeWhere((r) => r.id == routine.id);
    if (routines.length < initialLength) {
      await _saveRoutinesList(prefs, routines);
    } else {
      debugPrint("Routine with ID ${routine.id} not found for deletion.");
    }
  }

  @override
  Future<List<Routine>> getAllRoutines() async {
    final prefs = await _prefs;
    final jsonString = prefs.getString(_routinesKey);
    if (jsonString == null || jsonString.isEmpty) return [];
    try {
      final jsonList = jsonDecode(jsonString) as List;
      return jsonList
          .map((json) => Routine.fromMap(json as Map<String, dynamic>))
          .where((r) => r.id != null) // Ensure routines have IDs after parsing
          .toList();
    } catch (e, s) {
      debugPrint("Error decoding routines: $e\n$s");
      // Consider clearing corrupted data: await prefs.remove(_routinesKey);
      return []; // Return empty list on error
    }
  }

  @override
  Future<List<Routine>> getAllRecRoutines() async {
    // Implementation depends on how rec routines are sourced/stored for web
    // Example using SharedPreferences similar to user routines:
    final prefs = await _prefs;
    final jsonString = prefs.getString(_recRoutinesKey);
    if (jsonString == null || jsonString.isEmpty) return [];
    try {
      final jsonList = jsonDecode(jsonString) as List;
      return jsonList
          .map((json) => Routine.fromMap(json as Map<String, dynamic>))
          .toList();
    } catch (e, s) {
      debugPrint("Error decoding recommended routines: $e\n$s");
      return [];
    }
  }

  @override
  Future<void> addAllRoutines(List<Routine> routines) async {
    final prefs = await _prefs;
    // Ensure routines have unique IDs before saving
    int nextId = 1;
    final Map<int, Routine> uniqueRoutines = {};
    for(final r in routines) {
      int currentId = r.id ?? nextId;
      while(uniqueRoutines.containsKey(currentId)) {
        currentId++; // Find next available ID
      }
      nextId = currentId + 1;
      uniqueRoutines[currentId] = r.copyWith(id: currentId);
    }
    await _saveRoutinesList(prefs, uniqueRoutines.values.toList());
  }

  @override
  Future<void> deleteAllRoutines() async {
    final prefs = await _prefs;
    await prefs.remove(_routinesKey);
    // Decide if this should also clear recommended routines or sessions
    // await prefs.remove(_recRoutinesKey);
    // await prefs.remove(_sessionsKey);
  }

  // --- Workout Session Methods ---

  @override
  Future<void> saveWorkoutSession(WorkoutSession session) async {
    final prefs = await _prefs;
    try {
      // Fetch existing sessions, handle potential decoding errors
      List<Map<String, dynamic>> sessionsMapList;
      try {
        sessionsMapList = (await _getAllSessionMaps(prefs));
      } catch (e) {
        debugPrint("Error reading existing sessions, starting fresh: $e");
        sessionsMapList = []; // Start with empty list if current data is corrupt
      }

      // Remove old version if exists
      sessionsMapList.removeWhere((sMap) => sMap['id'] == session.id);
      // Add new/updated version
      sessionsMapList.add(session.toMapForDb());
      // Save the modified list
      await _saveSessionMaps(prefs, sessionsMapList);
      if (kDebugMode) {
        print("Session ${session.id} saved. Total sessions: ${sessionsMapList.length}");
      }
    } catch (e, s) {
      debugPrint('Error saving workout session: $e\n$s');
      rethrow; // Re-throw to notify caller
    }
  }

  @override
  Future<List<WorkoutSession>> getWorkoutSessions() async {
    final prefs = await _prefs;
    List<Map<String, dynamic>> sessionsMapList;
    try {
      sessionsMapList = await _getAllSessionMaps(prefs);
    } catch(e) {
      debugPrint("Failed to get session maps, returning empty: $e");
      return [];
    }

    if (sessionsMapList.isEmpty) return [];

    try {
      // Load routines ONCE for efficient lookup
      final Map<int, Routine> routineMap = {
        for (var r in await getAllRoutines()) if (r.id != null) r.id!: r
      };

      final List<WorkoutSession> sessions = [];
      for (final map in sessionsMapList) {
        try {
          int? routineId = _parseToInt(map['routineId']);
          if (routineId == null) {
            debugPrint('Session ${map['id']} missing or invalid routineId. Skipping.');
            continue;
          }

          final routine = routineMap[routineId];
          if (routine == null) {
            debugPrint('Routine $routineId not found for session ${map['id']}. Skipping.');
            continue; // Skip session if its routine doesn't exist anymore
          }

          // Ensure fromMap handles potential type issues robustly
          final session = WorkoutSession.fromMap(map, routine);
          sessions.add(session);
        } catch (e, s) {
          // Log error for specific session but continue with others
          debugPrint('Error processing individual session ${map['id']}: $e\n$s');
        }
      }
      return sessions;
    } catch (e, s) {
      // Error processing the whole list or routines
      debugPrint('Error processing workout sessions: $e\n$s');
      return [];
    }
  }

  @override
  Future<WorkoutSession?> getWorkoutSessionById(String id) async {
    // This could be optimized by reading maps and filtering before full parsing
    final sessions = await getWorkoutSessions();
    try {
      return sessions.firstWhere((s) => s.id == id);
    } catch (e) {
      // Throws StateError if not found
      return null;
    }
  }

  @override
  Future<void> deleteWorkoutSession(String id) async {
    final prefs = await _prefs;
    try {
      List<Map<String, dynamic>> sessionsMapList = await _getAllSessionMaps(prefs);
      final initialLength = sessionsMapList.length;
      sessionsMapList.removeWhere((sMap) => sMap['id'] == id);
      if(sessionsMapList.length < initialLength){
        await _saveSessionMaps(prefs, sessionsMapList);
      } else {
        debugPrint("Session with ID $id not found for deletion.");
      }
    } catch(e, s) {
      debugPrint("Error deleting session $id: $e\n$s");
      rethrow;
    }
  }

  // --- Helper Methods ---

  Future<void> _saveRoutinesList(SharedPreferences prefs, List<Routine> routines) async {
    final listToSave = routines.map((r) => r.toMapForDb()).toList();
    await prefs.setString(_routinesKey, jsonEncode(listToSave));
  }

  Future<List<Map<String, dynamic>>> _getAllSessionMaps(SharedPreferences prefs) async {
    final jsonString = prefs.getString(_sessionsKey);
    if (jsonString == null || jsonString.isEmpty) return [];
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is List) {
        // Ensure all items are maps
        return decoded.whereType<Map<String, dynamic>>().toList();
      }
      debugPrint("Stored sessions data is not a List: $decoded");
      throw FormatException("Invalid session data format");
    } catch (e) {
      debugPrint("Error decoding session maps: $e. Clearing potentially corrupt data.");
      // Optionally clear corrupted data
      await prefs.remove(_sessionsKey);
      throw FormatException("Failed to decode sessions: $e"); // Re-throw specific error
    }
  }

  Future<void> _saveSessionMaps(SharedPreferences prefs, List<Map<String, dynamic>> maps) async {
    await prefs.setString(_sessionsKey, jsonEncode(maps));
  }

  int? _parseToInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    if (value is double) return value.toInt(); // Handle potential doubles
    return null;
  }

  @override
  Future<Routine?> getRoutineById(int id) {
    // TODO: implement getRoutineById
    throw UnimplementedError();
  }
}