// models/workout_session.dart

import 'package:flutter/foundation.dart'; // For diagnostics, Object.hash
import 'package:uuid/uuid.dart'; // For generating unique IDs
// For @immutable
import 'package:collection/collection.dart'; // For DeepCollectionEquality

// Import related models
import 'routine.dart'; // Includes Part definition indirectly if exported
import 'exercise_performance.dart';
// Needed by ExercisePerformance
// import 'part.dart'; // No longer needed directly if Routine exports Part
// Needed by ExercisePerformance.fromExerciseDefinition

@immutable
class WorkoutSession {
  /// Unique identifier for the session (e.g., UUID String).
  final String id;
  /// The routine template this session is based on. Contains routineId.
  final Routine routine; // Assumes Routine is immutable and implements ==/hashCode
  /// The exact time the session was started.
  final DateTime startTime;
  /// The exact time the session was finished (null if ongoing or aborted).
  final DateTime? endTime;
  /// Flag indicating if the session was successfully completed.
  final bool isCompleted;
  /// List tracking the performance of each exercise in the session.
  /// NOTE: In the normalized DB schema, this list is populated separately
  /// by DBProviderIO after the main session object is created.
  final List<ExercisePerformance> exercises; // List of immutable ExercisePerformance

  // Private constructor - use factories or copyWith for instance creation
  const WorkoutSession._internal({
    required this.id,
    required this.routine,
    required this.startTime,
    required this.exercises,
    this.endTime,
    this.isCompleted = false,
  });

  /// Factory to create a *new* workout session instance when starting.
  /// Generates UUID and initial exercise performance list based on the routine.
  factory WorkoutSession.startNew({
    required Routine routine,
    DateTime? startTime, // Allow specifying start time, default to now
  }) {
    final actualStartTime = startTime ?? DateTime.now();
    final newId = const Uuid().v4(); // Generate unique ID

    // Create the initial list of ExercisePerformance objects based on the routine plan
    // *** FIX: Pass the routine to the corrected helper method ***
    final initialExercises = _createDefaultPerformances(routine);

    return WorkoutSession._internal(
      id: newId,
      routine: routine,
      startTime: actualStartTime,
      exercises: initialExercises, // Start with planned exercises/sets
      endTime: null, // Not ended yet
      isCompleted: false, // Not completed yet
    );
  }

  /// Factory to reconstruct a WorkoutSession *base object* from a database map.
  /// This map corresponds ONLY to the columns in the `WorkoutSessions` table.
  /// The 'exercises' list MUST be populated separately by the caller (e.g., DBProviderIO)
  /// after fetching data from the related normalized tables.
  factory WorkoutSession.fromMap(Map<String, dynamic> map, Routine routine) {
    // Helper for robust DateTime parsing
    DateTime? tryParseDateTime(dynamic value) {
      if (value is String && value.isNotEmpty) { return DateTime.tryParse(value); }
      return null;
    }

    // Validate required fields from map
    final String sessionId = map['id'] as String? ?? const Uuid().v4(); // Generate fallback ID if missing (should not happen)
    final DateTime sessionStartTime = tryParseDateTime(map['startTime']) ?? DateTime.now(); // Default if parse fails
    final bool sessionIsCompleted = (map['isCompleted'] as int? ?? 0) == 1; // Convert DB int (0/1) to bool
    final DateTime? sessionEndTime = tryParseDateTime(map['endTime']); // Nullable

    return WorkoutSession._internal(
      id: sessionId,
      routine: routine, // Routine is fetched and passed in separately
      startTime: sessionStartTime,
      endTime: sessionEndTime,
      isCompleted: sessionIsCompleted,
      // *** CRITICAL: Initialize exercises as empty list here. ***
      // The caller (DBProviderIO) is responsible for fetching data from
      // ExercisePerformances/SetPerformances tables and populating this list later.
      exercises: [],
    );
  }

