import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_planner/models/routine.dart';
import 'package:workout_planner/models/workout_session.dart';
import 'package:workout_planner/models/main_targeted_body_part.dart';
import 'package:workout_planner/resource/db_provider.dart';

class DBProviderWeb implements DBProvider {
  static const String _routinesKey = 'workout_routines';
  static const String _sessionsKey = 'workout_sessions';
  static const String _recRoutinesKey = 'recommended_routines';

  Future<SharedPreferences> get _prefs async => await SharedPreferences.getInstance();

  @override
  Future<void> initDB() async {
    // Initialize any web-specific database setup
  }

  @override
  Future<int> newRoutine(Routine routine) async {
    final prefs = await _prefs;
    final routines = await getAllRoutines();
    routines.add(routine);
    await prefs.setString(_routinesKey, jsonEncode(routines.map((r) => r.toMap()).toList()));
    return routines.length - 1; // Return index as ID
  }

  @override
  Future<void> updateRoutine(Routine routine) async {
    final prefs = await _prefs;
    final routines = await getAllRoutines();
    final index = routines.indexWhere((r) => r.id == routine.id);
    if (index != -1) {
      routines[index] = routine;
      await prefs.setString(_routinesKey, jsonEncode(routines.map((r) => r.toMap()).toList()));
    }
  }

  @override
  Future<void> deleteRoutine(Routine routine) async {
    final prefs = await _prefs;
    final routines = await getAllRoutines();
    routines.removeWhere((r) => r.id == routine.id);
    await prefs.setString(_routinesKey, jsonEncode(routines.map((r) => r.toMap()).toList()));
  }

  @override
  Future<List<Routine>> getAllRoutines() async {
    final prefs = await _prefs;
    final jsonString = prefs.getString(_routinesKey);
    if (jsonString == null) return [];
    final jsonList = jsonDecode(jsonString) as List;
    return jsonList.map((json) => Routine.fromMap(json)).toList();
  }

  @override
  Future<List<Routine>> getAllRecRoutines() async {
    final prefs = await _prefs;
    final jsonString = prefs.getString(_recRoutinesKey);
    if (jsonString == null) return [];
    final jsonList = jsonDecode(jsonString) as List;
    return jsonList.map((json) => Routine.fromMap(json)).toList();
  }

  @override
  Future<void> addAllRoutines(List<Routine> routines) async {
    final prefs = await _prefs;
    await prefs.setString(_routinesKey, jsonEncode(routines.map((r) => r.toMap()).toList()));
  }

  @override
  Future<void> deleteAllRoutines() async {
    final prefs = await _prefs;
    await prefs.remove(_routinesKey);
  }
  // ... (keep existing properties and other methods)

  @override
  Future<void> saveWorkoutSession(WorkoutSession session) async {
    final prefs = await _prefs;
    try {
      if (kDebugMode) {
        print("Saving session: ${session.id}");
        print("Session data: ${session.toMap()}");
      }

      // Verify session data is valid
      if (session.routine.id == null || session.routine.id == 0) {
        throw Exception('Cannot save session with invalid routine ID');
      }

      // Get existing sessions
      final existing = prefs.getString(_sessionsKey);
      final sessions = existing != null 
          ? (jsonDecode(existing) as List).map((e) => e as Map<String,dynamic>).toList()
          : <Map<String,dynamic>>[];

      // Find and remove any existing session with same ID
      sessions.removeWhere((s) => s['id'] == session.id);

      // Add new session data
      sessions.add(session.toMap());

      // Save with error handling
      final jsonData = jsonEncode(sessions);
      final success = await prefs.setString(_sessionsKey, jsonData);
      
      if (!success) {
        throw Exception('Failed to save session data');
      }

      if (kDebugMode) {
        print("Session saved successfully. Total sessions: ${sessions.length}");
        // Verify the saved data
        final saved = prefs.getString(_sessionsKey);
        if (saved != jsonData) {
          debugPrint('WARNING: Saved data does not match expected!');
        }
      }
    } catch (e) {
      debugPrint('Error saving workout session: $e');
      rethrow;
    }
  }

  @override
  Future<List<WorkoutSession>> getWorkoutSessions() async {
    final prefs = await _prefs;
    final jsonString = prefs.getString(_sessionsKey);
    
    if (jsonString == null || jsonString.isEmpty) {
      if (kDebugMode) {
        print("No sessions found in storage");
      }
      return [];
    }
    
    try {
      final jsonList = jsonDecode(jsonString) as List;
      final sessions = <WorkoutSession>[];
      final routines = await getAllRoutines();
      
      if (kDebugMode) {
        print("Found ${jsonList.length} session records");
        print("Available routines: ${routines.length}");
      }
      
      for (final json in jsonList) {
        try {
          // Handle both string and int routine IDs
          dynamic routineId = json['routineId'];
          if (routineId == null) {
            debugPrint('Session missing routineId: $json');
            continue;
          }
          
          // Convert to string for comparison
          final routineIdStr = routineId.toString();
          
          final routine = routines.firstWhere(
            (r) => r.id.toString() == routineIdStr,
            orElse: () {
              debugPrint('Routine $routineId not found for session');
              throw Exception('Routine not found');
            }
          );
          
          final session = WorkoutSession.fromMap(json, routine);
          if (kDebugMode) {
            print("Loaded session: ${session.id}");
            print("- Routine: ${routine.routineName} (ID: ${routine.id})");
            print("- Exercises: ${session.exercises.length}");
            print("- Duration: ${session.duration}");
          }
          sessions.add(session);
        } catch (e) {
          debugPrint('Error loading session $json: $e');
          // Continue with next session instead of failing completely
        }
      }
      
      if (kDebugMode) {
        print("Successfully loaded ${sessions.length} sessions");
      }
      return sessions;
    } catch (e) {
      debugPrint('Error decoding sessions: $e');
      return [];
    }
  }

  @override
  Future<WorkoutSession?> getWorkoutSessionById(String id) async {
    final sessions = await getWorkoutSessions();
    try {
      return sessions.firstWhere((s) => s.id == id);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> deleteWorkoutSession(String id) async {
    final prefs = await _prefs;
    final sessions = await getWorkoutSessions();
    sessions.removeWhere((s) => s.id == id);
    await prefs.setString(_sessionsKey, jsonEncode(sessions.map((s) => s.toMap()).toList()));
  }
}
