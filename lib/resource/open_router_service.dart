import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:workout_planner/models/routine.dart'; // Assuming you'll parse into this
import 'package:workout_planner/models/part.dart';
import 'package:workout_planner/models/exercise.dart';
import 'package:workout_planner/models/main_targeted_body_part.dart';


class OpenRouterService {
  final String apiKey;
  static const String _apiUrl = "https://openrouter.ai/api/v1/chat/completions";

  OpenRouterService({required this.apiKey});

  Future<String?> getAiGeneratedRoutineDescription(String userPrompt, {String model = "deepseek/deepseek-chat-v3-0324:free"}) async {
    // API key is now passed via constructor and stored in this.apiKey
    if (apiKey.isEmpty) { // Check if the passed key is empty
      debugPrint("OpenRouter API key is empty.");
      return null;
    }

    final systemPrompt = """
You are an expert fitness coach. Generate a workout routine based on the user's request.
Output the routine ONLY as a JSON object with the following structure and nothing else:
{
  "routineName": "User's Goal Routine",
  "mainTargetedBodyPart": "FullBody",
  "parts": [
    {
      "partName": "Day 1: Full Body A",
      "targetedBodyPart": "FullBody",
      "setType": "Regular",
      "exercises": [
        { "name": "Squats", "sets": 3, "reps": "8-12", "weight": 0.0, "workoutType": "Weight" },
        { "name": "Bench Press", "sets": 3, "reps": "8-12", "weight": 0.0, "workoutType": "Weight" }
      ]
    }
  ]
}
Ensure exercise names are common and recognizable.
'workoutType' can be 'Weight', 'Cardio', or 'Timed'.
'mainTargetedBodyPart' for the routine must be one of: Abs, Arm, Back, Chest, Leg, Shoulder, FullBody, Other.
'targetedBodyPart' for a part must be one of: Abs, Arm, Back, Chest, Leg, Shoulder, FullBody, Tricep, Bicep.
'setType' for a part must be one of: Regular, Drop, Super, Tri, Giant.
'reps' should be a string, e.g., "8-12" or "15" or "AMRAP" or "30 sec".
The key for number of sets per exercise MUST be "sets" (plural) and it should be an integer.
'weight' should be a double, use 0.0 if not applicable or bodyweight.
Provide a sensible routineName based on the user's request.
If the user asks for a 3-day routine, the "parts" array should contain 3 part objects, each representing a day.
Do not include any explanatory text before or after the JSON object.
""";

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Authorization': 'Bearer $apiKey', // Use the locally loaded apiKey
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': model,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userPrompt},
          ],
        }),
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        if (responseBody['choices'] != null && responseBody['choices'].isNotEmpty) {
          // Assuming the AI's response is in the 'content' of the first choice's message
          String rawContent = responseBody['choices'][0]['message']['content'];
          debugPrint("[OpenRouterService] Raw AI Response: $rawContent");
          // Attempt to extract only the JSON part if there's any surrounding text
          // This is a basic attempt; more robust JSON extraction might be needed
          final jsonRegex = RegExp(r'\{[\s\S]*\}');
          final match = jsonRegex.firstMatch(rawContent);
          if (match != null) {
            return match.group(0);
          }
          return rawContent; // Fallback to raw content if regex fails
        }
      } else {
        debugPrint("OpenRouter API Error: ${response.statusCode} - ${response.body}");
        return null;
      }
    } catch (e) {
      debugPrint("Exception during OpenRouter API call: $e");
      return null;
    }
    return null;
  }

  // Placeholder for parsing the JSON string into a Routine object
  // This will be complex and needs careful implementation based on your models
  Routine? parseRoutineFromJsonString(String jsonString) {
    try {
      final Map<String, dynamic> jsonMap = jsonDecode(jsonString);

      // Validate top-level keys
      if (!jsonMap.containsKey('routineName') ||
          !jsonMap.containsKey('mainTargetedBodyPart') ||
          !jsonMap.containsKey('parts')) {
        debugPrint("[OpenRouterService] Error parsing routine: Missing top-level keys.");
        return null;
      }

      final String routineName = jsonMap['routineName'] as String;
      final String mainBodyPartStr = jsonMap['mainTargetedBodyPart'] as String;
      final List<dynamic> partsListJson = jsonMap['parts'] as List<dynamic>;

      MainTargetedBodyPart mainTargetedBodyPart;
      try {
        mainTargetedBodyPart = MainTargetedBodyPart.values.firstWhere(
          (e) => e.name.toLowerCase() == mainBodyPartStr.toLowerCase(),
          orElse: () => MainTargetedBodyPart.Other // Default if not found
        );
      } catch (e) {
        debugPrint("[OpenRouterService] Error parsing mainTargetedBodyPart: '$mainBodyPartStr'. Defaulting to Other. Error: $e");
        mainTargetedBodyPart = MainTargetedBodyPart.Other;
      }


      List<Part> parts = [];
      for (var partJson in partsListJson) {
        if (partJson is! Map<String, dynamic>) {
          debugPrint("[OpenRouterService] Error parsing part: Item is not a map. Skipping.");
          continue;
        }
        if (!partJson.containsKey('partName') ||
            !partJson.containsKey('targetedBodyPart') ||
            !partJson.containsKey('setType') ||
            !partJson.containsKey('exercises')) {
          debugPrint("[OpenRouterService] Error parsing part: Missing keys in part object. Skipping part: $partJson");
          continue;
        }

        final String partName = partJson['partName'] as String;
        final String targetedBodyPartStr = partJson['targetedBodyPart'] as String;
        final String setTypeStr = partJson['setType'] as String;
        final List<dynamic> exercisesListJson = partJson['exercises'] as List<dynamic>;

        TargetedBodyPart targetedBodyPart;
         try {
            targetedBodyPart = TargetedBodyPart.values.firstWhere(
              (e) => e.name.toLowerCase() == targetedBodyPartStr.toLowerCase(),
              // orElse: () => TargetedBodyPart.FullBody // Default if not found
            );
         } catch (e) {
           debugPrint("[OpenRouterService] Error parsing part's targetedBodyPart: '$targetedBodyPartStr'. Defaulting to FullBody. Error: $e");
           targetedBodyPart = TargetedBodyPart.FullBody; // Default
         }

        SetType setType;
        try {
          setType = SetType.values.firstWhere(
            (e) => e.name.toLowerCase() == setTypeStr.toLowerCase(),
            // orElse: () => SetType.Regular // Default if not found
          );
        } catch (e) {
          debugPrint("[OpenRouterService] Error parsing setType: '$setTypeStr'. Defaulting to Regular. Error: $e");
          setType = SetType.Regular; // Default
        }


        List<Exercise> exercises = [];
        for (var exerciseJson in exercisesListJson) {
           if (exerciseJson is! Map<String, dynamic>) {
            debugPrint("[OpenRouterService] Error parsing exercise: Item is not a map. Skipping.");
            continue;
          }
          // Check for "sets" (plural) first, then fall back to "set" (singular)
          if (!exerciseJson.containsKey('name') ||
              !(exerciseJson.containsKey('sets') || exerciseJson.containsKey('set')) || // Check for either "sets" or "set"
              !exerciseJson.containsKey('reps') ||
              !exerciseJson.containsKey('workoutType')) {
            debugPrint("[OpenRouterService] Error parsing exercise: Missing required keys (name, sets/set, reps, workoutType). Skipping exercise: $exerciseJson");
            continue;
          }

          final String exName = exerciseJson['name'] as String;
          // Read "sets" or "set", defaulting to 0 if neither or not an int
          final int exSets = (exerciseJson['sets'] ?? exerciseJson['set']) is int
                           ? (exerciseJson['sets'] ?? exerciseJson['set']) as int
                           : 0;
          if (exSets == 0) {
            debugPrint("[OpenRouterService] Warning: Exercise '${exName}' has 0 sets or invalid 'sets'/'set' field. Value: ${exerciseJson['sets'] ?? exerciseJson['set']}. Skipping exercise.");
            continue;
          }
          final String exReps = exerciseJson['reps'] as String;
          // Weight is optional, default to 0.0 if not present or not a number
          final double exWeight = (exerciseJson['weight'] as num?)?.toDouble() ?? 0.0;
          final String workoutTypeStr = exerciseJson['workoutType'] as String;

          WorkoutType workoutType;
          try {
            workoutType = WorkoutType.values.firstWhere(
              (e) => e.name.toLowerCase() == workoutTypeStr.toLowerCase()
            );
          } catch (e) {
            debugPrint("[OpenRouterService] Error parsing workoutType: '$workoutTypeStr'. Defaulting to Weight. Error: $e");
            workoutType = WorkoutType.Weight; // Default
          }


          exercises.add(Exercise(
            name: exName,
            sets: exSets,
            reps: exReps,
            weight: exWeight,
            workoutType: workoutType,
            // exHistory and id will be handled by DB or default
          ));
        }

        if (exercises.isNotEmpty) {
          parts.add(Part(
            partName: partName,
            targetedBodyPart: targetedBodyPart,
            setType: setType,
            exercises: exercises,
          ));
        } else {
           debugPrint("[OpenRouterService] Part '$partName' skipped because it had no valid exercises after parsing.");
        }
      }
      if (parts.isEmpty && partsListJson.isNotEmpty) {
         debugPrint("[OpenRouterService] Routine parsing resulted in zero valid parts, although parts were present in JSON. Check part/exercise parsing errors.");
         return null; // Or return a routine with empty parts if that's acceptable
      }


      return Routine(
        routineName: routineName,
        mainTargetedBodyPart: mainTargetedBodyPart,
        parts: parts,
        createdDate: DateTime.now(),
        isAiGenerated: true, // Set the flag for AI generated routines
        // Other fields like id, completionCount, etc., will be set by DB or default
      );
    } catch (e, s) {
      debugPrint("[OpenRouterService] Exception parsing JSON to Routine: $e\n$s");
      debugPrint("[OpenRouterService] Faulty JSON string was: $jsonString");
      return null;
    }
  }
}