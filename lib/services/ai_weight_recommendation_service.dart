import 'dart:math';
import '../models/user_profile.dart';
import '../models/workout_session.dart';
import '../models/exercise_performance.dart';
import '../models/set_performance.dart';
import '../resource/db_provider.dart';

/// Service that provides AI-powered weight recommendations for exercises
class AIWeightRecommendationService {
  static final AIWeightRecommendationService _instance = AIWeightRecommendationService._internal();
  factory AIWeightRecommendationService() => _instance;
  AIWeightRecommendationService._internal();

  /// Gets recommended weight for an exercise based on user profile and workout history
  Future<double> getRecommendedWeight({
    required String exerciseName,
    required UserProfile? userProfile,
    int targetReps = 10,
  }) async {
    try {
      // Get workout history for this exercise
      final workoutHistory = await _getExerciseHistory(exerciseName);
      
      // If user has history with this exercise, use progressive recommendation
      if (workoutHistory.isNotEmpty) {
        return _calculateProgressiveRecommendation(workoutHistory, targetReps);
      }
      
      // If no history but user profile exists, use profile-based recommendation
      if (userProfile != null) {
        return _calculateProfileBasedRecommendation(exerciseName, userProfile, targetReps);
      }
      
      // Fallback to basic exercise-specific defaults
      return _getDefaultWeight(exerciseName, targetReps);
    } catch (e) {
      print('Error getting weight recommendation: $e');
      return _getDefaultWeight(exerciseName, targetReps);
    }
  }

  /// Gets exercise history from workout sessions
  Future<List<ExerciseHistoryData>> _getExerciseHistory(String exerciseName) async {
    try {
      final sessions = await dbProvider.getWorkoutSessions();
      final List<ExerciseHistoryData> history = [];
      
      for (final session in sessions) {
        for (final exercise in session.exercises) {
          if (_normalizeExerciseName(exercise.exerciseName) == _normalizeExerciseName(exerciseName)) {
            for (final set in exercise.sets) {
              if (set.isCompleted) {
                history.add(ExerciseHistoryData(
                  date: session.startTime,
                  weight: set.actualWeight,
                  reps: set.actualReps,
                  targetReps: set.targetReps,
                ));
              }
            }
          }
        }
      }
      
      // Sort by date (most recent first)
      history.sort((a, b) => b.date.compareTo(a.date));
      return history;
    } catch (e) {
      print('Error fetching exercise history: $e');
      return [];
    }
  }

  /// Calculates progressive recommendation based on workout history
  double _calculateProgressiveRecommendation(List<ExerciseHistoryData> history, int targetReps) {
    if (history.isEmpty) return 0.0;
    
    // Get recent performance (last 5 workouts)
    final recentHistory = history.take(5).toList();
    
    // Calculate average weight for similar rep ranges
    final similarRepHistory = recentHistory.where((data) => 
      (data.targetReps - targetReps).abs() <= 2
    ).toList();
    
    if (similarRepHistory.isNotEmpty) {
      // Calculate weighted average (more recent workouts have higher weight)
      double totalWeight = 0;
      double totalWeightFactor = 0;
      
      for (int i = 0; i < similarRepHistory.length; i++) {
        final weightFactor = 1.0 / (i + 1); // Recent workouts get higher weight
        totalWeight += similarRepHistory[i].weight * weightFactor;
        totalWeightFactor += weightFactor;
      }
      
      final averageWeight = totalWeight / totalWeightFactor;
      
      // Apply progressive overload (small increase)
      final progressionFactor = _calculateProgressionFactor(similarRepHistory);
      return (averageWeight * progressionFactor).roundToDouble();
    }
    
    // If no similar rep range, use rep conversion
    final mostRecentData = recentHistory.first;
    return _convertWeightForReps(mostRecentData.weight, mostRecentData.reps, targetReps);
  }

