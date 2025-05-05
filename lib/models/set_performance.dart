// models/set_performance.dart

import 'package:meta/meta.dart'; // For @immutable
import 'package:flutter/foundation.dart'; // For Object.hash

/// Tracks the performance details for a single set within an ExercisePerformance.
@immutable
class SetPerformance {
  // Fields representing the *actual* performance
  final int actualReps;
  final double actualWeight;
  final bool isCompleted;

  // Fields representing the *target*
  final int targetReps;
  final double targetWeight;

  /// Creates an instance of SetPerformance.
  const SetPerformance({
    this.actualReps = 0,
    this.actualWeight = 0.0,
    required this.targetReps,
    required this.targetWeight,
    this.isCompleted = false,
  });

  /// Creates a new SetPerformance instance with updated values.
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

  /*
   * NOTE: toMap and fromMap are not strictly needed for the normalized DB schema
   * where SetPerformance data is directly inserted/retrieved field by field
   * by DBProviderIO. They are kept here for potential other uses (e.g., debugging).
   */
  Map<String, dynamic> toMap() {
    return {
      'actualReps': actualReps,
      'actualWeight': actualWeight,
      'targetReps': targetReps,
      'targetWeight': targetWeight,
      'isCompleted': isCompleted,
    };
  }

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