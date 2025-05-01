import 'dart:convert'; // <-- Required for JSON encoding/decoding
import 'package:collection/collection.dart'; // For listEquals in == operator
import 'package:flutter/material.dart'; // Still needed for @immutable
import 'package:flutter/foundation.dart'; // For debugPrint

import 'exercise.dart'; // Import the corrected Exercise class

export 'exercise.dart'; // Keep export if needed

// Enums can stay here or be moved to a central location
enum TargetedBodyPart {
  Abs, Arm, Back, Chest, Leg, Shoulder, FullBody, Tricep, Bicep,
}

enum SetType { Regular, Drop, Super, Tri, Giant }

/// Represents a section or phase within a workout routine (e.g., Warmup, Bench Press Section, Superset).
/// Instances are immutable. Use [copyWith] to create modified versions.
@immutable
class Part {
  final bool defaultName;
  final SetType setType;
  final TargetedBodyPart targetedBodyPart;
  final String partName;
  final List<Exercise> exercises; // List of immutable Exercise objects
  final String additionalNotes;

  /// Creates an immutable Part instance.
  Part({
    required this.setType,
    required this.targetedBodyPart,
    required this.exercises,
    String? partName,
    this.defaultName = false,
    this.additionalNotes = '',
  }) : partName = (partName == null || partName.trim().isEmpty)
      ? _generateDefaultPartName(setType, exercises)
      : partName.trim();

  /// Creates a deep copy of another Part instance.
  factory Part.deepCopy(Part other) {
    return Part(
      setType: other.setType,
      targetedBodyPart: other.targetedBodyPart,
      // Exercise.copyWith handles deep copy of its fields (incl. history)
      exercises: other.exercises.map((ex) => ex.copyWith()).toList(),
      partName: other.partName,
      defaultName: other.defaultName,
      additionalNotes: other.additionalNotes,
    );
  }

  /// Creates a copy of a Part instance, using exercises without their history.
  factory Part.copyFromPartWithoutHistory(Part part) {
    return Part(
        defaultName: part.defaultName,
        setType: part.setType,
        targetedBodyPart: part.targetedBodyPart,
        partName: part.partName,
        additionalNotes: part.additionalNotes,
        // Use the Exercise factory for copying without history
        exercises: part.exercises.map((ex) => Exercise.copyWithoutHistory(ex)).toList()
    );
  }

  /// Generates a default name based on set type and first exercise(s).
  static String _generateDefaultPartName(SetType setType, List<Exercise> exercises) {
    // (Implementation remains the same)
    if (exercises.isEmpty) return 'Unnamed Part';
    switch (setType) {
      case SetType.Regular: case SetType.Drop:
      return exercises[0].name.isNotEmpty ? exercises[0].name : "Exercise";
      case SetType.Super:
        if (exercises.length >= 2) { final name1 = exercises[0].name.isNotEmpty ? exercises[0].name : "Exercise 1"; final name2 = exercises[1].name.isNotEmpty ? exercises[1].name : "Exercise 2"; return '$name1 & $name2'; }
        return exercises[0].name.isNotEmpty ? exercises[0].name : "Exercise";
      case SetType.Tri: final name1 = exercises[0].name.isNotEmpty ? exercises[0].name : "Exercise 1"; return 'Tri-set: $name1...';
      case SetType.Giant: final name1 = exercises[0].name.isNotEmpty ? exercises[0].name : "Exercise 1"; return 'Giant Set: $name1...';
    }
  }

  /// Validates exercises within the Part.
  static bool validateExercises(Part part) {
    // (Implementation remains the same)
    for (var exercise in part.exercises) {
      if (exercise.name.trim().isEmpty) return false;
      if (exercise.reps.trim().isEmpty) return false;
      // Add other validation if needed (sets > 0, weight > 0 for Weight type etc.)
    }
    return true;
  }

  /// Creates a Part instance from a map (e.g., from JSON/database).
  /// Handles decoding of the 'exercises' list from a JSON string.
  factory Part.fromMap(Map<String, dynamic> map) {
    // --- Helper function to safely decode the list of Exercises ---
    List<Exercise> decodeExercisesList(dynamic jsonInput) {
      if (jsonInput is String && jsonInput.isNotEmpty) {
        try {
          final decodedList = jsonDecode(jsonInput) as List?;
          if (decodedList != null) {
            // ** CRITICAL: Assumes Exercise.fromMap exists and works **
            return decodedList
                .map((exMap) {
              try {
                // Ensure item is a Map before passing to Exercise.fromMap
                if (exMap is Map<String, dynamic>) {
                  return Exercise.fromMap(exMap);
                } else {
                  debugPrint("Skipping non-map item in exercises list: $exMap");
                  return null;
                }
              } catch (e) {
                debugPrint("Error decoding single Exercise from map: $exMap, Error: $e");
                return null;
              }
            })
                .whereNotNull() // Filter out nulls from failed parsing
                .whereType<Exercise>() // Ensure type safety
                .toList();
          }
        } catch (e) {
          debugPrint("Error decoding exercises list JSON ('$jsonInput'): $e");
        }
      } else if (jsonInput is List) {
        // Allow fallback if data is already a List<Map> (e.g. from direct JSON)
        debugPrint("Warning: Decoding exercises from List instead of JSON string.");
        return jsonInput
            .whereType<Map<String, dynamic>>() // Ensure we only process Maps
            .map((exMap) => Exercise.fromMap(exMap))
            .whereNotNull()
            .toList();
      }
      return <Exercise>[]; // Return empty typed list on error or invalid input
    }
    // --- End Helper ---


    // Parse exercises first using the new helper
    List<Exercise> parsedExercises = decodeExercisesList(map['exercises']);

    SetType setType = _parseSetType(map['setType'], SetType.Regular);
    TargetedBodyPart bodyPart = _parseTargetedBodyPart(map['bodyPart'], TargetedBodyPart.FullBody);

    String? nameFromMap = map['partName'] as String?;
    bool useDefault = (nameFromMap == null || nameFromMap.trim().isEmpty);

    return Part(
      // Use null-aware operator ?? for potential nulls from DB/map
      defaultName: map['isDefaultName'] as bool? ?? useDefault,
      setType: setType,
      targetedBodyPart: bodyPart,
      additionalNotes: map['notes'] as String? ?? '',
      // Use the parsed exercises list
      exercises: parsedExercises,
      // Determine name based on whether it was parsed or needs default generation
      partName: useDefault ? _generateDefaultPartName(setType, parsedExercises) : nameFromMap.trim(),
    );
  }

