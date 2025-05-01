import 'dart:convert'; // <-- Import for jsonEncode/Decode
import 'package:flutter/foundation.dart'; // For debugPrint, Object.hash
import 'package:collection/collection.dart'; // For DeepCollectionEquality
// For @immutable

// Assuming these models are correctly defined
import 'package:workout_planner/models/exercise.dart'; // Import Exercise model
import 'package:workout_planner/models/set_performance.dart'; // Import SetPerformance model

/// Tracks the performance details for a single exercise within a WorkoutSession.
@immutable // Mark as immutable
class ExercisePerformance {
  final String exerciseName;
  final List<SetPerformance> sets; // List of immutable SetPerformance objects
  final Duration? restPeriod; // Planned rest period (immutable)

  /// Creates an immutable instance of ExercisePerformance.
  const ExercisePerformance({ // Make constructor const
    required this.exerciseName,
    required this.sets,
    this.restPeriod,
  });

  /// Creates a new ExercisePerformance instance with updated values.
  ExercisePerformance copyWith({
    String? exerciseName,
    List<SetPerformance>? sets,
    Duration? restPeriod,
    bool clearRestPeriod = false, // Flag to explicitly set restPeriod to null
  }) {
    return ExercisePerformance(
      exerciseName: exerciseName ?? this.exerciseName,
      // If sets list is provided, use it; otherwise keep original reference
      sets: sets ?? this.sets,
      restPeriod: clearRestPeriod ? null : (restPeriod ?? this.restPeriod),
    );
  }

  /// Creates an initial ExercisePerformance based on an Exercise definition.
  factory ExercisePerformance.fromExerciseDefinition(Exercise exercise) {
    // --- Logic to parse target reps from Exercise.reps string ---
    int targetReps = 0;
    try {
      // Handle simple numbers, ranges (use first number), or default
      final repString = exercise.reps.trim();
      if (repString.contains('-')) {
        targetReps = int.tryParse(repString.split('-').first.trim()) ?? 0;
      } else {
        targetReps = int.tryParse(repString) ?? 0;
      }
    } catch (_) { /* Ignore parsing errors, keep targetReps = 0 */ }
    // --- End Reps Parsing ---

    return ExercisePerformance(
      exerciseName: exercise.name,
      // Create list of SetPerformance based on Exercise plan
      sets: List.generate(
        exercise.sets.clamp(0, 100), // Ensure non-negative sets (and reasonable max)
            (i) => SetPerformance( // Create immutable SetPerformance
          targetReps: targetReps,
          targetWeight: exercise.weight.clamp(0.0, 9999.0), // Ensure non-negative weight
          // Initial actual values are 0/false
        ),
        growable: false, // List length is fixed based on plan
      ),
      // TODO: Potentially get planned restPeriod from Exercise model if available
      restPeriod: const Duration(seconds: 60), // Default rest period
    );
  }

  /// Serializes the ExercisePerformance state to a Map suitable for DB storage.
  /// Encodes the 'sets' list into a JSON string.
  Map<String, dynamic> toMapForDb() { // Renamed for clarity
    String encodedSets = '[]';
    try {
      encodedSets = jsonEncode(sets.map((s) => s.toMap()).toList());
    } catch (e) {
      debugPrint("Error encoding sets list to JSON in ExercisePerformance '$exerciseName': $e");
      // Handle error appropriately
    }
    return {
      'exerciseName': exerciseName,
      // *** FIX: Encode list to JSON string ***
      'sets': encodedSets,
      'restPeriodInSeconds': restPeriod?.inSeconds, // Store duration as seconds (INTEGER)
    };
  }

  /// Creates an ExercisePerformance instance from a Map (e.g., from database).
  /// Decodes the 'sets' list from a JSON string.
  factory ExercisePerformance.fromMap(Map<String, dynamic> map) {
    // --- Helper function to safely decode list of Sets ---
    List<SetPerformance> decodeSetsList(dynamic jsonInput) {
      if (jsonInput is String && jsonInput.isNotEmpty) {
        try {
          final decodedList = jsonDecode(jsonInput) as List?;
          if (decodedList != null) {
            return decodedList.map((sMap) {
              try {
                if (sMap is Map<String, dynamic>) {
                  return SetPerformance.fromMap(sMap);
                } else { return null; }
              } catch (e) {
                debugPrint("Error decoding single SetPerformance from map: $sMap, Error: $e");
                return null;
              }
            }).whereNotNull().toList();
          }
        } catch (e) {
          debugPrint("Error decoding sets list JSON ('$jsonInput'): $e");
        }
      }
      return []; // Return empty on error
    }
    // --- End Helper ---

    int? restSeconds = map['restPeriodInSeconds'] as int?;

    return ExercisePerformance(
      exerciseName: map['exerciseName'] as String? ?? 'Unknown Exercise',
      // *** FIX: Decode list from JSON string ***
      sets: decodeSetsList(map['sets']),
      restPeriod: restSeconds != null && restSeconds >= 0
          ? Duration(seconds: restSeconds)
          : null, // Handle potential null/negative from DB
    );
  }

  @override
  String toString() {
    return 'ExercisePerformance(name: $exerciseName, sets: ${sets.length})';
  }

  // Equality based on exercise name and deep comparison of set details
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    final listEquals = const DeepCollectionEquality().equals; // Use collection package

    return other is ExercisePerformance &&
        runtimeType == other.runtimeType &&
        exerciseName == other.exerciseName &&
        listEquals(sets, other.sets) && // Deep list comparison
        restPeriod == other.restPeriod;
  }

  @override
  int get hashCode => Object.hash(
    exerciseName,
    const DeepCollectionEquality().hash(sets), // Use deep hash for list
    restPeriod,
  );
}