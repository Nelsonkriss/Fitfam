import 'dart:convert'; // Import dart:convert for JSON handling
import 'package:collection/collection.dart'; // For listEquals and hashAll
import 'package:flutter/foundation.dart'; // For debugPrint

// Assuming these models are defined correctly and handle their own toMap/fromMap
import 'package:workout_planner/models/main_targeted_body_part.dart';
import 'part.dart'; // ** ACTION REQUIRED: Ensure Part model handles JSON for 'exercises' list **

export 'part.dart'; // Keep export if needed

/// Represents a workout routine template.
/// Instances are immutable. Use [copyWith] to create modified versions.
@immutable // Mark as immutable
class Routine {
  final int? id;
  final String routineName;
  final MainTargetedBodyPart mainTargetedBodyPart;
  final List<Part> parts; // List of Part objects
  final DateTime createdDate;
  final DateTime? lastCompletedDate;
  final int completionCount;
  final List<int> weekdays; // List of integers
  final List<int> routineHistory; // List of integers (e.g., timestamps)

  /// Creates an immutable Routine instance.
  Routine({
    this.id,
    required this.routineName,
    required this.mainTargetedBodyPart,
    required this.parts,
    required this.createdDate,
    this.lastCompletedDate,
    this.completionCount = 0,
    List<int>? weekdays,
    List<int>? routineHistory,
  })  : weekdays = weekdays ?? const [], // Use const empty lists as default
        routineHistory = routineHistory ?? const [];

  /// Creates a new Routine instance with specified fields updated.
  /// Performs deep copies for lists to maintain immutability.
  Routine copyWith({
    int? id,
    String? routineName,
    MainTargetedBodyPart? mainTargetedBodyPart,
    List<Part>? parts, // If updating parts, pass the new list
    DateTime? createdDate,
    DateTime? lastCompletedDate,
    bool clearLastCompletedDate = false, // Flag to explicitly set to null
    int? completionCount,
    List<int>? weekdays,
    List<int>? routineHistory,
  }) {
    return Routine(
      // Use ?? operator for optional overrides
      id: id ?? this.id,
      routineName: routineName ?? this.routineName,
      mainTargetedBodyPart: mainTargetedBodyPart ?? this.mainTargetedBodyPart,
      // If 'parts' is provided, assume it's the complete new list (already copied if needed)
      // If not provided, keep the existing list reference (it's immutable)
      parts: parts ?? this.parts,
      createdDate: createdDate ?? this.createdDate,
      lastCompletedDate: clearLastCompletedDate ? null : (lastCompletedDate ?? this.lastCompletedDate),
      completionCount: completionCount ?? this.completionCount,
      // Create new list instances only if new lists are provided
      weekdays: weekdays != null ? List<int>.from(weekdays) : this.weekdays,
      routineHistory: routineHistory != null ? List<int>.from(routineHistory) : this.routineHistory,
    );
  }

  /// Serializes the Routine to a Map suitable for DB insertion (e.g., Sqflite).
  /// Encodes lists (`parts`, `weekdays`, `routineHistory`) into JSON strings for TEXT columns.
  Map<String, dynamic> toMapForDb() { // Renamed for clarity
    // ** CRITICAL: Assumes Part.toMap() exists and works correctly **
    // ** including encoding its own 'exercises' list if necessary **
    String encodedParts = '[]'; // Default to empty JSON array
    try {
      encodedParts = jsonEncode(parts.map((p) => p.toMap()).toList());
    } catch (e) {
      debugPrint("Error encoding parts list to JSON: $e");
      // Decide how to handle error: throw? save empty? save partial?
      // Saving empty might be safest to avoid DB constraint errors
    }

    return {
      // ID is usually handled by DB auto-increment, exclude from map for INSERT
      // 'id': id,
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
    List<T> _decodeJsonList<T>(dynamic jsonInput) {
      if (jsonInput is String && jsonInput.isNotEmpty) {
        try {
          final decoded = jsonDecode(jsonInput);
          if (decoded is List) {
            // Handle type casting properly with explicit List<T> return
            if (T == int) {
              return decoded.map((item) => item as int).toList() as List<T>;
            }
            if (T == String) {
              return decoded.map((item) => item as String).toList() as List<T>;
            }
            // Add other simple types if needed
            // For complex types, further mapping is needed after decoding
            return decoded.whereType<T>().toList(); // General fallback for other types
          }
        } catch (e) {
          debugPrint("Error decoding list JSON ('$jsonInput'): $e");
        }
      }
      return <T>[]; // Return empty list on error or invalid input
    }

    List<Part> _decodePartsList(dynamic jsonInput) {
      if (jsonInput is String && jsonInput.isNotEmpty) {
        try {
          final decodedList = jsonDecode(jsonInput) as List?;
          if (decodedList != null) {
            // ** CRITICAL: Assumes Part.fromMap exists and handles its nested 'exercises' list **
            return decodedList
                .map((p) {
              try {
                // Ensure the item 'p' is actually a Map before casting
                if (p is Map<String, dynamic>) {
                  return Part.fromMap(p);
                } else {
                  debugPrint("Skipping non-map item in parts list: $p");
                  return null;
                }
              } catch (e) {
                debugPrint("Error decoding single Part from map: $p, Error: $e");
                return null;
              }
            })
                .whereNotNull() // Filter out nulls from failed parsing
                .toList();
          }
        } catch (e) {
          debugPrint("Error decoding parts list JSON ('$jsonInput'): $e");
        }
      }
      return []; // Return empty list on error or invalid input
    }

    DateTime? _parseOptionalDate(dynamic value) {
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }
    // --- End Helper Functions ---


    // Parse MainTargetedBodyPart from stored index
    MainTargetedBodyPart bodyPart = MainTargetedBodyPart.FullBody; // Sensible default
    if (map['mainTargetedBodyPart'] is int) {
      int index = map['mainTargetedBodyPart'];
      if (index >= 0 && index < MainTargetedBodyPart.values.length) {
        bodyPart = MainTargetedBodyPart.values[index];
      } else { debugPrint("Warning: Invalid index ${map['mainTargetedBodyPart']} for MainTargetedBodyPart."); }
    } else if (map['mainTargetedBodyPart'] != null) { debugPrint("Warning: Expected integer for mainTargetedBodyPart, got ${map['mainTargetedBodyPart'].runtimeType}."); }


    return Routine(
      // Safely cast ID
      id: map['id'] as int?,
      routineName: map['routineName'] as String? ?? 'Unnamed Routine',
      mainTargetedBodyPart: bodyPart,
      // Decode JSON strings back into lists
      parts: _decodePartsList(map['parts']),
      createdDate: _parseOptionalDate(map['createdDate']) ?? DateTime.now(), // Default createdDate if parsing fails
      lastCompletedDate: _parseOptionalDate(map['lastCompletedDate']),
      completionCount: map['completionCount'] as int? ?? 0,
      weekdays: _decodeJsonList<int>(map['weekdays']),
      routineHistory: _decodeJsonList<int>(map['routineHistory']),
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