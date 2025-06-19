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

    final routine = Routine(
      routineName: routineName,
      mainTargetedBodyPart: targetedBodyPart,
      parts: parts,
      createdDate: DateTime.now(),
      isAiGenerated: true,
    );

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
}
