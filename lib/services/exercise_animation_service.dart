import 'package:workout_planner/models/exercise_animation_data.dart';

/// Service to provide AI with information about available animated exercises
class ExerciseAnimationService {
  
  /// Get all available exercise names that have animations
  static List<String> getAvailableAnimatedExercises() {
    return ExerciseAnimationData.getAllExerciseNames();
  }
  
  /// Get exercises grouped by category for AI understanding
  static Map<String, List<String>> getExercisesByCategory() {
    final allExercises = ExerciseAnimationData.getAllExerciseNames();
    
    return {
      'Bodyweight Exercises': allExercises.where((exercise) => 
        exercise.toLowerCase().contains('push-up') ||
        exercise.toLowerCase().contains('pull-up') ||
        exercise.toLowerCase().contains('mountain climber') ||
        exercise.toLowerCase().contains('crunch') ||
        exercise.toLowerCase().contains('dips') ||
        exercise.toLowerCase().contains('bicycle')
      ).toList(),
      
      'Dumbbell Exercises': allExercises.where((exercise) => 
        exercise.toLowerCase().contains('dumbbell') ||
        exercise.toLowerCase().contains('bicep curl') ||
        exercise.toLowerCase().contains('lateral raise') ||
        exercise.toLowerCase().contains('hammer curl') ||
        exercise.toLowerCase().contains('bent over row')
      ).toList(),
      
      'Barbell Exercises': allExercises.where((exercise) => 
        exercise.toLowerCase().contains('barbell') ||
        exercise.toLowerCase().contains('squat') ||
        exercise.toLowerCase().contains('bench press') ||
        exercise.toLowerCase().contains('deadlift') ||
        exercise.toLowerCase().contains('overhead press')
      ).toList(),
    };
  }
  
  /// Get exercise alternatives and variations for AI suggestions
  static Map<String, List<String>> getExerciseAlternatives() {
    return {
      'Chest': [
        'Push-up', 'Push-ups', 'Dumbbell Bench Press', 'Barbell Bench Press', 'Bench Press'
      ],
      'Back': [
        'Pull-ups', 'Pull-up', 'Dumbbell Bent Over Row', 'Barbell Bent Over Row', 'Bent Over Row'
      ],
      'Shoulders': [
        'Dumbbell Lateral Raise', 'Lateral Raise', 'Side Raise', 
        'Barbell Overhead Press', 'Overhead Press'
      ],
      'Arms - Biceps': [
        'Dumbbell Bicep Curl', 'Dumbbell Biceps Curl', 'Bicep Curl', 'Biceps Curl',
        'Dumbbell Hammer Curl', 'Hammer Curl'
      ],
      'Arms - Triceps': [
        'Dips', 'Push-up', 'Push-ups'
      ],
      'Legs': [
        'Barbell Squat', 'Back Squat', 'Squat', 'Barbell Deadlift', 'Deadlift'
      ],
      'Core/Abs': [
        'Crunches', 'Crunch', 'Bodyweight Crunch', 'Bicycle Crunches'
      ],
      'Cardio': [
        'Mountain Climbers', 'Mountain Climber'
      ]
    };
  }
  
  /// Generate AI-friendly exercise list with descriptions
  static String generateAIExerciseList() {
    final categories = getExercisesByCategory();
    final alternatives = getExerciseAlternatives();
    
    StringBuffer buffer = StringBuffer();
    buffer.writeln('AVAILABLE EXERCISES WITH ANIMATIONS:');
    buffer.writeln('You MUST only use exercises from this list to ensure users can see proper animations during workouts.\n');
    
    // Add categorized exercises
    categories.forEach((category, exercises) {
      if (exercises.isNotEmpty) {
        buffer.writeln('$category:');
        for (String exercise in exercises) {
          buffer.writeln('- $exercise');
        }
        buffer.writeln();
      }
    });
    
    buffer.writeln('EXERCISE ALTERNATIVES BY MUSCLE GROUP:');
    buffer.writeln('Use these alternatives to create varied routines:\n');
    
    alternatives.forEach((muscleGroup, exercises) {
      buffer.writeln('$muscleGroup: ${exercises.join(", ")}');
    });
    
    buffer.writeln('\nIMPORTANT RULES:');
    buffer.writeln('1. ONLY use exercise names from the above lists');
    buffer.writeln('2. Use exact names as listed (case-sensitive)');
    buffer.writeln('3. If you need a similar exercise not in the list, choose the closest alternative from the list');
    buffer.writeln('4. Prefer compound movements (Squat, Deadlift, Bench Press) for beginner routines');
    buffer.writeln('5. Mix bodyweight and weighted exercises for variety');
    
    return buffer.toString();
  }
  
