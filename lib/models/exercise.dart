import 'dart:convert';
import 'package:flutter/material.dart';

enum WorkoutType { Cardio, Weight }

class Exercise {
  String name;
  double weight;
  int sets;
  String reps;
  WorkoutType workoutType;
  Map<String, dynamic> exHistory;

  Exercise({
    required this.name,
    required this.weight,
    required this.sets,
    required this.reps,
    WorkoutType? workoutType,
    Map<String, dynamic>? exHistory,
  })  : workoutType = workoutType ?? WorkoutType.Weight,
        exHistory = exHistory ?? {};

  factory Exercise.deepCopy(Exercise other) => Exercise(
    name: other.name,
    weight: other.weight,
    sets: other.sets,
    reps: other.reps,
    workoutType: other.workoutType,
    exHistory: Map.from(other.exHistory),
  );

  Exercise.fromMap(Map<String, dynamic> map)
      : name = map["name"] ?? '',
        weight = double.parse((map["weight"] ?? '0').toString()),
        sets = int.parse((map["sets"] ?? '0').toString()),
        reps = map["reps"] ?? '',
        workoutType = intToWorkoutTypeConverter(map['workoutType'] ?? 1),
        exHistory = map["history"] == null
            ? {}
            : jsonDecode(map['history']) as Map<String, dynamic>;

  Map<String, dynamic> toMap() => {
    'name': name,
    'weight': weight.toStringAsFixed(1),
    'sets': sets,
    'reps': reps,
    'workoutType': workoutTypeToIntConverter(workoutType),
    'history': jsonEncode(exHistory),
  };

  Exercise.copyFromExercise(Exercise ex)
      : name = ex.name,
        weight = ex.weight,
        sets = ex.sets,
        reps = ex.reps,
        workoutType = ex.workoutType,
        exHistory = Map.from(ex.exHistory);

  Exercise.copyFromExerciseWithoutHistory(Exercise ex)
      : name = ex.name,
        weight = ex.weight,
        sets = ex.sets,
        reps = ex.reps,
        workoutType = ex.workoutType,
        exHistory = {};

  @override
  String toString() {
    return "Instance of Exercise: name: $name";
  }
}

int workoutTypeToIntConverter(WorkoutType wt) {
  switch (wt) {
    case WorkoutType.Cardio:
      return 0;
    case WorkoutType.Weight:
      return 1;
  }
}

WorkoutType intToWorkoutTypeConverter(int i) {
  switch (i) {
    case 0:
      return WorkoutType.Cardio;
    case 1:
      return WorkoutType.Weight;
    default:
      throw Exception('Invalid workout type integer: $i');
  }
}
