import 'dart:convert';

enum FitnessGoal {
  buildMuscle,
  loseWeight,
  improveStrength,
  improveEndurance,
  maintainFitness;

  String get displayName {
    switch (this) {
      case FitnessGoal.buildMuscle:
        return 'Build Muscle';
      case FitnessGoal.loseWeight:
        return 'Lose Weight';
      case FitnessGoal.improveStrength:
        return 'Improve Strength';
      case FitnessGoal.improveEndurance:
        return 'Improve Endurance';
      case FitnessGoal.maintainFitness:
        return 'Maintain Fitness';
    }
  }
}

enum AvailableEquipment {
  barbell,
  dumbbell,
  kettlebell,
  bodyweight,
  machine,
  bands,
  other;

  String get displayName {
    switch (this) {
      case AvailableEquipment.barbell:
        return 'Barbell';
      case AvailableEquipment.dumbbell:
        return 'Dumbbell';
      case AvailableEquipment.kettlebell:
        return 'Kettlebell';
      case AvailableEquipment.bodyweight:
        return 'Bodyweight';
      case AvailableEquipment.machine:
        return 'Machine';
      case AvailableEquipment.bands:
        return 'Bands';
      case AvailableEquipment.other:
        return 'Other';
    }
  }
}

/// Enum representing different fitness levels
enum FitnessLevel {
  beginner,
  intermediate,
  advanced;

  String get displayName {
    switch (this) {
      case FitnessLevel.beginner:
        return 'Beginner';
      case FitnessLevel.intermediate:
        return 'Intermediate';
      case FitnessLevel.advanced:
        return 'Advanced';
    }
  }

  String get description {
    switch (this) {
      case FitnessLevel.beginner:
        return 'New to working out or returning after a long break';
      case FitnessLevel.intermediate:
        return 'Regular workout routine for 6+ months';
      case FitnessLevel.advanced:
        return 'Experienced lifter with 2+ years of consistent training';
    }
  }
}

