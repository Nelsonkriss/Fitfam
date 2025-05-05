// models/routine.dart

import 'dart:convert'; // Import dart:convert for JSON handling
import 'package:collection/collection.dart'; // For listEquals and hashAll
import 'package:flutter/foundation.dart'; // For debugPrint, @immutable
import 'package:meta/meta.dart'; // For @immutable

// Assuming these models are defined correctly and handle their own toMap/fromMap
import 'package:workout_planner/models/main_targeted_body_part.dart';
import 'part.dart'; // Assumes Part model handles JSON for 'exercises' list if needed

// Export Part if needed by other files importing Routine
export 'part.dart';

/// Represents a workout routine template.
/// Instances are immutable. Use [copyWith] to create modified versions.
@immutable
class Routine {
  final int? id;
  final String routineName;
  final MainTargetedBodyPart mainTargetedBodyPart;
  /// List of parts, each containing exercises for that part of the workout.
  final List<Part> parts; // List of Part objects
  final DateTime createdDate;
  final DateTime? lastCompletedDate;
  final int completionCount;
  /// Days of the week (1=Mon, 7=Sun) this routine is scheduled for.
  final List<int> weekdays; // List of integers
  /// History of completion timestamps (millisecondsSinceEpoch).
  final List<int> routineHistory; // List of integers (timestamps)

  /// Creates an immutable Routine instance.
  const Routine({
    this.id,
    required this.routineName,
    required this.mainTargetedBodyPart,
    required this.parts,
    required this.createdDate,
    this.lastCompletedDate,
    this.completionCount = 0,
    List<int>? weekdays, // Nullable list arguments
    List<int>? routineHistory, // Nullable list arguments
  })  : weekdays = weekdays ?? const [], // Use const empty lists as default
        routineHistory = routineHistory ?? const [];

  /// Derived getter to extract all exercises from all parts.
  /// Useful for WorkoutSession initialization.
  List<Exercise> get exercises {
    try {
      return parts.expand((part) => part.exercises).toList();
    } catch(e,s) {
      debugPrint("Error expanding exercises from parts in Routine '$routineName': $e\n$s");
      return [];
    }
  }


  /// Creates a new Routine instance with specified fields updated.
  Routine copyWith({
    int? id,
    String? routineName,
    MainTargetedBodyPart? mainTargetedBodyPart,
    List<Part>? parts, // If updating parts, pass the new list
    DateTime? createdDate,
    // Use Object? trick to allow setting lastCompletedDate to null
    Object? lastCompletedDate = const _Undefined(),
    int? completionCount,
    List<int>? weekdays,
    List<int>? routineHistory,
  }) {
    return Routine(
      id: id ?? this.id,
      routineName: routineName ?? this.routineName,
      mainTargetedBodyPart: mainTargetedBodyPart ?? this.mainTargetedBodyPart,
      // Keep existing list reference if not provided (lists are immutable)
      parts: parts ?? this.parts,
      createdDate: createdDate ?? this.createdDate,
      lastCompletedDate: lastCompletedDate is _Undefined
          ? this.lastCompletedDate
          : lastCompletedDate as DateTime?,
      completionCount: completionCount ?? this.completionCount,
      // Only create new list instances if a new list is actually passed
      weekdays: weekdays ?? this.weekdays,
      routineHistory: routineHistory ?? this.routineHistory,
    );
  }

  /// Serializes the Routine to a Map suitable for DB insertion (e.g., Sqflite).
  /// Encodes lists (`parts`, `weekdays`, `routineHistory`) into JSON strings for TEXT columns.
  Map<String, dynamic> toMapForDb() {
    // ** Assumes Part.toMap() exists and works correctly **
    String encodedParts = '[]'; // Default to empty JSON array
    try {
      encodedParts = jsonEncode(parts.map((p) => p.toMap()).toList());
    } catch (e) {
      debugPrint("Error encoding parts list to JSON in Routine '$routineName': $e");
    }

    return {
      // 'id' is handled by DB auto-increment, so it's not included here for inserts.
      // It *is* included when called by updateRoutine in DBProviderIO via the model passed in.
      // Keep it consistent with how Sqflite update/insert works. Usually maps don't include ID for insert.
      // But for UPDATE, the map might include ID if needed by the model layer, though DBProvider uses `where id = ?`.
      // Let's include it here as DBProvider update logic expects the full map.
      'id': id,
      'routineName': routineName,
      'mainTargetedBodyPart': mainTargetedBodyPart.index, // Store enum index (INTEGER)
      'parts': encodedParts, // Store JSON string (TEXT)
      'createdDate': createdDate.toIso8601String(), // Store as ISO8601 string (TEXT)
      'lastCompletedDate': lastCompletedDate?.toIso8601String(), // TEXT or NULL
      'completionCount': completionCount, // Store as INTEGER
      'weekdays': jsonEncode(weekdays), // Encode List<int> to JSON string (TEXT)
      'routineHistory': jsonEncode(routineHistory), // Encode List<int> to JSON string (TEXT)
    };
  }

