import 'dart:convert'; // <-- Import for jsonEncode/Decode
import 'package:collection/collection.dart'; // For potential listEquals if needed
import 'package:uuid/uuid.dart'; // For generating IDs
import 'package:meta/meta.dart'; // For @immutable
import 'package:flutter/foundation.dart'; // For debugPrint, Object.hash

// Import corrected models (adjust paths if necessary)
import 'package:workout_planner/models/routine.dart';
import 'package:workout_planner/models/exercise_performance.dart'; // Import corrected ExercisePerformance
import 'package:workout_planner/models/set_performance.dart'; // Needed indirectly by ExercisePerformance
import 'package:workout_planner/models/exercise.dart'; // Needed by ExercisePerformance.fromExerciseDefinition
import 'package:workout_planner/models/part.dart'; // Needed indirectly by Routine

/// Represents an active or completed workout session based on a Routine.
@immutable // Mark as immutable where possible (endTime/isCompleted/exercises are mutable state)
class WorkoutSession {
  final String id;
  final Routine routine; // Assumes Routine is immutable
  final DateTime startTime;

  // State that changes during/after the session
  final DateTime? endTime;
  final bool isCompleted;
  final List<ExercisePerformance> exercises; // List of immutable ExercisePerformance

  /// Creates an instance representing a workout session state.
  /// Use copyWith to represent changes during the session.
  const WorkoutSession({ // Make constructor const
    required this.id,
    required this.routine,
    required this.startTime,
    required this.exercises, // Require exercises list
    this.endTime,
    this.isCompleted = false,
  });

  /// Factory to create a *new* workout session instance when starting.
  /// Generates UUID and initial exercise performance list.
  factory WorkoutSession.startNew({
    required Routine routine,
    DateTime? startTime, // Allow specifying start time, default to now
  }) {
    final actualStartTime = startTime ?? DateTime.now();
    final newId = const Uuid().v4(); // Generate unique ID
    final initialExercises = _createDefaultPerformances(routine); // Create initial state

    return WorkoutSession(
      id: newId,
      routine: routine,
      startTime: actualStartTime,
      exercises: initialExercises,
      endTime: null, // Not ended yet
      isCompleted: false, // Not completed yet
    );
  }

  /// Creates a new WorkoutSession instance representing an updated state.
  WorkoutSession copyWith({
    String? id,
    Routine? routine,
    DateTime? startTime,
    List<ExercisePerformance>? exercises,
    DateTime? endTime,
    bool? isCompleted,
    bool clearEndTime = false, // Flag to set endTime to null
  }) {
    return WorkoutSession(
      id: id ?? this.id,
      routine: routine ?? this.routine,
      startTime: startTime ?? this.startTime,
      // Assume exercises list passed is the complete new state
      exercises: exercises ?? this.exercises,
      endTime: clearEndTime ? null : (endTime ?? this.endTime),
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  /// Helper to create initial performance trackers based on the routine plan.
  static List<ExercisePerformance> _createDefaultPerformances(Routine routine) {
    try {
      return routine.parts
          .expand((part) => part.exercises.map(
        // Use factory from ExercisePerformance
              (exercise) => ExercisePerformance.fromExerciseDefinition(exercise))
      )
          .toList();
    } catch (e) {
      debugPrint("Error creating default performances: $e");
      return []; // Return empty list on error
    }
  }

  /// Calculates the duration of the workout session.
  Duration get duration {
    if (endTime != null) {
      return endTime!.difference(startTime).isNegative
          ? Duration.zero // Handle potential clock skew issues
          : endTime!.difference(startTime);
    } else if (!isCompleted) {
      // Ongoing session duration (up to now)
      return DateTime.now().difference(startTime).isNegative
          ? Duration.zero
          : DateTime.now().difference(startTime);
    } else {
      // Completed but somehow endTime is null? Return zero duration.
      return Duration.zero;
    }
  }

  /// Serializes the WorkoutSession state to a Map suitable for DB storage.
  /// Encodes the 'exercises' list into a JSON string.
  Map<String, dynamic> toMapForDb() { // Renamed for clarity
    String encodedExercises = '[]';
    try {
      // ExercisePerformance.toMapForDb() handles encoding its own 'sets' list
      encodedExercises = jsonEncode(exercises.map((e) => e.toMapForDb()).toList());
    } catch (e) {
      debugPrint("Error encoding exercises list to JSON in WorkoutSession '$id': $e");
      // Handle error
    }

    return {
      'id': id,
      'routineId': routine.id, // Foreign key reference
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(), // Store as ISO string or NULL
      'isCompleted': isCompleted ? 1 : 0, // Store boolean as INTEGER (0 or 1)
      // *** FIX: Store exercises as JSON encoded string ***
      'exercises': encodedExercises, // Store as TEXT
    };
  }

  /// Creates a WorkoutSession instance from a Map (e.g., from database).
  /// Requires the corresponding [Routine] object to be passed in.
  /// Decodes the 'exercises' list from a JSON string.
  factory WorkoutSession.fromMap(Map<String, dynamic> map, Routine routine) {
    // --- Helper function to safely decode list of ExercisePerformances ---
    List<ExercisePerformance> _decodeExercisesList(dynamic jsonInput) {
      if (jsonInput is String && jsonInput.isNotEmpty) {
        try {
          final decodedList = jsonDecode(jsonInput) as List?;
          if (decodedList != null) {
            // ** CRITICAL: Assumes ExercisePerformance.fromMap exists and handles its nested 'sets' list **
            return decodedList.map((exMap) {
              try {
                if (exMap is Map<String, dynamic>) {
                  return ExercisePerformance.fromMap(exMap);
                } else { return null; }
              } catch (e) {
                debugPrint("Error decoding single ExercisePerformance from map: $exMap, Error: $e");
                return null;
              }
            }).whereNotNull().toList();
          }
        } catch (e) {
          debugPrint("Error decoding exercises list JSON ('$jsonInput'): $e");
        }
      }
      return []; // Return empty on error
    }
    // --- End Helper ---

    // --- Helper for robust DateTime parsing ---
    DateTime? _tryParseDateTime(dynamic value) {
      if (value is String && value.isNotEmpty) { return DateTime.tryParse(value); }
      return null;
    }
    // --- End Helper ---

    return WorkoutSession(
      // Use Uuid().v4() only if ID is truly missing/null from DB, otherwise use DB value
      id: map['id'] as String? ?? const Uuid().v4(),
      routine: routine, // Provided externally
      startTime: _tryParseDateTime(map['startTime']) ?? DateTime.now(), // Default if parse fails
      endTime: _tryParseDateTime(map['endTime']), // Nullable
      // Convert INTEGER (0/1) back to boolean
      isCompleted: (map['isCompleted'] as int? ?? 0) == 1,
      // *** FIX: Decode list from JSON string ***
      exercises: _decodeExercisesList(map['exercises']),
    );
  }


  @override
  String toString() {
    return 'WorkoutSession(id: $id, routine: ${routine.routineName}, startTime: $startTime, completed: $isCompleted)';
  }

  // Equality based on ID for identifying specific session instances
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is WorkoutSession && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}