  /// Calculates progression factor based on recent performance trends
  double _calculateProgressionFactor(List<ExerciseHistoryData> history) {
    if (history.length < 2) return 1.02; // Small 2% increase for new exercises
    
    // Analyze performance trend
    final recent = history.take(3).toList();
    bool isProgressing = true;
    
    for (int i = 0; i < recent.length - 1; i++) {
      if (recent[i].weight < recent[i + 1].weight) {
        isProgressing = false;
        break;
      }
    }
    
    if (isProgressing) {
      return 1.025; // 2.5% increase if progressing well
    } else {
      return 1.0; // No increase if struggling
    }
  }

  /// Converts weight recommendation between different rep ranges
  double _convertWeightForReps(double weight, int fromReps, int toReps) {
    if (fromReps == toReps) return weight;
    
    // Use Epley formula for 1RM estimation and conversion
    final oneRM = weight * (1 + fromReps / 30.0);
    final newWeight = oneRM / (1 + toReps / 30.0);
    
    return max(0.0, newWeight.roundToDouble());
  }

  /// Calculates recommendation based on user profile
  double _calculateProfileBasedRecommendation(String exerciseName, UserProfile userProfile, int targetReps) {
    final baseWeights = userProfile.suggestedStartingWeights;
    final normalizedName = _normalizeExerciseName(exerciseName);
    
    // Check for exact matches first
    if (baseWeights.containsKey(normalizedName)) {
      return _adjustForReps(baseWeights[normalizedName]!, targetReps);
    }
    
    // Check for partial matches or exercise categories
    final recommendedWeight = _getWeightByExerciseCategory(exerciseName, userProfile);
    return _adjustForReps(recommendedWeight, targetReps);
  }

  /// Gets weight recommendation based on exercise category
  double _getWeightByExerciseCategory(String exerciseName, UserProfile userProfile) {
    final normalizedName = _normalizeExerciseName(exerciseName);
    final bodyWeight = userProfile.weight;
    
    double multiplier;
    switch (userProfile.fitnessLevel) {
      case FitnessLevel.beginner:
        multiplier = 0.3;
        break;
      case FitnessLevel.intermediate:
        multiplier = 0.6;
        break;
      case FitnessLevel.advanced:
        multiplier = 1.0;
        break;
    }
    
    // Categorize exercises and provide appropriate weights
    if (_isCompoundMovement(normalizedName)) {
      if (_isLowerBodyExercise(normalizedName)) {
        return (bodyWeight * multiplier * 1.2).roundToDouble(); // Legs are stronger
      } else if (_isPushingExercise(normalizedName)) {
        return (bodyWeight * multiplier * 0.8).roundToDouble(); // Chest/shoulders
      } else if (_isPullingExercise(normalizedName)) {
        return (bodyWeight * multiplier * 0.7).roundToDouble(); // Back
      }
    } else {
      // Isolation exercises
      if (_isArmExercise(normalizedName)) {
        return (bodyWeight * multiplier * 0.2).roundToDouble(); // Arms
      } else if (_isShoulderExercise(normalizedName)) {
        return (bodyWeight * multiplier * 0.15).roundToDouble(); // Shoulders
      }
    }
    
    // Default fallback
    return (bodyWeight * multiplier * 0.4).roundToDouble();
  }

  /// Adjusts weight based on target rep range
  double _adjustForReps(double baseWeight, int targetReps) {
    if (targetReps <= 5) {
      return (baseWeight * 1.2).roundToDouble(); // Strength range
    } else if (targetReps <= 8) {
      return baseWeight; // Hypertrophy range
    } else if (targetReps <= 15) {
      return (baseWeight * 0.8).roundToDouble(); // Endurance range
    } else {
      return (baseWeight * 0.6).roundToDouble(); // High rep range
    }
  }