  /// Creates a Routine instance from a Map retrieved from the database.
  /// Decodes JSON strings from TEXT columns back into Dart lists.
  factory Routine.fromMap(Map<String, dynamic> map) {
    // --- Helper Functions for Safe Decoding ---
    List<T> decodeJsonList<T>(dynamic jsonInput) {
      if (jsonInput is String && jsonInput.isNotEmpty) {
        try {
          final decoded = jsonDecode(jsonInput);
          if (decoded is List) {
            // Handle primitive types directly
            if (T == int) return decoded.whereType<int>().toList() as List<T>;
            if (T == double) return decoded.whereType<num>().map((n) => n.toDouble()).toList() as List<T>;
            if (T == String) return decoded.whereType<String>().toList() as List<T>;
            if (T == bool) return decoded.whereType<bool>().toList() as List<T>;
            // Fallback for other simple types (less common in this context)
            return decoded.whereType<T>().toList();
          }
        } catch (e) {
          debugPrint("Error decoding list JSON ('$jsonInput'): $e");
        }
      }
      return <T>[]; // Return empty list on error or invalid input
    }

    List<Part> decodePartsList(dynamic jsonInput) {
      if (jsonInput is String && jsonInput.isNotEmpty) {
        try {
          final decodedList = jsonDecode(jsonInput) as List?;
          if (decodedList != null) {
            // ** Assumes Part.fromMap exists and works correctly **
            return decodedList
                .map((p) {
              try {
                if (p is Map<String, dynamic>) {
                  return Part.fromMap(p);
                } else { return null; }
              } catch (e) { return null; }
            })
                .whereNotNull()
                .toList();
          }
        } catch (e) { debugPrint("Error decoding parts list JSON ('$jsonInput'): $e"); }
      }
      return []; // Return empty list on error or invalid input
    }

    DateTime? parseOptionalDate(dynamic value) {
      if (value is String && value.isNotEmpty) { return DateTime.tryParse(value); }
      return null;
    }
    // --- End Helper Functions ---

    // Parse MainTargetedBodyPart safely
    MainTargetedBodyPart bodyPart = MainTargetedBodyPart.FullBody; // Default
    if (map['mainTargetedBodyPart'] is int) {
      int index = map['mainTargetedBodyPart'];
      if (index >= 0 && index < MainTargetedBodyPart.values.length) {
        bodyPart = MainTargetedBodyPart.values[index];
      }
    }

    return Routine(
      id: map['id'] as int?, // Get ID from map
      routineName: map['routineName'] as String? ?? 'Unnamed Routine',
      mainTargetedBodyPart: bodyPart,
      parts: decodePartsList(map['parts']), // Decode parts list
      createdDate: parseOptionalDate(map['createdDate']) ?? DateTime.now(), // Default if parsing fails
      lastCompletedDate: parseOptionalDate(map['lastCompletedDate']),
      completionCount: map['completionCount'] as int? ?? 0,
      weekdays: decodeJsonList<int>(map['weekdays']), // Decode int list
      routineHistory: decodeJsonList<int>(map['routineHistory']), // Decode int list
    );
  }


  @override
  String toString() {
    return 'Routine(id: $id, name: $routineName, parts: ${parts.length})';
  }

  // Equality operator using DeepCollectionEquality for lists
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    final listEquals = const DeepCollectionEquality().equals;

    return other is Routine &&
        runtimeType == other.runtimeType &&
        id == other.id &&
        routineName == other.routineName &&
        mainTargetedBodyPart == other.mainTargetedBodyPart &&
        listEquals(parts, other.parts) && // Deep compare parts list
        createdDate == other.createdDate &&
        lastCompletedDate == other.lastCompletedDate &&
        completionCount == other.completionCount &&
        listEquals(weekdays, other.weekdays) && // Compare int lists
        listEquals(routineHistory, other.routineHistory); // Compare int lists
  }

  // Hash code generation using Object.hash and DeepCollectionEquality
  @override
  int get hashCode => Object.hash(
    id,
    routineName,
    mainTargetedBodyPart,
    const DeepCollectionEquality().hash(parts), // Deep hash for parts list
    createdDate,
    lastCompletedDate,
    completionCount,
    const DeepCollectionEquality().hash(weekdays), // Hash for int list
    const DeepCollectionEquality().hash(routineHistory), // Hash for int list
  );
}

// Helper class for copyWith differentiation when needing to set null explicitly
class _Undefined { const _Undefined(); }