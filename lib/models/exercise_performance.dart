// models/exercise_performance.dart

import 'package:flutter/foundation.dart'; // For Object.hash, debugPrint
import 'package:collection/collection.dart'; // For DeepCollectionEquality
// For @immutable

// Assuming these models are correctly defined
import 'package:workout_planner/models/exercise.dart'; // Import Exercise model
import 'package:workout_planner/models/set_performance.dart'; // Import SetPerformance model

/// Tracks the performance details for a single exercise within a WorkoutSession.
/// Corresponds to a record in the 'ExercisePerformances' database table.
@immutable
class ExercisePerformance {
  /// The unique ID from the 'ExercisePerformances' database table (null if not saved yet).
  final int? id;
  final String exerciseName;
  /// The list of sets performed for this exercise during the session.
  /// Populated by DBProviderIO after fetching from 'SetPerformances' table.
  final List<SetPerformance> sets;
  /// The planned rest period after this exercise (if any).
  final Duration? restPeriod;

  const ExercisePerformance({
    this.id, // Nullable ID from DB
    required this.exerciseName,
    required this.sets,
    this.restPeriod,
  });

  /// Creates a new ExercisePerformance instance with updated values.
  ExercisePerformance copyWith({
    int? id,
    String? exerciseName,
    List<SetPerformance>? sets,
    // Allow setting restPeriod to null explicitly
    Object? restPeriod = const _Undefined(),
  }) {
    return ExercisePerformance(
      id: id ?? this.id,
      exerciseName: exerciseName ?? this.exerciseName,
      // If sets list is provided, use it; otherwise keep original list reference
      sets: sets ?? this.sets,
      restPeriod: restPeriod is _Undefined
          ? this.restPeriod
          : restPeriod as Duration?,
    );
  }

  /// Creates an initial ExercisePerformance based on an Exercise definition
  /// when starting a new workout session.
  factory ExercisePerformance.fromExerciseDefinition(Exercise exercise) {
    // Helper logic to parse target reps from the Exercise.reps string
    int targetReps = 0;
    try {
      final repString = exercise.reps.trim().toLowerCase();
      if (repString == 'amrap') {
        targetReps = 0; // Or a special value like -1 if needed
      } else if (repString.contains('-')) {
        targetReps = int.tryParse(repString.split('-').first.trim()) ?? 0;
      } else {
        targetReps = int.tryParse(repString) ?? 0;
      }
    } catch (_) {
      /* Ignore parsing errors, keep targetReps = 0 */
      debugPrint("Could not parse target reps from string: '${exercise.reps}' for exercise '${exercise.name}'");
    }
    targetReps = targetReps.clamp(0, 999); // Clamp to reasonable value

    // Helper logic to parse target weight (assuming Exercise model has 'weight' as double)
    double targetWeight = exercise.weight.clamp(0.0, 9999.0); // Ensure non-negative weight

    // TODO: Get planned restPeriod from Exercise model if it exists
    Duration? plannedRest = const Duration(seconds: 60); // Default rest period

    return ExercisePerformance(
      // ID is null initially, assigned by DB upon saving
      exerciseName: exercise.name,
      // Create list of SetPerformance based on Exercise plan
      sets: List.generate(
        exercise.sets.clamp(1, 100), // Ensure 1 to 100 sets
            (i) => SetPerformance(
          targetReps: targetReps,
          targetWeight: targetWeight,
          // Initial actual values are 0 / false
          actualReps: 0,
          actualWeight: 0.0,
          isCompleted: false,
        ),
        growable: false, // List length is fixed based on plan
      ),
      restPeriod: plannedRest,
    );
  }

  /*
   * NOTE: toMapForDb and fromMap methods are removed because the DBProviderIO
   * uses a normalized schema. It constructs the map for insertion manually
   * and reconstructs the ExercisePerformance object manually after fetching
   * data from multiple tables (ExercisePerformances and SetPerformances).
   */

  @override
  String toString() {
    return 'ExercisePerformance(id: $id, name: $exerciseName, sets: ${sets.length}, rest: $restPeriod)';
  }

  // Equality comparison
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    // Use DeepCollectionEquality for deep comparison of the sets list
    final listEquals = const DeepCollectionEquality().equals;

    return other is ExercisePerformance &&
        runtimeType == other.runtimeType &&
        id == other.id &&
        exerciseName == other.exerciseName &&
        listEquals(sets, other.sets) && // Deep list comparison is important
        restPeriod == other.restPeriod;
  }

  @override
  int get hashCode => Object.hash(
    id,
    exerciseName,
    const DeepCollectionEquality().hash(sets), // Use deep hash for list
    restPeriod,
  );
}

// Helper class for copyWith differentiation when needing to set null explicitly
class _Undefined { const _Undefined(); }