  /// Gets default weight for exercises without user data
  double _getDefaultWeight(String exerciseName, int targetReps) {
    final normalizedName = _normalizeExerciseName(exerciseName);
    
    final Map<String, double> defaultWeights = {
      'bench_press': 40.0,
      'squat': 50.0,
      'deadlift': 60.0,
      'overhead_press': 25.0,
      'barbell_row': 35.0,
      'dumbbell_curl': 8.0,
      'tricep_extension': 10.0,
      'lateral_raise': 5.0,
      'leg_press': 80.0,
      'lat_pulldown': 30.0,
      'chest_press': 30.0,
      'shoulder_press': 20.0,
    };
    
    double baseWeight = defaultWeights[normalizedName] ?? 15.0;
    return _adjustForReps(baseWeight, targetReps);
  }

  /// Normalizes exercise name for comparison
  String _normalizeExerciseName(String name) {
    return name.toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
  }

  /// Exercise categorization methods
  bool _isCompoundMovement(String exerciseName) {
    final compoundKeywords = [
      'squat', 'deadlift', 'bench_press', 'overhead_press', 'row', 'pull_up',
      'chin_up', 'dip', 'lunge', 'clean', 'snatch', 'thruster'
    ];
    return compoundKeywords.any((keyword) => exerciseName.contains(keyword));
  }

  bool _isLowerBodyExercise(String exerciseName) {
    final lowerBodyKeywords = [
      'squat', 'deadlift', 'lunge', 'leg', 'calf', 'glute', 'hip', 'quad', 'hamstring'
    ];
    return lowerBodyKeywords.any((keyword) => exerciseName.contains(keyword));
  }

  bool _isPushingExercise(String exerciseName) {
    final pushKeywords = [
      'bench', 'press', 'push', 'dip', 'tricep', 'chest', 'shoulder'
    ];
    return pushKeywords.any((keyword) => exerciseName.contains(keyword));
  }

  bool _isPullingExercise(String exerciseName) {
    final pullKeywords = [
      'row', 'pull', 'lat', 'chin', 'curl', 'back', 'rear'
    ];
    return pullKeywords.any((keyword) => exerciseName.contains(keyword));
  }

  bool _isArmExercise(String exerciseName) {
    final armKeywords = [
      'curl', 'tricep', 'bicep', 'arm', 'extension', 'hammer'
    ];
    return armKeywords.any((keyword) => exerciseName.contains(keyword));
  }

  bool _isShoulderExercise(String exerciseName) {
    final shoulderKeywords = [
      'lateral', 'raise', 'fly', 'reverse', 'rear', 'front', 'shoulder'
    ];
    return shoulderKeywords.any((keyword) => exerciseName.contains(keyword));
  }

  /// Gets multiple weight recommendations for different rep ranges
  Future<Map<int, double>> getWeightRecommendationsForRepRanges({
    required String exerciseName,
    required UserProfile? userProfile,
    List<int> repRanges = const [5, 8, 10, 12, 15],
  }) async {
    final Map<int, double> recommendations = {};
    
    for (final reps in repRanges) {
      recommendations[reps] = await getRecommendedWeight(
        exerciseName: exerciseName,
        userProfile: userProfile,
        targetReps: reps,
      );
    }
    
    return recommendations;
  }

  /// Gets confidence level for the recommendation
  Future<double> getRecommendationConfidence({
    required String exerciseName,
    required UserProfile? userProfile,
  }) async {
    final history = await _getExerciseHistory(exerciseName);
    
    if (history.length >= 5) {
      return 0.9; // High confidence with good history
    } else if (history.length >= 2) {
      return 0.7; // Medium confidence with some history
    } else if (userProfile != null) {
      return 0.5; // Low-medium confidence with profile only
    } else {
      return 0.3; // Low confidence with defaults only
    }
  }
}

/// Data class for exercise history
class ExerciseHistoryData {
  final DateTime date;
  final double weight;
  final int reps;
  final int targetReps;

  ExerciseHistoryData({
    required this.date,
    required this.weight,
    required this.reps,
    required this.targetReps,
  });
}