  /// Converts the Part instance to a map for serialization (e.g., to Sqflite).
  /// Encodes the 'exercises' list into a JSON string.
  Map<String, dynamic> toMap() {
    // ** CRITICAL: Assumes Exercise.toMap() exists and works correctly **
    String encodedExercises = '[]'; // Default empty JSON array
    try {
      encodedExercises = jsonEncode(exercises.map((e) => e.toMap()).toList());
    } catch (e) {
      debugPrint("Error encoding exercises list to JSON in Part '$partName': $e");
      // Handle error: save empty string? throw?
    }

    return {
      'isDefaultName': defaultName,
      'setType': setType.name, // Store enum name (String)
      'bodyPart': targetedBodyPart.name, // Store enum name (String)
      'notes': additionalNotes,
      // *** FIX: Store exercises as JSON encoded string ***
      'exercises': encodedExercises,
      'partName': partName,
    };
  }

  /// Creates a new Part instance with specified fields updated.
  Part copyWith({
    bool? defaultName,
    SetType? setType,
    TargetedBodyPart? targetedBodyPart,
    String? partName,
    List<Exercise>? exercises, // If updating exercises, pass the new list
    String? additionalNotes,
  }) {
    // --- Name Generation Logic (remains mostly the same) ---
    final newSetType = setType ?? this.setType;
    // Use passed exercises if provided, otherwise keep existing (immutable)
    final newExercises = exercises ?? this.exercises;
    final newPartNameProvided = partName != null;
    // Check against default name generated from *original* type/exercises if name wasn't provided
    final currentNameIsPotentiallyDefault = this.partName == _generateDefaultPartName(this.setType, this.exercises);

    String resultingPartName;
    bool resultingDefaultName;

    if (newPartNameProvided) {
      resultingPartName = partName.trim();
      resultingDefaultName = false; // Explicitly set name is not default
    } else {
      // Regenerate name if type/exercises changed OR if current name *was* the default
      bool needsRegeneration = (setType != null && setType != this.setType) ||
          (exercises != null && !const ListEquality().equals(exercises, this.exercises));

      if (currentNameIsPotentiallyDefault || needsRegeneration) {
        resultingPartName = _generateDefaultPartName(newSetType, newExercises);
        resultingDefaultName = true; // Newly generated name is default
      } else {
        resultingPartName = this.partName; // Keep existing non-default name
        resultingDefaultName = this.defaultName; // Keep original default flag
      }
    }
    // --- End Name Generation Logic ---

    return Part(
      // Override fields if provided, otherwise use existing value
      defaultName: defaultName ?? resultingDefaultName,
      setType: newSetType,
      targetedBodyPart: targetedBodyPart ?? this.targetedBodyPart,
      partName: resultingPartName, // Use calculated name
      // If 'exercises' list was passed to copyWith, use it directly
      // Otherwise, keep the original list reference (safe because immutable)
      exercises: newExercises,
      additionalNotes: additionalNotes ?? this.additionalNotes,
    );
  }


  @override
  String toString() {
    return 'Part(name: $partName, type: ${setType.name}, bodyPart: ${targetedBodyPart.name}, exercises: ${exercises.length})';
  }

  // Use DeepCollectionEquality for lists
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    final listEquals = const DeepCollectionEquality().equals;

    return other is Part &&
        runtimeType == other.runtimeType && // Added runtimeType check
        other.defaultName == defaultName &&
        other.setType == setType &&
        other.targetedBodyPart == targetedBodyPart &&
        other.partName == partName &&
        listEquals(other.exercises, exercises) && // Deep list comparison
        other.additionalNotes == additionalNotes;
  }

  // Use DeepCollectionEquality for lists
  @override
  int get hashCode => Object.hash(
    defaultName,
    setType,
    targetedBodyPart,
    partName,
    const DeepCollectionEquality().hash(exercises), // Deep hash for exercises list
    additionalNotes,
  );

  // --- Private Helper Functions for Enum Parsing ---
  static SetType _parseSetType(dynamic value, SetType defaultValue) {
    if (value is String) { try { return SetType.values.byName(value); } catch (_) {} }
    if (value is int) { if (value >= 0 && value < SetType.values.length) return SetType.values[value]; }
    return defaultValue;
  }
  static TargetedBodyPart _parseTargetedBodyPart(dynamic value, TargetedBodyPart defaultValue) {
    if (value is String) { try { return TargetedBodyPart.values.byName(value); } catch (_) {} }
    if (value is int) { if (value >= 0 && value < TargetedBodyPart.values.length) return TargetedBodyPart.values[value]; }
    return defaultValue;
  }
}
