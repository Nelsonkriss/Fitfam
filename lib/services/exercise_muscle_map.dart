import 'package:workout_planner/models/part.dart';

/// Lightweight mapping from exercise name -> targeted body parts with weights.
/// We avoid DB migrations by keeping this as a service and using fuzzy matching.
class ExerciseMuscleMap {
  /// Returns a map of body part -> weight (sums to 1.0) for an exercise name.
  /// Fallbacks to [TargetedBodyPart.FullBody] if unknown.
  static Map<TargetedBodyPart, double> targetsFor(String exerciseName) {
    final n = exerciseName.toLowerCase();

    Map<TargetedBodyPart, double> w(Map<TargetedBodyPart, double> m) => _norm(m);

    // Core lifts and common movements
    if (n.contains('squat')) {
      return w({TargetedBodyPart.Leg: 0.85, TargetedBodyPart.Abs: 0.15});
    }
    if (n.contains('deadlift')) {
      return w({TargetedBodyPart.Back: 0.45, TargetedBodyPart.Leg: 0.45, TargetedBodyPart.Abs: 0.10});
    }
    if (n.contains('bench press')) {
      return w({TargetedBodyPart.Chest: 0.7, TargetedBodyPart.Tricep: 0.25, TargetedBodyPart.Shoulder: 0.05});
    }
    if (n.contains('overhead press') || n.contains('shoulder press')) {
      return w({TargetedBodyPart.Shoulder: 0.7, TargetedBodyPart.Tricep: 0.3});
    }
    if (n.contains('row')) { // bent over row, barbell row, dumbbell row
      return w({TargetedBodyPart.Back: 0.7, TargetedBodyPart.Bicep: 0.3});
    }
    if (n.contains('pull-up') || n.contains('pull ups') || n.contains('pullups')) {
      return w({TargetedBodyPart.Back: 0.7, TargetedBodyPart.Bicep: 0.3});
    }
    if (n.contains('lateral raise')) {
      return w({TargetedBodyPart.Shoulder: 1.0});
    }
    if (n.contains('curl')) { // bicep curl, hammer curl
      return w({TargetedBodyPart.Bicep: 1.0});
    }
    if (n.contains('dip')) {
      return w({TargetedBodyPart.Tricep: 0.7, TargetedBodyPart.Chest: 0.3});
    }
    if (n.contains('lunge')) {
      return w({TargetedBodyPart.Leg: 1.0});
    }
    if (n.contains('hip thrust')) {
      return w({TargetedBodyPart.Leg: 1.0});
    }
    if (n.contains('crunch') || n.contains('sit-up') || n.contains('sit up')) {
      return w({TargetedBodyPart.Abs: 1.0});
    }
    if (n.contains('mountain climber')) {
      return w({TargetedBodyPart.Abs: 0.5, TargetedBodyPart.Leg: 0.25, TargetedBodyPart.Shoulder: 0.25});
    }
    if (n.contains('push-up') || n.contains('push up') || n.contains('push-ups')) {
      return w({TargetedBodyPart.Chest: 0.6, TargetedBodyPart.Tricep: 0.3, TargetedBodyPart.Shoulder: 0.1});
    }

    // Fallback
    return {TargetedBodyPart.FullBody: 1.0};
  }

  static Map<TargetedBodyPart, double> _norm(Map<TargetedBodyPart, double> m) {
    final s = m.values.fold(0.0, (a, b) => a + b);
    if (s <= 0) return {TargetedBodyPart.FullBody: 1.0};
    return m.map((k, v) => MapEntry(k, v / s));
  }
}

