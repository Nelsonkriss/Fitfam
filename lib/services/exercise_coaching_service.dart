import 'package:workout_planner/models/part.dart';

class CoachingTip {
  final String headline;
  final List<String> tips;
  final List<String> pitfalls;
  final int suggestedRestSeconds;
  final String whyThisSet;
  CoachingTip({
    required this.headline,
    required this.tips,
    required this.pitfalls,
    required this.suggestedRestSeconds,
    required this.whyThisSet,
  });
}

/// Lightweight, local coaching library. No network calls.
class ExerciseCoachingService {
  static CoachingTip getCoaching({
    required String exerciseName,
    required int setIndex,
    required int totalSets,
    required TargetedBodyPart primaryTarget,
    required bool lowEnergy,
    required bool sore,
  }) {
    final n = exerciseName.toLowerCase();
    List<String> tips = [];
    List<String> pitfalls = [];
    int rest = 60;
    String headline = 'Quick Coaching';

    if (n.contains('squat')) {
      headline = 'Squat form cues';
      tips.addAll(['Brace core before each rep', 'Knees track over toes', 'Drive through mid-foot']);
      pitfalls.addAll(['Heels lifting', 'Back rounding at the bottom']);
      rest = 120;
    } else if (n.contains('bench press')) {
      headline = 'Bench press cues';
      tips.addAll(['Scapula retracted', 'Soft touch on chest', 'Drive feet into floor']);
      pitfalls.addAll(['Elbows flared too wide', 'Bouncing bar off chest']);
      rest = 90;
    } else if (n.contains('deadlift')) {
      headline = 'Deadlift cues';
      tips.addAll(['Hinge first (not squat)', 'Lats tight, bar close', 'Push the floor away']);
      pitfalls.addAll(['Bar drifting forward', 'Jerking the bar off the floor']);
      rest = 150;
    } else if (n.contains('row')) {
      tips.addAll(['Pull elbows to hips', 'Neutral spine', 'Pause at contraction']);
      pitfalls.addAll(['Shrugging shoulders', 'Excessive body English']);
      rest = 75;
    } else if (n.contains('curl')) {
      tips.addAll(['Elbows pinned', 'Control the eccentric']);
      pitfalls.addAll(['Swinging torso', 'Elbows drifting forward']);
      rest = 60;
    } else if (n.contains('push-up') || n.contains('push up')) {
      tips.addAll(['Ribs down, glutes tight', 'Full lockout']);
      pitfalls.addAll(['Head dropping', 'Hips sagging']);
      rest = 45;
    } else {
      tips.addAll(['Control tempo', 'Full ROM', 'Stop 1–2 reps shy of failure']);
      rest = 60;
    }

    // Modifiers
    if (lowEnergy) rest = (rest * 0.8).round();
    if (sore) rest = (rest * 1.2).round();

    String why;
    if (setIndex == 0) {
      why = 'Primer set: groove the pattern and dial in form.';
    } else if (setIndex == totalSets - 1) {
      why = 'Final set: quality over ego. Leave 1–2 reps in the tank.';
    } else {
      why = 'Working set: accumulate quality volume for $primaryTarget.';
    }

    return CoachingTip(
      headline: headline,
      tips: tips,
      pitfalls: pitfalls,
      suggestedRestSeconds: rest,
      whyThisSet: why,
    );
  }
}