/// Model representing user profile information
class UserProfile {
  final double height; // in cm
  final double weight; // in kg
  final FitnessLevel fitnessLevel;
  final FitnessGoal fitnessGoal;
  final List<AvailableEquipment> availableEquipment;
  final String? displayName;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserProfile({
    required this.height,
    required this.weight,
    required this.fitnessLevel,
    required this.fitnessGoal,
    required this.availableEquipment,
    this.displayName,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Creates a copy of this profile with updated values
  UserProfile copyWith({
    double? height,
    double? weight,
    FitnessLevel? fitnessLevel,
    FitnessGoal? fitnessGoal,
    List<AvailableEquipment>? availableEquipment,
    String? displayName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      height: height ?? this.height,
      weight: weight ?? this.weight,
      fitnessLevel: fitnessLevel ?? this.fitnessLevel,
      fitnessGoal: fitnessGoal ?? this.fitnessGoal,
      availableEquipment: availableEquipment ?? this.availableEquipment,
      displayName: displayName ?? this.displayName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Calculates BMI (Body Mass Index)
  double get bmi {
    final heightInMeters = height / 100;
    return weight / (heightInMeters * heightInMeters);
  }

  /// Gets BMI category
  String get bmiCategory {
    final bmiValue = bmi;
    if (bmiValue < 18.5) return 'Underweight';
    if (bmiValue < 25) return 'Normal weight';
    if (bmiValue < 30) return 'Overweight';
    return 'Obese';
  }

  /// Gets suggested starting weights based on fitness level and body weight
  Map<String, double> get suggestedStartingWeights {
    double multiplier;
    switch (fitnessLevel) {
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

    final baseWeight = weight * multiplier;
    
    return {
      'bench_press': (baseWeight * 0.8).roundToDouble(),
      'squat': (baseWeight * 1.2).roundToDouble(),
      'deadlift': (baseWeight * 1.4).roundToDouble(),
      'overhead_press': (baseWeight * 0.5).roundToDouble(),
      'barbell_row': (baseWeight * 0.7).roundToDouble(),
      'dumbbell_curl': (baseWeight * 0.2).roundToDouble(),
      'tricep_extension': (baseWeight * 0.25).roundToDouble(),
      'lateral_raise': (baseWeight * 0.1).roundToDouble(),
    };
  }

  /// Gets workout frequency recommendation based on fitness level
  int get recommendedWorkoutFrequency {
    switch (fitnessLevel) {
      case FitnessLevel.beginner:
        return 3; // 3 days per week
      case FitnessLevel.intermediate:
        return 4; // 4 days per week
      case FitnessLevel.advanced:
        return 5; // 5-6 days per week
    }
  }

  /// Gets rest time recommendations in seconds
  Map<String, int> get recommendedRestTimes {
    switch (fitnessLevel) {
      case FitnessLevel.beginner:
        return {
          'compound': 120, // 2 minutes for compound exercises
          'isolation': 60, // 1 minute for isolation exercises
        };
      case FitnessLevel.intermediate:
        return {
          'compound': 180, // 3 minutes for compound exercises
          'isolation': 90, // 1.5 minutes for isolation exercises
        };
      case FitnessLevel.advanced:
        return {
          'compound': 240, // 4 minutes for compound exercises
          'isolation': 120, // 2 minutes for isolation exercises
        };
    }
  }

  /// Converts the profile to a JSON map for storage
  Map<String, dynamic> toJson() {
    return {
      'height': height,
      'weight': weight,
      'fitnessLevel': fitnessLevel.name,
      'fitnessGoal': fitnessGoal.name,
      'availableEquipment': availableEquipment.map((e) => e.name).toList(),
      'displayName': displayName,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Creates a UserProfile from a JSON map
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      height: (json['height'] as num).toDouble(),
      weight: (json['weight'] as num).toDouble(),
      fitnessLevel: FitnessLevel.values.byName(json['fitnessLevel'] as String),
      fitnessGoal: FitnessGoal.values.byName(json['fitnessGoal'] as String),
      availableEquipment: (json['availableEquipment'] as List<dynamic>)
          .map((e) => AvailableEquipment.values.byName(e as String))
          .toList(),
      displayName: json['displayName'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  /// Converts the profile to a JSON string
  String toJsonString() {
    return jsonEncode(toJson());
  }

  /// Creates a UserProfile from a JSON string
  factory UserProfile.fromJsonString(String jsonString) {
    final Map<String, dynamic> json = jsonDecode(jsonString);
    return UserProfile.fromJson(json);
  }

  /// Creates a new profile with current timestamp
  factory UserProfile.create({
    required double height,
    required double weight,
    required FitnessLevel fitnessLevel,
    required FitnessGoal fitnessGoal,
    required List<AvailableEquipment> availableEquipment,
    String? displayName,
  }) {
    final now = DateTime.now();
    return UserProfile(
      height: height,
      weight: weight,
      fitnessLevel: fitnessLevel,
      fitnessGoal: fitnessGoal,
      availableEquipment: availableEquipment,
      displayName: displayName,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Updates the profile with new values and current timestamp
  UserProfile update({
    double? height,
    double? weight,
    FitnessLevel? fitnessLevel,
    FitnessGoal? fitnessGoal,
    List<AvailableEquipment>? availableEquipment,
    String? displayName,
  }) {
    return copyWith(
      height: height,
      weight: weight,
      fitnessLevel: fitnessLevel,
      fitnessGoal: fitnessGoal,
      availableEquipment: availableEquipment,
      displayName: displayName,
      updatedAt: DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'UserProfile(height: ${height}cm, weight: ${weight}kg, level: ${fitnessLevel.displayName}, goal: ${fitnessGoal.displayName}, name: ${displayName ?? ''}, bmi: ${bmi.toStringAsFixed(1)})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserProfile &&
        other.height == height &&
        other.weight == weight &&
        other.fitnessLevel == fitnessLevel &&
        other.fitnessGoal == fitnessGoal &&
        other.availableEquipment == availableEquipment &&
        other.displayName == displayName &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(height, weight, fitnessLevel, fitnessGoal, availableEquipment, displayName, createdAt, updatedAt);
  }
}
