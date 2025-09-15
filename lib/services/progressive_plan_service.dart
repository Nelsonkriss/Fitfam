import 'package:workout_planner/models/routine.dart';
import 'package:workout_planner/models/part.dart';
import 'package:workout_planner/models/exercise.dart';

class ProgressivePlanService {
  /// Builds a progressive multi-week plan by cloning base routines and
  /// applying small weekly progressions with optional deloads.
  ///
  /// - Weight-type exercises: +2.5% per week (rounded to nearest 0.5kg), deload week at [deloadEvery] uses [deloadMultiplier].
  /// - Bodyweight (weight <= 0): +1 rep (lower bound if range) per week, deload week keeps base.
  /// - Timed: +5 seconds per week, deload week keeps base.
  static List<Routine> buildPlan(
    List<Routine> bases, {
    int weeks = 4,
    int deloadEvery = 4,
    double weeklyWeightPct = 0.025,
    double deloadMultiplier = 0.7,
  }) {
    if (weeks <= 1) return bases;
    final List<Routine> out = [];
    for (int w = 1; w <= weeks; w++) {
      for (final base in bases) {
        final bool isDeload = (deloadEvery > 0) && (w % deloadEvery == 0);
        out.add(_cloneWithWeekProgression(
          base,
          week: w,
          isDeload: isDeload,
          weeklyWeightPct: weeklyWeightPct,
          deloadMultiplier: deloadMultiplier,
        ));
      }
    }
    return out;
  }

  static Routine _cloneWithWeekProgression(
    Routine base, {
    required int week,
    required bool isDeload,
    required double weeklyWeightPct,
    required double deloadMultiplier,
  }) {
    final progressedParts = base.parts.map((p) {
      final newExercises = p.exercises.map((ex) {
        switch (ex.workoutType) {
          case WorkoutType.Weight:
            final bool bodyweight = ex.weight <= 0.0;
            if (bodyweight) {
              // Increase reps target slightly
              final reps = _bumpReps(ex.reps, week, isDeload);
              return ex.copyWith(reps: reps);
            } else {
              // Increase weight
              double newWeight = ex.weight;
              if (isDeload) {
                newWeight = (newWeight * deloadMultiplier);
              } else {
                newWeight = newWeight * (1.0 + weeklyWeightPct * (week - 1));
              }
              newWeight = _roundToIncrement(newWeight, 0.5);
              return ex.copyWith(weight: newWeight);
            }
          case WorkoutType.Timed:
            final baseSecs = _parseSeconds(ex.reps);
            int newSecs = baseSecs;
            if (!isDeload) newSecs = baseSecs + (5 * (week - 1));
            final reps = newSecs > 0 ? '$newSecs sec' : ex.reps;
            return ex.copyWith(reps: reps);
          case WorkoutType.Cardio:
            return ex; // Leave as-is for now
        }
      }).toList();

      return p.copyWith(exercises: newExercises);
    }).toList();

    return base.copyWith(
      parts: progressedParts,
      routineName: '${base.routineName} — Week $week',
    );
  }

  static String _bumpReps(String reps, int week, bool isDeload) {
    if (isDeload) return reps; // keep base
    try {
      final s = reps.trim().toLowerCase();
      if (s.contains('amrap')) return reps; // leave AMRAP
      if (s.contains('-')) {
        final parts = s.split('-');
        int lo = int.tryParse(parts.first.trim()) ?? 0;
        int hi = int.tryParse(parts.last.trim()) ?? lo;
        lo += (week - 1); hi += (week - 1);
        return '${lo.clamp(1, 999)}-${hi.clamp(1, 999)}';
      }
      final n = int.tryParse(s) ?? 0;
      return '${(n + (week - 1)).clamp(1, 999)}';
    } catch (_) {
      return reps;
    }
  }

  static int _parseSeconds(String reps) {
    final s = reps.toLowerCase();
    final match = RegExp(r'(\d+)\s*(sec|s)').firstMatch(s);
    if (match != null) {
      return int.tryParse(match.group(1) ?? '') ?? 0;
    }
    return 0;
  }

  static double _roundToIncrement(double value, double inc) {
    if (inc <= 0) return value;
    return (value / inc).round() * inc;
  }
}
