import 'package:flutter/material.dart';
import 'package:workout_planner/models/main_targeted_body_part.dart';
import 'part.dart';

export 'part.dart';

class Routine {
  MainTargetedBodyPart mainTargetedBodyPart;
  List<int> routineHistory;
  List<int> weekdays;
  String routineName;
  List<Part> parts;
  DateTime lastCompletedDate;
  DateTime createdDate;
  int completionCount;
  int? id;

  Routine({
    required this.mainTargetedBodyPart,
    required this.routineName,
    required this.parts,
    required this.createdDate,
    DateTime? lastCompletedDate,
    this.weekdays = const [],
    this.routineHistory = const [], 
    this.completionCount = 0,
    this.id,
  }) : lastCompletedDate = lastCompletedDate ?? DateTime.now();

  factory Routine.deepCopy(Routine other) => Routine(
    mainTargetedBodyPart: other.mainTargetedBodyPart,
    routineName: other.routineName,
    parts: other.parts.map((p) => Part.deepCopy(p)).toList(),
    createdDate: other.createdDate,
    lastCompletedDate: other.lastCompletedDate,
    weekdays: List.from(other.weekdays),
    routineHistory: List.from(other.routineHistory),
    completionCount: other.completionCount,
    id: other.id,
  );

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'routineName': routineName,
      'mainTargetedBodyPart': mainTargetedBodyPart.index,
      'parts': parts.map((p) => p.toMap()).toList(),
      'createdDate': createdDate.toIso8601String(),
      'lastCompletedDate': lastCompletedDate.toIso8601String(),
      'completionCount': completionCount,
      'weekdays': weekdays,
      'routineHistory': routineHistory,
    };
  }

  factory Routine.fromMap(Map<String, dynamic> map) {
    return Routine(
      id: map['id'] as int?,
      routineName: (map['routineName'] as String?) ?? 'Unnamed Routine',
      mainTargetedBodyPart: MainTargetedBodyPart.values[
        (map['mainTargetedBodyPart'] as int?) ?? 0
      ],
      parts: (map['parts'] as List? ?? []).map((p) => Part.fromMap(p)).toList(),
      createdDate: _parseDateTime(map['createdDate']),
      lastCompletedDate: _parseDateTime(map['lastCompletedDate']),
      completionCount: (map['completionCount'] as int?) ?? 0,
      weekdays: (map['weekdays'] as List? ?? []).cast<int>(),
      routineHistory: (map['routineHistory'] as List? ?? []).cast<int>(),
    );
  }

  @override
  String toString() {
    return 'Routine(id: $id, name: $routineName)';
  }

  static DateTime _parseDateTime(dynamic date) {
    try {
      return DateTime.parse(date as String);
    } catch (e) {
      return DateTime.now();
    }
  }
}

// Define MainTargetedBodyPart enum in separate file
