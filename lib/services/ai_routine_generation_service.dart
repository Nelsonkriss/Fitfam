import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:workout_planner/models/routine.dart';
import 'package:workout_planner/models/part.dart';
import 'package:workout_planner/models/exercise.dart';
import 'package:workout_planner/models/main_targeted_body_part.dart';
import 'package:workout_planner/models/user_profile.dart';
import 'package:workout_planner/resource/open_router_service.dart';
import 'package:workout_planner/services/ai_weight_recommendation_service.dart';

class AIRoutineGenerationService {
  final AIWeightRecommendationService _weightRecommendationService;
  final OpenRouterService _openRouterService;

  AIRoutineGenerationService({AIWeightRecommendationService? weightRecommendationService, OpenRouterService? openRouterService})
      : _weightRecommendationService = weightRecommendationService ?? AIWeightRecommendationService(),
        _openRouterService = openRouterService ?? OpenRouterService(apiKey: dotenv.env['OPENROUTER_API_KEY'] ?? '');

  Future<List<Routine>> generateRoutines({
    required MainTargetedBodyPart targetedBodyPart,
    required String routineName,
    UserProfile? userProfile,
  }) async {
    final parts = await _generatePartsForBodyPart(targetedBodyPart, userProfile: userProfile);

    if (parts.isEmpty) {
      return [];
    }

    // Build base routine
    var routine = Routine(
      routineName: routineName,
      mainTargetedBodyPart: targetedBodyPart,
      parts: parts,
      createdDate: DateTime.now(),
      isAiGenerated: true,
    );

    // Enrich with recommended weights based on profile/history
    routine = await enrichRoutineWithRecommendedWeights(routine, userProfile: userProfile);

    return [routine];
  }

  Future<List<Part>> _generatePartsForBodyPart(MainTargetedBodyPart bodyPart, {UserProfile? userProfile}) async {
    String userPrompt = "Generate a workout routine for ${bodyPart.name}.";
    if (userProfile != null) {
      userPrompt += " My fitness level is ${userProfile.fitnessLevel.name}, and my goal is to ${userProfile.fitnessGoal.name}.";
      if (userProfile.availableEquipment.isNotEmpty) {
        userPrompt += " I have access to the following equipment: ${userProfile.availableEquipment.map((e) => e.name).join(', ')}.";
      }
    }

    final String? routineJsonString = await _openRouterService.getAiGeneratedRoutineDescription(userPrompt);

    if (routineJsonString != null) {
      final List<Routine> newRoutines = _openRouterService.parseRoutinesFromJsonString(routineJsonString);
      if (newRoutines.isNotEmpty) {
        return newRoutines.first.parts;
      }
    }

    return [];
  }

  // --- Weight Enrichment ---------------------------------------------------
  // Post-processes a routine to fill target weights for Weight-type exercises
  // using onboarding profile + user history.
  Future<Routine> enrichRoutineWithRecommendedWeights(
    Routine routine, {
    UserProfile? userProfile,
  }) async {
    // Helper to parse target reps from a reps string like "8-12", "10", "AMRAP"
    int _parseTargetReps(String reps) {
      try {
        final rep = reps.trim().toLowerCase();
        if (rep == 'amrap') return 10; // sensible default for estimation
        if (rep.contains('-')) {
          // Use the lower bound to be conservative
          return int.tryParse(rep.split('-').first.trim()) ?? 10;
        }
        if (rep.contains('sec')) {
          // Timed work: return 0 to mark as N/A for weights
          return 0;
        }
        return int.tryParse(rep) ?? 10;
      } catch (_) {
        return 10;
      }
    }

    double _roundToIncrement(double value, double increment) {
      if (increment <= 0) return value;
      return (value / increment).round() * increment;
    }

    // Build new parts with weights filled in
    final enrichedParts = <Part>[];
    for (final part in routine.parts) {
      final newExercises = <Exercise>[];
      for (final ex in part.exercises) {
        if (ex.workoutType == WorkoutType.Weight) {
          final currentWeight = ex.weight;
          final reps = _parseTargetReps(ex.reps);
          // Only compute if weight is missing or zero
          if (currentWeight <= 0 && reps > 0) {
            try {
              final recommended = await _weightRecommendationService.getRecommendedWeight(
                exerciseName: ex.name,
                userProfile: userProfile,
                targetReps: reps,
              );
              // Round to common gym increment (2.5kg)
              final rounded = _roundToIncrement(recommended, 2.5);
              newExercises.add(ex.copyWith(weight: rounded));
            } catch (_) {
              // If recommendation fails, keep original
              newExercises.add(ex);
            }
          } else {
            newExercises.add(ex);
          }
        } else {
          newExercises.add(ex);
        }
      }
      enrichedParts.add(part.copyWith(exercises: newExercises));
    }

    return routine.copyWith(parts: enrichedParts);
  }
}