  /// Validate if an exercise name has animation support
  static bool validateExerciseHasAnimation(String exerciseName) {
    return ExerciseAnimationData.hasAnimationForExercise(exerciseName);
  }
  
  /// Get suggested alternative for an exercise without animation
  static String? getSuggestedAlternative(String exerciseName) {
    final lowerName = exerciseName.toLowerCase();
    
    // Map common exercise patterns to animated alternatives
    final alternativeMap = {
      // Chest alternatives
      'chest press': 'Dumbbell Bench Press',
      'incline press': 'Dumbbell Bench Press',
      'decline press': 'Push-ups',
      'chest fly': 'Dumbbell Bench Press',
      
      // Back alternatives
      'lat pulldown': 'Pull-ups',
      'cable row': 'Dumbbell Bent Over Row',
      'seated row': 'Dumbbell Bent Over Row',
      't-bar row': 'Barbell Bent Over Row',
      
      // Shoulder alternatives
      'shoulder fly': 'Dumbbell Lateral Raise',
      'front raise': 'Dumbbell Lateral Raise',
      'rear delt fly': 'Dumbbell Bent Over Row',
      'upright row': 'Dumbbell Lateral Raise',
      
      // Arm alternatives
      'tricep extension': 'Dips',
      'tricep pushdown': 'Dips',
      'preacher curl': 'Dumbbell Bicep Curl',
      'concentration curl': 'Dumbbell Bicep Curl',
      
      // Leg alternatives
      'leg press': 'Barbell Squat',
      'leg curl': 'Barbell Deadlift',
      'leg extension': 'Barbell Squat',
      'calf raise': 'Barbell Squat',
      
      // Core alternatives
      'plank': 'Crunches',
      'russian twist': 'Bicycle Crunches',
      'leg raise': 'Crunches',
      'sit-up': 'Crunches',
    };
    
    // Check for direct matches
    for (String pattern in alternativeMap.keys) {
      if (lowerName.contains(pattern)) {
        return alternativeMap[pattern];
      }
    }
    
    // Fallback to general categories
    if (lowerName.contains('chest') || lowerName.contains('pec')) {
      return 'Push-ups';
    } else if (lowerName.contains('back') || lowerName.contains('lat')) {
      return 'Pull-ups';
    } else if (lowerName.contains('shoulder') || lowerName.contains('delt')) {
      return 'Dumbbell Lateral Raise';
    } else if (lowerName.contains('bicep') || lowerName.contains('curl')) {
      return 'Dumbbell Bicep Curl';
    } else if (lowerName.contains('tricep')) {
      return 'Dips';
    } else if (lowerName.contains('leg') || lowerName.contains('quad') || lowerName.contains('glute')) {
      return 'Barbell Squat';
    } else if (lowerName.contains('core') || lowerName.contains('ab')) {
      return 'Crunches';
    }
    
    return null;
  }
  
  /// Get exercise recommendations for specific goals
  static List<String> getExercisesForGoal(String goal) {
    final lowerGoal = goal.toLowerCase();
    
    if (lowerGoal.contains('beginner') || lowerGoal.contains('start')) {
      return [
        'Push-ups', 'Barbell Squat', 'Dumbbell Bent Over Row', 
        'Dumbbell Lateral Raise', 'Crunches'
      ];
    } else if (lowerGoal.contains('strength') || lowerGoal.contains('power')) {
      return [
        'Barbell Squat', 'Barbell Deadlift', 'Barbell Bench Press',
        'Barbell Overhead Press', 'Pull-ups'
      ];
    } else if (lowerGoal.contains('muscle') || lowerGoal.contains('mass') || lowerGoal.contains('bulk')) {
      return [
        'Barbell Bench Press', 'Barbell Squat', 'Barbell Deadlift',
        'Dumbbell Bicep Curl', 'Dumbbell Lateral Raise', 'Dips'
      ];
    } else if (lowerGoal.contains('tone') || lowerGoal.contains('lean')) {
      return [
        'Push-ups', 'Mountain Climbers', 'Dumbbell Lateral Raise',
        'Bicycle Crunches', 'Dumbbell Bent Over Row'
      ];
    } else if (lowerGoal.contains('cardio') || lowerGoal.contains('endurance')) {
      return [
        'Mountain Climbers', 'Push-ups', 'Bicycle Crunches', 'Pull-ups'
      ];
    } else if (lowerGoal.contains('full body') || lowerGoal.contains('total body')) {
      return [
        'Barbell Squat', 'Push-ups', 'Pull-ups', 'Dumbbell Bent Over Row',
        'Dumbbell Lateral Raise', 'Crunches'
      ];
    }
    
    // Default recommendation
    return [
      'Push-ups', 'Barbell Squat', 'Pull-ups', 'Dumbbell Bicep Curl', 'Crunches'
    ];
  }
}
