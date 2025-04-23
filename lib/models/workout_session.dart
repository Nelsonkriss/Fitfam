import 'package:flutter/material.dart';
import 'package:workout_planner/models/routine.dart';
import 'package:workout_planner/models/exercise.dart';

class WorkoutSession {
  final String id;
  final Routine routine;
  final DateTime startTime;
  DateTime? endTime;
  bool isCompleted;
  List<ExercisePerformance> exercises;

  WorkoutSession({
    required this.routine,
    required this.startTime,
    this.endTime,
    this.isCompleted = false,
    List<ExercisePerformance>? exercises,
  }) : 
    id = DateTime.now().millisecondsSinceEpoch.toString(),
    exercises = exercises ?? _createDefaultPerformances(routine);

  static List<ExercisePerformance> _createDefaultPerformances(Routine routine) {
    return routine.parts.expand((part) => part.exercises.map((exercise) => 
      ExercisePerformance.fromExercise(exercise)
    )).toList();
  }

  Duration get duration => endTime != null 
    ? endTime!.difference(startTime)
    : DateTime.now().difference(startTime);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'routineId': routine.id,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'isCompleted': isCompleted,
      'exercises': exercises.map((e) => e.toMap()).toList(),
    };
  }

  factory WorkoutSession.fromMap(Map<String, dynamic> map, Routine routine) {
    return WorkoutSession(
      routine: routine,
      startTime: DateTime.parse(map['startTime']),
      endTime: map['endTime'] != null ? DateTime.parse(map['endTime']) : null,
      isCompleted: map['isCompleted'],
      exercises: (map['exercises'] as List)
        .map((e) => ExercisePerformance.fromMap(e))
        .toList(),
    );
  }
}

class ExercisePerformance {
  final String exerciseName;
  final List<SetPerformance> sets;
  Duration? restPeriod;

  ExercisePerformance({
    required this.exerciseName,
    required this.sets,
    this.restPeriod,
  });

  factory ExercisePerformance.fromExercise(Exercise exercise) {
    return ExercisePerformance(
      exerciseName: exercise.name,
      sets: List.generate(int.parse(exercise.sets.toString()), (i) => SetPerformance(
        targetReps: int.tryParse(exercise.reps.toString()) ?? 12,
        targetWeight: double.tryParse(exercise.weight.toString()) ?? 20.0,
      )),
      restPeriod: const Duration(seconds: 60),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'exerciseName': exerciseName,
      'sets': sets.map((s) => s.toMap()).toList(),
      'restPeriod': restPeriod?.inSeconds,
    };
  }

  factory ExercisePerformance.fromMap(Map<String, dynamic> map) {
    return ExercisePerformance(
      exerciseName: (map['exerciseName'] as String?)?.trim() ?? 'Unknown Exercise',
      sets: (map['sets'] as List)
        .map((s) => SetPerformance.fromMap(s))
        .toList(),
      restPeriod: map['restPeriod'] != null 
        ? Duration(seconds: map['restPeriod'])
        : null,
    );
  }
}

class SetPerformance {
  int actualReps;
  double actualWeight;
  final int targetReps;
  final double targetWeight;
  bool isCompleted;

  SetPerformance({
    this.actualReps = 0,
    this.actualWeight = 0,
    required this.targetReps,
    required this.targetWeight,
    this.isCompleted = false,
  }) :
    assert(targetReps != null, 'targetReps must not be null'),
    assert(targetWeight != null, 'targetWeight must not be null');

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
      actualReps: map['actualReps'],
      actualWeight: map['actualWeight'],
      targetReps: map['targetReps'],
      targetWeight: map['targetWeight'],
      isCompleted: map['isCompleted'],
    );
  }
}