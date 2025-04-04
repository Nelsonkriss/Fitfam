import 'package:flutter/material.dart';
import 'exercise.dart';

export 'exercise.dart';

enum TargetedBodyPart {
  Abs,
  Arm,
  Back,
  Chest,
  Leg,
  Shoulder,
  FullBody,
  Tricep,
  Bicep,
}

enum SetType { Regular, Drop, Super, Tri, Giant }

class Part {
  bool defaultName;
  SetType setType;
  TargetedBodyPart targetedBodyPart;
  String partName;
  List<Exercise> exercises;
  String additionalNotes;

  factory Part.deepCopy(Part other) => Part(
    setType: other.setType,
    targetedBodyPart: other.targetedBodyPart,
    exercises: other.exercises.map((ex) => Exercise.deepCopy(ex)).toList(),
    partName: other.partName,
    defaultName: other.defaultName,
    additionalNotes: other.additionalNotes,
  );

  Part({
    required this.setType,
    required this.targetedBodyPart,
    required this.exercises,
    String? partName,
    this.defaultName = false,
    String? additionalNotes,
  })  : additionalNotes = additionalNotes ?? '',
        partName = (partName == null || partName.trim().isEmpty)
            ? _generateDefaultPartName(setType, exercises)
            : partName;

  static String _generateDefaultPartName(SetType setType, List<Exercise> exercises) {
    if (exercises.isEmpty) return '';
    switch (setType) {
      case SetType.Regular:
      case SetType.Drop:
        return exercises[0].name;
      case SetType.Super:
        return exercises.length >= 2
            ? '${exercises[0].name} and ${exercises[1].name}'
            : exercises[0].name;
      case SetType.Tri:
        return 'Tri-set of ${exercises[0].name} and more';
      case SetType.Giant:
        return 'Giant Set of ${exercises[0].name} and more';
    }
  }

  /// Validates that required fields in exercises are non-empty.
  static Map<bool, String> checkIfAnyNull(Part part) {
    for (var exercise in part.exercises) {
      if (exercise.name.trim().isEmpty) {
        return {false: 'Please complete the names of exercises.'};
      }
      if (exercise.reps.trim().isEmpty) {
        return {false: 'Reps of exercises need to be defined.'};
      }
      // If a zero value for sets or weight is considered invalid,
      // add checks here accordingly.
    }
    return {true: ''};
  }

  Part.fromMap(Map<String, dynamic> map)
      : defaultName = map["isDefaultName"] ?? false,
        setType = intToSetTypeConverter(map['setType']),
        targetedBodyPart = intToTargetedBodyPartConverter(map['bodyPart']),
        additionalNotes = map['notes'] ?? '',
        exercises = (map['exercises'] as List)
            .map((e) => Exercise.fromMap(e as Map<String, dynamic>))
            .toList(),
        partName = (map['partName'] != null && (map['partName'] as String).trim().isNotEmpty)
            ? map['partName']
            : _generateDefaultPartName(
            intToSetTypeConverter(map['setType']),
            (map['exercises'] as List)
                .map((e) => Exercise.fromMap(e as Map<String, dynamic>))
                .toList());

  Map<String, dynamic> toMap() {
    return {
      'isDefaultName': defaultName,
      'setType': setTypeToIntConverter(setType),
      'bodyPart': targetedBodyPartToIntConverter(targetedBodyPart),
      'notes': additionalNotes,
      'exercises': exercises.map((e) => e.toMap()).toList(),
      'partName': partName,
    };
  }

  Part.copyFromPart(Part part)
      : defaultName = part.defaultName,
        setType = part.setType,
        targetedBodyPart = part.targetedBodyPart,
        partName = part.partName,
        additionalNotes = part.additionalNotes,
        exercises = part.exercises.map((ex) => Exercise.copyFromExercise(ex)).toList();

  Part.copyFromPartWithoutHistory(Part part)
      : defaultName = part.defaultName,
        setType = part.setType,
        targetedBodyPart = part.targetedBodyPart,
        partName = part.partName,
        additionalNotes = part.additionalNotes,
        exercises = part.exercises
            .map((ex) => Exercise.copyFromExerciseWithoutHistory(ex))
            .toList();

  @override
  String toString() {
    return exercises.toString();
  }
}

int setTypeToIntConverter(SetType setType) {
  switch (setType) {
    case SetType.Regular:
      return 0;
    case SetType.Drop:
      return 1;
    case SetType.Super:
      return 2;
    case SetType.Tri:
      return 3;
    case SetType.Giant:
      return 4;
  }
}

SetType intToSetTypeConverter(int i) {
  switch (i) {
    case 0:
      return SetType.Regular;
    case 1:
      return SetType.Drop;
    case 2:
      return SetType.Super;
    case 3:
      return SetType.Tri;
    case 4:
      return SetType.Giant;
    default:
      throw Exception("Inside intToSetTypeConverter, i is $i");
  }
}

TargetedBodyPart intToTargetedBodyPartConverter(int i) {
  switch (i) {
    case 0:
      return TargetedBodyPart.Abs;
    case 1:
      return TargetedBodyPart.Arm;
    case 2:
      return TargetedBodyPart.Back;
    case 3:
      return TargetedBodyPart.Chest;
    case 4:
      return TargetedBodyPart.Leg;
    case 5:
      return TargetedBodyPart.Shoulder;
    case 6:
      return TargetedBodyPart.FullBody;
    case 7:
      return TargetedBodyPart.Tricep;
    case 8:
      return TargetedBodyPart.Bicep;
    default:
      throw Exception("Inside intToTargetedBodyPartConverter, i is $i");
  }
}

int targetedBodyPartToIntConverter(TargetedBodyPart tb) {
  switch (tb) {
    case TargetedBodyPart.Abs:
      return 0;
    case TargetedBodyPart.Arm:
      return 1;
    case TargetedBodyPart.Back:
      return 2;
    case TargetedBodyPart.Chest:
      return 3;
    case TargetedBodyPart.Leg:
      return 4;
    case TargetedBodyPart.Shoulder:
      return 5;
    case TargetedBodyPart.FullBody:
      return 6;
    case TargetedBodyPart.Tricep:
      return 7;
    case TargetedBodyPart.Bicep:
      return 8;
  }
}
