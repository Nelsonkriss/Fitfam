import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:workout_planner/models/user_profile.dart';
import 'package:workout_planner/resource/shared_prefs_provider.dart';
import 'package:workout_planner/resource/db_provider.dart';
import 'package:workout_planner/models/workout_session.dart';

/// Lightweight AI-style recommender for reps/seconds
/// Heuristics use profile + last history to produce a sensible target.
class AIRepTimeRecommendationService {
  static final AIRepTimeRecommendationService _singleton = AIRepTimeRecommendationService._internal();
  factory AIRepTimeRecommendationService() => _singleton;
  AIRepTimeRecommendationService._internal();

  List<WorkoutSession>? _sessionsCache;

  Future<int> recommendReps({
    required String exerciseName,
    required UserProfile? userProfile,
  }) async {
    try {
      final targetRpe = await sharedPrefsProvider.getTargetRPE();
      final history = await _getExerciseHistory(exerciseName);
      int base = _baseRepsForLevel(userProfile?.fitnessLevel);

      if (history.isNotEmpty) {
        // Use average of last 3 sets if present
        final last = history.take(3).toList();
        final avg = last.map((e) => e.reps).fold<int>(0, (a, b) => a + b) / last.length;
        base = avg.round();
      }
      // Adjust by RPE preference: higher RPE -> slightly lower reps (harder)
      if (targetRpe >= 9) base = max(6, base - 2);
      if (targetRpe <= 7) base = min(20, base + 2);
      return base.clamp(6, 30);
    } catch (e) {
      debugPrint('[AIRepTime] recommendReps error: $e');
      return _baseRepsForLevel(userProfile?.fitnessLevel);
    }
  }

  Future<int> recommendSeconds({
    required String exerciseName,
    required UserProfile? userProfile,
  }) async {
    try {
      final level = userProfile?.fitnessLevel;
      int base = switch (level) {
        FitnessLevel.advanced => 45,
        FitnessLevel.intermediate => 40,
        _ => 30,
      };
      // If there is history with actual reps used as a proxy for time (if logged that way)
      final history = await _getExerciseHistory(exerciseName);
      if (history.isNotEmpty) {
        // Some users log time as reps (seconds) for timed work; cap to 90
        final last = history.first.reps;
        if (last > 0) base = last.clamp(15, 90);
      }
      return base;
    } catch (e) {
      debugPrint('[AIRepTime] recommendSeconds error: $e');
      return 30;
    }
  }

  int _baseRepsForLevel(FitnessLevel? level) {
    switch (level) {
      case FitnessLevel.advanced:
        return 12;
      case FitnessLevel.intermediate:
        return 10;
      case FitnessLevel.beginner:
      default:
        return 15;
    }
  }

  Future<List<_Hist>> _getExerciseHistory(String exerciseName) async {
    try {
      _sessionsCache ??= await dbProvider.getWorkoutSessions();
      final key = exerciseName.toLowerCase().trim();
      final out = <_Hist>[];
      for (final s in _sessionsCache!) {
        for (final ex in s.exercises) {
          if (ex.exerciseName.toLowerCase().trim() == key) {
            for (final set in ex.sets) {
              if (set.isCompleted) out.add(_Hist(date: s.startTime, reps: set.actualReps));
            }
          }
        }
      }
      out.sort((a, b) => b.date.compareTo(a.date));
      return out;
    } catch (_) {
      return const [];
    }
  }
}

class _Hist {
  final DateTime date;
  final int reps;
  const _Hist({required this.date, required this.reps});
}