  /// Serializes the **top-level** WorkoutSession fields into a Map suitable
  /// for inserting/updating the 'WorkoutSessions' database table.
  /// **It DOES NOT include the 'exercises' list.** The DBProviderIO handles
  /// saving the nested exercises/sets into their separate normalized tables.
  Map<String, dynamic> toMapForDb() {
    // Ensure the routine has an ID, as it's a foreign key
    if (routine.id == null) {
      throw StateError('Cannot map WorkoutSession to DB: Associated Routine is missing an ID.');
    }

    return {
      'id': id, // PRIMARY KEY (TEXT)
      'routineId': routine.id, // FOREIGN KEY (INTEGER)
      'startTime': startTime.toIso8601String(), // TEXT (ISO8601 String)
      'endTime': endTime?.toIso8601String(), // TEXT (ISO8601 String or NULL)
      'isCompleted': isCompleted ? 1 : 0, // INTEGER (0 or 1)
      // 'exercises' field is intentionally OMITTED here.
    };
  }


  /// Creates a copy of this WorkoutSession but with the given fields replaced.
  /// Use this for immutable state updates within the BLoC.
  WorkoutSession copyWith({
    String? id,
    Routine? routine,
    DateTime? startTime,
    List<ExercisePerformance>? exercises, // Allow replacing the exercises list
    // Use Object? to allow setting endTime to null explicitly via copyWith(endTime: null)
    Object? endTime = const _Undefined(),
    bool? isCompleted,
  }) {
    return WorkoutSession._internal(
      id: id ?? this.id,
      routine: routine ?? this.routine,
      startTime: startTime ?? this.startTime,
      exercises: exercises ?? this.exercises, // Use provided list or keep original
      endTime: endTime is _Undefined ? this.endTime : endTime as DateTime?,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  /// **CORRECTED** Helper method used by `startNew` factory to create initial performance trackers.
  /// Iterates through the routine's parts and the exercises within each part.
  static List<ExercisePerformance> _createDefaultPerformances(Routine routine) {
    final List<ExercisePerformance> defaultPerformances = [];
    try {
      // Iterate through each Part defined in the Routine
      for (final part in routine.parts) {
        // Iterate through each Exercise defined within the Part
        for (final exerciseDefinition in part.exercises) {
          // Use the factory from ExercisePerformance to create the initial state
          // for this specific exercise based on its definition (sets, reps, weight)
          defaultPerformances.add(
              ExercisePerformance.fromExerciseDefinition(exerciseDefinition));
        }
      }
      if (defaultPerformances.isEmpty) {
        debugPrint("Warning: No exercises found within the parts of routine '${routine.routineName}'.");
      }
      return defaultPerformances;
    } catch (e, s) {
      debugPrint("Error creating default ExercisePerformances for routine '${routine.routineName}': $e\n$s");
      return []; // Return empty list on error
    }
  }

  /// Calculates the duration of the workout session.
  /// Returns Duration.zero if ongoing or if data is inconsistent.
  Duration get duration {
    final et = endTime; // Cache endTime
    if (et != null) {
      final diff = et.difference(startTime);
      // Return zero if duration is negative (clock issues)
      return diff.isNegative ? Duration.zero : diff;
    } else {
      // Not finished or inconsistent state
      return Duration.zero;
    }
  }


  @override
  String toString() {
    return 'WorkoutSession(id: $id, routine: ${routine.routineName}, startTime: $startTime, completed: $isCompleted, exercises_count: ${exercises.length})';
  }

  // Equality comparison: Primarily based on ID for identity, but includes other
  // fields for value comparison if needed (e.g., in tests or collections).
  // Using DeepCollectionEquality for the exercises list is crucial for value comparison.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    final listEquals = const DeepCollectionEquality().equals;

    return other is WorkoutSession &&
        runtimeType == other.runtimeType &&
        id == other.id &&
        routine == other.routine && // Assumes Routine implements == correctly
        startTime == other.startTime &&
        endTime == other.endTime &&
        isCompleted == other.isCompleted &&
        listEquals(exercises, other.exercises); // Deep list comparison
  }

  @override
  int get hashCode => Object.hash(
    id,
    routine, // Assumes Routine implements hashCode correctly
    startTime,
    endTime,
    isCompleted,
    const DeepCollectionEquality().hash(exercises), // Use deep hash for list
  );
}

// Helper class for copyWith differentiation when needing to set null explicitly
class _Undefined { const _Undefined(); }