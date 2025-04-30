import 'dart:convert';
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:collection/collection.dart'; // For potential mapEquals if needed

/// Represents the type of workout an exercise belongs to.
enum WorkoutType { Cardio, Weight }

/// Represents a single exercise within a workout plan.
/// Immutable. Use [copyWith] to create modified instances.
@immutable // Added for consistency
class Exercise {
  final String name;
  final double weight;
  final int sets;
  final String reps;
  final WorkoutType workoutType;
  final Map<String, dynamic> exHistory; // Keys: Date String, Values: String or Map

  /// Creates an immutable instance of [Exercise].
  const Exercise({ // Make constructor const
    required this.name,
    required this.weight,
    required this.sets,
    required this.reps,
    this.workoutType = WorkoutType.Weight,
    Map<String, dynamic>? exHistory,
  }) : exHistory = exHistory ?? const {}; // Use const empty map

  /// Creates a new Exercise instance with specified fields updated.
  Exercise copyWith({
    String? name,
    double? weight,
    int? sets,
    String? reps,
    WorkoutType? workoutType,
    Map<String, dynamic>? exHistory,
  }) {
    return Exercise(
      name: name ?? this.name,
      weight: weight ?? this.weight,
      sets: sets ?? this.sets,
      reps: reps ?? this.reps,
      workoutType: workoutType ?? this.workoutType,
      // Deep copy history map if provided, otherwise keep current
      exHistory: exHistory ?? Map<String, dynamic>.from(this.exHistory),
    );
  }

  /// Creates an Exercise instance from a map (e.g., from JSON/database).
  factory Exercise.fromMap(Map<String, dynamic> map) {
    // --- Helper to decode History ---
    Map<String, dynamic> _decodeHistory(dynamic historyInput) {
      if (historyInput is String && historyInput.isNotEmpty) {
        try {
          final decoded = jsonDecode(historyInput);
          // Ensure decoded result is actually a Map<String, dynamic>
          if (decoded is Map) {
            // Need to cast keys and values if necessary, Map.from ensures String keys
            return Map<String, dynamic>.from(decoded);
          }
        } catch (e) {
          debugPrint('Error decoding exercise history JSON for ${map["name"]}: $e');
        }
      } else if (historyInput is Map) {
        // Already a map, ensure keys are strings
        return Map<String, dynamic>.from(historyInput);
      }
      return {}; // Return empty map on error or invalid input
    }
    // --- End Helper ---

    // --- Helper to parse WorkoutType ---
    WorkoutType _parseWorkoutType(dynamic value, WorkoutType defaultValue) {
      if (value is String) { try { return WorkoutType.values.byName(value); } catch (_) {} }
      if (value is int) { // Fallback for old integer format
        debugPrint('Warning: workoutType stored as int for ${map["name"]}, migrating to String is recommended.');
        if (value == 0) return WorkoutType.Cardio;
        if (value == 1) return WorkoutType.Weight;
      }
      return defaultValue;
    }
    // --- End Helper ---


    return Exercise(
      name: map['name'] as String? ?? '',
      // Use tryParse for robust number conversion, provide defaults
      weight: double.tryParse(map['weight']?.toString() ?? '0.0') ?? 0.0,
      sets: int.tryParse(map['sets']?.toString() ?? '0') ?? 0,
      reps: map['reps'] as String? ?? '',
      // Parse workout type using helper
      workoutType: _parseWorkoutType(map['workoutType'], WorkoutType.Weight),
      // Decode history using helper
      exHistory: _decodeHistory(map['history']),
    );
  }

  /// Converts the Exercise instance to a map suitable for JSON/database storage.
  /// Encodes the history map into a JSON string.
  Map<String, dynamic> toMap() => {
    'name': name,
    'weight': weight, // Store as number
    'sets': sets,     // Store as number
    'reps': reps,
    'workoutType': workoutType.name, // Store enum name as String
    // *** Correctly encodes history map to JSON string ***
    'history': jsonEncode(exHistory),
  };

  /// Creates a copy of an Exercise instance without its history.
  factory Exercise.copyWithoutHistory(Exercise other) {
    return Exercise(
      name: other.name,
      weight: other.weight,
      sets: other.sets,
      reps: other.reps,
      workoutType: other.workoutType,
      exHistory: const {}, // Use const empty map
    );
  }

  @override
  String toString() {
    return 'Exercise(name: $name, weight: $weight, sets: $sets, reps: $reps, type: ${workoutType.name}, history: ${exHistory.length} entries)';
  }

  // Equality operator comparing core fields (history omitted for performance)
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    // Use DeepCollectionEquality().equals(exHistory, other.exHistory) for deep history comparison if needed

    return other is Exercise &&
        runtimeType == other.runtimeType &&
        other.name == name &&
        other.weight == weight &&
        other.sets == sets &&
        other.reps == reps &&
        other.workoutType == workoutType;
  }

  // Hash code based on core fields
  @override
  int get hashCode => Object.hash(
    name,
    weight,
    sets,
    reps,
    workoutType,
    // Use DeepCollectionEquality().hash(exHistory) if history is included in ==
  );
}