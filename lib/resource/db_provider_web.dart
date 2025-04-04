import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_planner/models/routine.dart';
import 'package:workout_planner/resource/db_provider.dart';

class DBProviderWeb implements DBProvider {
  static const String _routinesKey = 'workout_routines';
  static const String _recommendedRoutinesKey = 'recommended_routines';

  Future<SharedPreferences> get _prefs async {
    return await SharedPreferences.getInstance();
  }

  @override
  Future<void> initDB() async {
    // No initialization needed for web
  }

  @override
  Future<int> newRoutine(Routine routine) async {
    final prefs = await _prefs;
    try {
      final routines = await getAllRoutines();
      final id = routines.length + 1;
      routine.id = id;
      routines.add(routine);
      
      // Convert routines to List<Map> before encoding
      final routinesData = routines.map((r) => r.toMap()).toList();
      await prefs.setString(_routinesKey, jsonEncode(routinesData));
      return id;
    } catch (e) {
      print('Error saving routine: $e');
      rethrow;
    }
  }

  @override
  Future<int> updateRoutine(Routine routine) async {
    final prefs = await _prefs;
    try {
      final routines = await getAllRoutines();
      final index = routines.indexWhere((r) => r.id == routine.id);
      if (index >= 0) {
        routines[index] = routine;
        
        // Convert routines to List<Map> before encoding
        final routinesData = routines.map((r) => r.toMap()).toList();
        await prefs.setString(_routinesKey, jsonEncode(routinesData));
        return 1; // Return number of affected rows
      }
      return 0;
    } catch (e) {
      print('Error updating routine: $e');
      rethrow;
    }
  }

  @override
  Future<int> deleteRoutine(Routine routine) async {
    final prefs = await _prefs;
    try {
      final routines = await getAllRoutines();
      final initialLength = routines.length;
      routines.removeWhere((r) => r.id == routine.id);
      if (routines.length < initialLength) {
        // Convert routines to List<Map> before encoding
        final routinesData = routines.map((r) => r.toMap()).toList();
        await prefs.setString(_routinesKey, jsonEncode(routinesData));
        return 1; // Return number of affected rows
      }
      return 0;
    } catch (e) {
      print('Error deleting routine: $e');
      rethrow;
    }
  }

  @override
  Future<int> deleteAllRoutines() async {
    final prefs = await _prefs;
    await prefs.remove(_routinesKey);
    return 1; // Assume success
  }

  @override
  Future<void> addAllRoutines(List<Routine> routines) async {
    final prefs = await _prefs;
    await prefs.setString(_routinesKey, jsonEncode(routines));
  }

  @override
  Future<List<Routine>> getAllRoutines() async {
    final prefs = await _prefs;
    final jsonString = prefs.getString(_routinesKey);
    if (jsonString == null || jsonString.isEmpty) return [];
    
    try {
      final decoded = jsonDecode(jsonString) as List;
      return decoded
          .map((r) => Routine.fromMap(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error parsing routines: $e');
      return [];
    }
  }

  @override
  Future<List<Routine>> getAllRecRoutines() async {
    final prefs = await _prefs;
    final jsonString = prefs.getString(_recommendedRoutinesKey);
    if (jsonString == null) return [];
    try {
      return (jsonDecode(jsonString) as List)
          .map((r) => Routine.fromMap(r))
          .toList();
    } catch (e) {
      if (kDebugMode) print('Error parsing recommended routines: $e');
      return [];
    }
  }

  @override
  Future<int> getLastId() async {
    final routines = await getAllRoutines();
    if (routines.isEmpty) return 1;
    return (routines.last.id ?? 0) + 1;
  }
}