import 'package:meta/meta.dart'; // For @immutable
import 'package:flutter/foundation.dart'; // For Object.hash

// --- No dart:convert needed here ---

/// Tracks the performance details for a single set within an ExercisePerformance.
@immutable // Make the class immutable where possible, though some fields are mutable for tracking
class SetPerformance {
  // Fields representing the *actual* performance are mutable during a session
  final int actualReps;
  final double actualWeight;
  final bool isCompleted;

  // Fields representing the *target* are typically fixed for the session
  final int targetReps;
  final double targetWeight;

  /// Creates an instance of SetPerformance.
  const SetPerformance({ // Make constructor const
    this.actualReps = 0,
    this.actualWeight = 0.0,
    required this.targetReps,
    required this.targetWeight,
    this.isCompleted = false,
  });

  /// Creates a new SetPerformance instance with updated values.
  /// Needed because some fields track mutable state during a workout.
  SetPerformance copyWith({
    int? actualReps,
    double? actualWeight,
    int? targetReps,
    double? targetWeight,
    bool? isCompleted,
  }) {
    return SetPerformance(
      actualReps: actualReps ?? this.actualReps,
      actualWeight: actualWeight ?? this.actualWeight,
      targetReps: targetReps ?? this.targetReps,
      targetWeight: targetWeight ?? this.targetWeight,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }


  /// Serializes the SetPerformance state to a Map suitable for JSON encoding.
  /// All values are primitive types compatible with JSON.
  Map<String, dynamic> toMap() {
    return {
      'actualReps': actualReps,
      'actualWeight': actualWeight,
      'targetReps': targetReps,
      'targetWeight': targetWeight,
      'isCompleted': isCompleted, // Booleans are valid JSON types
    };
  }

  /// Creates a SetPerformance instance from a Map (typically after JSON decoding).
  factory SetPerformance.fromMap(Map<String, dynamic> map) {
    return SetPerformance(
      actualReps: map['actualReps'] as int? ?? 0,
      actualWeight: (map['actualWeight'] as num?)?.toDouble() ?? 0.0,
      targetReps: map['targetReps'] as int? ?? 0,
      targetWeight: (map['targetWeight'] as num?)?.toDouble() ?? 0.0,
      isCompleted: map['isCompleted'] as bool? ?? false,
    );
  }

  @override
  String toString() {
    return 'Set(target: ${targetWeight}kg x $targetReps, actual: ${actualWeight}kg x $actualReps, completed: $isCompleted)';
  }

  // Equality based on all fields
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is SetPerformance &&
        runtimeType == other.runtimeType &&
        actualReps == other.actualReps &&
        actualWeight == other.actualWeight &&
        targetReps == other.targetReps &&
        targetWeight == other.targetWeight &&
        isCompleted == other.isCompleted;
  }

  @override
  int get hashCode => Object.hash(
    actualReps,
    actualWeight,
    targetReps,
    targetWeight,
    isCompleted,
  );
}