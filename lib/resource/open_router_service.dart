import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:workout_planner/models/routine.dart'; // Assuming you'll parse into this
import 'package:workout_planner/models/main_targeted_body_part.dart';
import 'package:workout_planner/services/exercise_animation_service.dart';


class OpenRouterService {
  final String apiKey;
  final String defaultModel;
  static const String _apiUrl = "https://openrouter.ai/api/v1/chat/completions";

  OpenRouterService({
    required this.apiKey,
    this.defaultModel = "mimo v2flash",
  });

  Future<String?> getAiGeneratedRoutineDescription(String userPrompt, {String? model}) async {
    final String effectiveModel = (model != null && model.trim().isNotEmpty)
        ? model.trim()
        : defaultModel.trim();
    // API key is now passed via constructor and stored in this.apiKey
    if (apiKey.isEmpty) { // Check if the passed key is empty
      debugPrint("OpenRouter API key is empty.");
      return null;
    }

    // Get the animation-aware exercise list
    final availableExercises = ExerciseAnimationService.generateAIExerciseList();
    
    final systemPrompt = """
You are an expert fitness coach with access to a workout app that has 3D animations for specific exercises.
Generate a workout routine based on the user's request using ONLY exercises that have animations available. The routine should have multiple parts, each targeting different muscle groups or body parts.

$availableExercises

OUTPUT FORMAT (STRICT):
Return ONLY a valid JSON object with a single top-level key "routines" whose value is an array of routine objects. Do not output markdown fences or any extra text.
{
  "routines": [
    {
      "routineName": "User's Goal Routine",
      "mainTargetedBodyPart": "FullBody",
      "parts": [
        {
          "partName": "Day 1: Full Body A",
          "targetedBodyPart": "FullBody",
          "setType": "Regular",
          "exercises": [
            { "name": "Barbell Squat", "sets": 3, "reps": "8-12", "weight": 0.0, "workoutType": "Weight", "primaryTarget": "Leg" },
            { "name": "Barbell Bench Press", "sets": 3, "reps": "8-12", "weight": 0.0, "workoutType": "Weight", "primaryTarget": "Chest", "secondaryTargets": ["Tricep","Shoulder"] }
          ]
        },
        {
          "partName": "Day 1: Full Body B",
          "targetedBodyPart": "FullBody",
          "setType": "Regular",
          "exercises": [
            { "name": "Dumbbell Lunges", "sets": 3, "reps": "8-12", "weight": 0.0, "workoutType": "Weight" },
            { "name": "Pull-ups", "sets": 3, "reps": "8-12", "weight": 0.0, "workoutType": "Weight" }
          ]
        }
      ]
    }
  ]
}

FIELD REQUIREMENTS (STRICT):
- 'workoutType' can be 'Weight', 'Cardio', 'Timed'.
- 'mainTargetedBodyPart' for the routine must be one of: Abs, Arm, Back, Chest, Leg, Shoulder, FullBody, Other.
- 'targetedBodyPart' for a part must be one of: Abs, Arm, Back, Chest, Leg, Shoulder, FullBody, Tricep, Bicep.
- 'setType' for a part must be one of: Regular, Drop, Super, Tri, Giant.
- 'reps' should be a string, e.g., "8-12" or "15" or "AMRAP" or "30 sec".
- The key for number of sets per exercise MUST be "sets" (plural) and it should be an integer.
- 'weight' should be a double, use 0.0 if not applicable or bodyweight.
- Provide a sensible routineName based on the user's request.
- If the user asks for a 3-day routine, the "parts" array should contain 3 part objects, each representing a day.
- Each part should contain only one exercise. If there are 12 exercises in a routine, there should be 12 parts.

TARGETS PER EXERCISE:
- For each exercise, include "primaryTarget" as one of: Abs, Arm, Back, Chest, Leg, Shoulder, FullBody, Tricep, Bicep.
- Optionally include "secondaryTargets" as a list of the same enum strings.

CRITICAL:
- Use EXACT exercise names from the available list above.
- ALWAYS return a JSON object with the key "routines" (even for a single routine).
- Do NOT include markdown (```), comments, or any extra prose.
""";

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Authorization': 'Bearer $apiKey', // Use the locally loaded apiKey
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': effectiveModel,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userPrompt},
          ],
        }),
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        if (responseBody['choices'] != null && responseBody['choices'].isNotEmpty) {
          // AI response content
          String rawContent = responseBody['choices'][0]['message']['content'];
          debugPrint("[OpenRouterService] Raw AI Response: $rawContent");

          // Robust JSON block extraction: try array first, then object; else fallback
          String? extractJson(String input) {
            String? trySlice(String start, String end) {
              final startIdx = input.indexOf(start);
              final endIdx = input.lastIndexOf(end);
              if (startIdx != -1 && endIdx != -1 && endIdx > startIdx) {
                final candidate = input.substring(startIdx, endIdx + 1).trim();
                try {
                  jsonDecode(candidate);
                  return candidate;
                } catch (_) { /* keep searching */ }
              }
              return null;
            }

            // Prefer a JSON object with routines
            final obj = trySlice('{', '}');
            if (obj != null) return obj;
            // Or a top-level array of routines
            final arr = trySlice('[', ']');
            if (arr != null) return arr;
            return null;
          }

          final extracted = extractJson(rawContent);
          return extracted ?? rawContent.trim();
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

  List<Routine> parseRoutinesFromJsonString(String jsonString) {
    try {
      final dynamic decoded = jsonDecode(jsonString);

      List<dynamic> routinesJson;

      if (decoded is Map<String, dynamic>) {
        // Case A: Proper object with 'routines'
        if (decoded.containsKey('routines') && decoded['routines'] is List) {
          routinesJson = decoded['routines'] as List<dynamic>;
        } else {
          // Case B: Single routine object at root
          debugPrint("[OpenRouterService] Root is a single object; wrapping into routines[].");
          routinesJson = [decoded];
        }
      } else if (decoded is List) {
        // Case C: Top-level array of routines
        routinesJson = decoded;
      } else {
        debugPrint("[OpenRouterService] Error: Unsupported JSON root type: ${decoded.runtimeType}");
        return [];
      }

      // Pre-process each routine map: if AI encoded multiple days in one routine
      // (e.g., parts named "Day 1", "Day 2"...), split them into separate routines.
      final List<Routine> parsed = [];
      for (final routineJson in routinesJson) {
        if (routineJson is! Map<String, dynamic>) continue;
        for (final splitMap in _splitRoutineMapByDaysIfNeeded(routineJson)) {
          final r = _parseSingleRoutine(splitMap);
          if (r != null) parsed.add(r);
        }
      }

      if (parsed.isEmpty) {
        debugPrint("[OpenRouterService] Warning: No valid routines parsed from JSON.");
      }
      return parsed;
    } catch (e, s) {
      debugPrint("[OpenRouterService] Exception parsing JSON to List<Routine>: $e\n$s");
      debugPrint("[OpenRouterService] Faulty JSON string was: $jsonString");
      return [];
    }
  }

  Routine? _parseSingleRoutine(Map<String, dynamic> jsonMap) {
    try {
      // Reuse the existing parsing logic for a single routine
      return parseRoutineFromJsonString(jsonEncode(jsonMap));
    } catch (e) {
      debugPrint("[OpenRouterService] Error parsing single routine from list: $e");
      return null;
    }
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
          
          // Validate that the exercise has animation support
          if (!ExerciseAnimationService.validateExerciseHasAnimation(exName)) {
            debugPrint("[OpenRouterService] Warning: Exercise '$exName' does not have animation support. Attempting to find alternative...");
            
            final String? alternative = ExerciseAnimationService.getSuggestedAlternative(exName);
            if (alternative != null) {
              debugPrint("[OpenRouterService] Using alternative exercise '$alternative' instead of '$exName'");
              // Update the exercise name to the alternative
              exerciseJson['name'] = alternative;
            } else {
              debugPrint("[Open-router_service] No suitable alternative found for '$exName'. Skipping exercise.");
              continue;
            }
          }
          
          // Read "sets" or "set", defaulting to 0 if neither or not an int
          final int exSets = (exerciseJson['sets'] ?? exerciseJson['set']) is int
                           ? (exerciseJson['sets'] ?? exerciseJson['set']) as int
                           : 0;
          if (exSets == 0) {
            debugPrint("[OpenRouterService] Warning: Exercise '${exerciseJson['name']}' has 0 sets or invalid 'sets'/'set' field. Value: ${exerciseJson['sets'] ?? exerciseJson['set']}. Skipping exercise.");
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


          // Parse optional targets if provided by AI
          TargetedBodyPart? primaryTarget;
          List<TargetedBodyPart> secondaryTargets = const [];
          try {
            final pt = exerciseJson['primaryTarget'] ?? exerciseJson['primaryTargetedBodyPart'];
            if (pt != null) {
              primaryTarget = TargetedBodyPart.values.firstWhere(
                  (e) => e.name.toLowerCase() == pt.toString().toLowerCase(),
                  orElse: () => TargetedBodyPart.FullBody);
            }
            final st = exerciseJson['secondaryTargets'];
            if (st is List) {
              secondaryTargets = st.map((v) {
                try {
                  return TargetedBodyPart.values.firstWhere((e) => e.name.toLowerCase() == v.toString().toLowerCase());
                } catch (_) { return null; }
              }).whereType<TargetedBodyPart>().toList();
            }
          } catch (_) {}

          exercises.add(Exercise(
            name: exerciseJson['name'] as String, // Use the potentially updated name
            sets: exSets,
            reps: exReps,
            weight: exWeight,
            workoutType: workoutType,
            primaryTarget: primaryTarget,
            secondaryTargets: secondaryTargets,
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

  // --- Helpers to split a single routine map into multiple routines by Day markers ---
  List<Map<String, dynamic>> _splitRoutineMapByDaysIfNeeded(Map<String, dynamic> routineMap) {
    final parts = routineMap['parts'];
    if (parts is! List) return [routineMap];

    // Identify indices where a new day begins by scanning partName
    final List<_DayGroup> groups = [];
    _DayGroup? current;

    for (final p in parts) {
      if (p is! Map<String, dynamic>) continue;
      final pn = (p['partName'] ?? '').toString();
      final label = _extractDayLabel(pn);

      if (label != null) {
        // Start a new group on a new day label
        current = _DayGroup(label)..parts.add(p);
        groups.add(current);
      } else {
        // Append to current group if one exists; otherwise, keep a generic bucket
        current ??= _DayGroup('');
        current.parts.add(p);
      }
    }

    // If fewer than 2 labeled groups, do not split; return original
    final labeledCount = groups.where((g) => g.label.isNotEmpty).length;
    if (labeledCount < 2) return [routineMap];

    // Build new routine maps from groups
    final baseName = (routineMap['routineName'] ?? 'Program').toString();
    final mainTarget = routineMap['mainTargetedBodyPart'] ?? 'FullBody';
    final List<Map<String, dynamic>> out = [];
    int auto = 1;
    for (final g in groups) {
      final nameSuffix = g.label.isNotEmpty ? g.label : 'Day $auto';
      final newMap = <String, dynamic>{
        'routineName': '$baseName - $nameSuffix',
        'mainTargetedBodyPart': mainTarget,
        'parts': g.parts,
      };
      out.add(newMap);
      auto++;
    }
    return out;
  }

  String? _extractDayLabel(String partName) {
    final lower = partName.toLowerCase();
    // Common patterns: Day 1/2/3, Day One/Two, Mon/Tue/Wednesday, etc.
    final RegExp dayRe = RegExp(
      r"\b(day\s*(\d+|one|two|three|four|five|six|seven)|mon(day)?|tue(sday)?|wed(nesday)?|thu(rsday)?|fri(day)?|sat(urday)?|sun(day)?)\b",
      caseSensitive: false,
    );
    final m = dayRe.firstMatch(lower);
    if (m == null) return null;
    // Return the matched segment capitalized nicely
    final raw = m.group(0)!;
    return raw.split(' ').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' ');
  }
}

class _DayGroup {
  final String label;
  final List<Map<String, dynamic>> parts = [];
  _DayGroup(this.label);
}
