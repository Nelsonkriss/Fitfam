enum AnimationType {
  frameBased,
  singleAnimated,
}

class ExerciseAnimationData {
  final String exerciseName;
  final List<String> imagePaths;
  final String? animatedImagePath;
  final String? iconImagePath; // New field for icon image path
  final AnimationType animationType;
  final String description;
  final int frameCount;
  final Duration frameDuration;

  const ExerciseAnimationData({
    required this.exerciseName,
    required this.imagePaths,
    this.animatedImagePath,
    this.iconImagePath,
    this.animationType = AnimationType.frameBased,
    required this.description,
    this.frameCount = 2,
    this.frameDuration = const Duration(milliseconds: 800),
  });

  // Constructor for single animated files
  const ExerciseAnimationData.animated({
    required this.exerciseName,
    required this.animatedImagePath,
    this.iconImagePath,
    required this.description,
  }) : imagePaths = const [],
       animationType = AnimationType.singleAnimated,
       frameCount = 1,
       frameDuration = const Duration(milliseconds: 800);

  // Check if this exercise uses a single animated file
  bool get isAnimated => animationType == AnimationType.singleAnimated;
  
  // Get the primary image path (animated or first frame)
  String get primaryImagePath => isAnimated ? animatedImagePath! : imagePaths.first;

  // Get the icon image path or fallback to primary image path
  String get iconPath => iconImagePath ?? primaryImagePath;

  // Static map of available exercises with their animation data
  static final Map<String, ExerciseAnimationData> _exerciseAnimations = {
    // Bodyweight Exercises - Using animated .webp files
    'Push-up': ExerciseAnimationData.animated(
      exerciseName: 'Push-up',
      animatedImagePath: 'assets/exercise_images/bw_push_ups.webp',
      iconImagePath: 'assets/exercise_images/bw_push_ups_icon.webp',
      description: 'Classic upper body exercise targeting chest, shoulders, and triceps.',
    ),
    
    'Push-ups': ExerciseAnimationData.animated(
      exerciseName: 'Push-ups',
      animatedImagePath: 'assets/exercise_images/bw_push_ups.webp',
      iconImagePath: 'assets/exercise_images/bw_push_ups_icon.webp',
      description: 'Classic upper body exercise targeting chest, shoulders, and triceps.',
    ),
    
    'Mountain Climbers': ExerciseAnimationData.animated(
      exerciseName: 'Mountain Climbers',
      animatedImagePath: 'assets/exercise_images/bw_mountain_climber.webp',
      iconImagePath: 'assets/exercise_images/bw_mountain_climber_icon.webp',
      description: 'High-intensity cardio exercise alternating knee drives.',
    ),
    
    'Mountain Climber': ExerciseAnimationData.animated(
      exerciseName: 'Mountain Climber',
      animatedImagePath: 'assets/exercise_images/bw_mountain_climber.webp',
      iconImagePath: 'assets/exercise_images/bw_mountain_climber_icon.webp',
      description: 'High-intensity cardio exercise alternating knee drives.',
    ),
    
    'Crunches': ExerciseAnimationData.animated(
      exerciseName: 'Crunches',
      animatedImagePath: 'assets/exercise_images/bw_crunches.webp',
      iconImagePath: 'assets/exercise_images/bw_crunches_icon.webp',
      description: 'Basic abdominal crunch targeting rectus abdominis.',
    ),
    
    'Crunch': ExerciseAnimationData.animated(
      exerciseName: 'Crunch',
      animatedImagePath: 'assets/exercise_images/bw_crunches.webp',
      iconImagePath: 'assets/exercise_images/bw_crunches_icon.webp',
      description: 'Basic abdominal crunch targeting rectus abdominis.',
    ),
    
    'Bodyweight Crunch': ExerciseAnimationData.animated(
      exerciseName: 'Bodyweight Crunch',
      animatedImagePath: 'assets/exercise_images/bw_crunches.webp',
      iconImagePath: 'assets/exercise_images/bw_crunches_icon.webp',
      description: 'Basic abdominal crunch targeting rectus abdominis.',
    ),

    'Pull-ups': ExerciseAnimationData.animated(
      exerciseName: 'Pull-ups',
      animatedImagePath: 'assets/exercise_images/bw_pull_ups.webp',
      iconImagePath: 'assets/exercise_images/bw_pull_ups_icon.webp',
      description: 'Upper body pulling exercise targeting back and biceps.',
    ),

    'Pull-up': ExerciseAnimationData.animated(
      exerciseName: 'Pull-up',
      animatedImagePath: 'assets/exercise_images/bw_pull_ups.webp',
      iconImagePath: 'assets/exercise_images/bw_pull_ups_icon.webp',
      description: 'Upper body pulling exercise targeting back and biceps.',
    ),

    'Dips': ExerciseAnimationData.animated(
      exerciseName: 'Dips',
      animatedImagePath: 'assets/exercise_images/bw_dips.webp',
      iconImagePath: 'assets/exercise_images/bw_dips_icon.webp',
      description: 'Bodyweight exercise targeting triceps and chest.',
    ),

    'Bicycle Crunches': ExerciseAnimationData.animated(
      exerciseName: 'Bicycle Crunches',
      animatedImagePath: 'assets/exercise_images/bw_bicycle.webp',
      iconImagePath: 'assets/exercise_images/bw_bicycle_icon.webp',
      description: 'Core exercise targeting obliques and rectus abdominis.',
    ),
    
    // Dumbbell Exercises - Using animated .webp files
    'Dumbbell Bicep Curl': ExerciseAnimationData.animated(
      exerciseName: 'Dumbbell Bicep Curl',
      animatedImagePath: 'assets/exercise_images/dumbbell_bicep_curl.webp',
      iconImagePath: 'assets/exercise_images/dumbbell_bicep_curl_icon.webp',
      description: 'Isolation exercise targeting bicep muscles with dumbbells.',
    ),
    
    'Dumbbell Biceps Curl': ExerciseAnimationData.animated(
      exerciseName: 'Dumbbell Biceps Curl',
      animatedImagePath: 'assets/exercise_images/dumbbell_bicep_curl.webp',
      iconImagePath: 'assets/exercise_images/dumbbell_bicep_curl_icon.webp',
      description: 'Isolation exercise targeting bicep muscles with dumbbells.',
    ),
    
    'Bicep Curl': ExerciseAnimationData.animated(
      exerciseName: 'Bicep Curl',
      animatedImagePath: 'assets/exercise_images/dumbbell_bicep_curl.webp',
      iconImagePath: 'assets/exercise_images/dumbbell_bicep_curl_icon.webp',
      description: 'Isolation exercise targeting bicep muscles with dumbbells.',
    ),
    
    'Biceps Curl': ExerciseAnimationData.animated(
      exerciseName: 'Biceps Curl',
      animatedImagePath: 'assets/exercise_images/dumbbell_bicep_curl.webp',
      iconImagePath: 'assets/exercise_images/dumbbell_bicep_curl_icon.webp',
      description: 'Isolation exercise targeting bicep muscles with dumbbells.',
    ),
    
    'Dumbbell Lateral Raise': ExerciseAnimationData.animated(
      exerciseName: 'Dumbbell Lateral Raise',
      animatedImagePath: 'assets/exercise_images/dumbbell_lateral_raise.webp',
      iconImagePath: 'assets/exercise_images/dumbbell_lateral_raise_icon.webp',
      description: 'Shoulder isolation exercise raising dumbbells to the sides.',
    ),
    
    'Lateral Raise': ExerciseAnimationData.animated(
      exerciseName: 'Lateral Raise',
      animatedImagePath: 'assets/exercise_images/dumbbell_lateral_raise.webp',
      iconImagePath: 'assets/exercise_images/dumbbell_lateral_raise_icon.webp',
      description: 'Shoulder isolation exercise raising dumbbells to the sides.',
    ),
    
    'Side Raise': ExerciseAnimationData.animated(
      exerciseName: 'Side Raise',
      animatedImagePath: 'assets/exercise_images/dumbbell_lateral_raise.webp',
      iconImagePath: 'assets/exercise_images/dumbbell_lateral_raise_icon.webp',
      description: 'Shoulder isolation exercise raising dumbbells to the sides.',
    ),

    'Dumbbell Bench Press': ExerciseAnimationData.animated(
      exerciseName: 'Dumbbell Bench Press',
      animatedImagePath: 'assets/exercise_images/dumbbell_bench_press.webp',
      iconImagePath: 'assets/exercise_images/dumbbell_bench_press_icon.webp',
      description: 'Chest exercise using dumbbells on a bench.',
    ),

    'Dumbbell Hammer Curl': ExerciseAnimationData.animated(
      exerciseName: 'Dumbbell Hammer Curl',
      animatedImagePath: 'assets/exercise_images/dumbbell_hammer_curl.webp',
      iconImagePath: 'assets/exercise_images/dumbbell_hammer_curl_icon.webp',
      description: 'Bicep exercise with neutral grip targeting brachialis.',
    ),

    'Hammer Curl': ExerciseAnimationData.animated(
      exerciseName: 'Hammer Curl',
      animatedImagePath: 'assets/exercise_images/dumbbell_hammer_curl.webp',
      iconImagePath: 'assets/exercise_images/dumbbell_hammer_curl_icon.webp',
      description: 'Bicep exercise with neutral grip targeting brachialis.',
    ),

    'Dumbbell Bent Over Row': ExerciseAnimationData.animated(
      exerciseName: 'Dumbbell Bent Over Row',
      animatedImagePath: 'assets/exercise_images/dumbbell_bent_over.webp',
      iconImagePath: 'assets/exercise_images/dumbbell_bent_over_icon.webp',
      description: 'Back exercise targeting latissimus dorsi and rhomboids.',
    ),

    'Bent Over Row': ExerciseAnimationData.animated(
      exerciseName: 'Bent Over Row',
      animatedImagePath: 'assets/exercise_images/dumbbell_bent_over.webp',
      iconImagePath: 'assets/exercise_images/dumbbell_bent_over_icon.webp',
      description: 'Back exercise targeting latissimus dorsi and rhomboids.',
    ),

    // Barbell Exercises - Using animated .webp files
    'Barbell Squat': ExerciseAnimationData.animated(
      exerciseName: 'Barbell Squat',
      animatedImagePath: 'assets/exercise_images/barbell_back_squat.webp',
      iconImagePath: 'assets/exercise_images/barbell_back_squat_icon.webp',
      description: 'Fundamental compound movement targeting legs and glutes with barbell.',
    ),
    
    'Back Squat': ExerciseAnimationData.animated(
      exerciseName: 'Back Squat',
      animatedImagePath: 'assets/exercise_images/barbell_back_squat.webp',
      iconImagePath: 'assets/exercise_images/barbell_back_squat_icon.webp',
      description: 'Fundamental compound movement targeting legs and glutes with barbell.',
    ),
    
    'Squat': ExerciseAnimationData.animated(
      exerciseName: 'Squat',
      animatedImagePath: 'assets/exercise_images/barbell_back_squat.webp',
      iconImagePath: 'assets/exercise_images/barbell_back_squat_icon.webp',
      description: 'Fundamental compound movement targeting legs and glutes.',
    ),
    
    'Barbell Bench Press': ExerciseAnimationData.animated(
      exerciseName: 'Barbell Bench Press',
      animatedImagePath: 'assets/exercise_images/barbell_bench_press.webp',
      iconImagePath: 'assets/exercise_images/barbell_bench_press_icon.webp',
      description: 'Classic chest exercise pressing barbell from chest.',
    ),
    
    'Bench Press': ExerciseAnimationData.animated(
      exerciseName: 'Bench Press',
      animatedImagePath: 'assets/exercise_images/barbell_bench_press.webp',
      iconImagePath: 'assets/exercise_images/barbell_bench_press_icon.webp',
      description: 'Classic chest exercise pressing barbell from chest.',
    ),

    'Barbell Deadlift': ExerciseAnimationData.animated(
      exerciseName: 'Barbell Deadlift',
      animatedImagePath: 'assets/exercise_images/barbell_deadlift.webp',
      iconImagePath: 'assets/exercise_images/barbell_deadlift_icon.webp',
      description: 'Compound exercise targeting posterior chain muscles.',
    ),

    'Deadlift': ExerciseAnimationData.animated(
      exerciseName: 'Deadlift',
      animatedImagePath: 'assets/exercise_images/barbell_deadlift.webp',
      iconImagePath: 'assets/exercise_images/barbell_deadlift_icon.webp',
      description: 'Compound exercise targeting posterior chain muscles.',
    ),

    'Barbell Bent Over Row': ExerciseAnimationData.animated(
      exerciseName: 'Barbell Bent Over Row',
      animatedImagePath: 'assets/exercise_images/barbell_bent_over.webp',
      iconImagePath: 'assets/exercise_images/barbell_bent_over_icon.webp',
      description: 'Back exercise targeting latissimus dorsi and middle traps.',
    ),

    'Barbell Overhead Press': ExerciseAnimationData.animated(
      exerciseName: 'Barbell Overhead Press',
      animatedImagePath: 'assets/exercise_images/barbell_overhead_press.webp',
      iconImagePath: 'assets/exercise_images/barbell_overhead_press_icon.webp',
      description: 'Shoulder exercise pressing barbell overhead.',
    ),

    'Overhead Press': ExerciseAnimationData.animated(
      exerciseName: 'Overhead Press',
      animatedImagePath: 'assets/exercise_images/barbell_overhead_press.webp',
      iconImagePath: 'assets/exercise_images/barbell_overhead_press_icon.webp',
      description: 'Shoulder exercise pressing barbell overhead.',
    ),

    // Additional Barbell Exercises
    'Barbell Calf Raise': ExerciseAnimationData.animated(
      exerciseName: 'Barbell Calf Raise',
      animatedImagePath: 'assets/exercise_images/barbell_calf_raise.webp',
      iconImagePath: 'assets/exercise_images/barbell_calf_raise_icon.webp',
      description: 'Lower leg exercise targeting calves with barbell.',
    ),

    'Barbell Close Grip Bench Press': ExerciseAnimationData.animated(
      exerciseName: 'Barbell Close Grip Bench Press',
      animatedImagePath: 'assets/exercise_images/barbell_close_grip_bench_press.webp',
      iconImagePath: 'assets/exercise_images/barbell_close_grip_bench_press_icon.webp',
      description: 'Triceps-focused variation of the bench press.',
    ),

    'Barbell Decline Bench Press': ExerciseAnimationData.animated(
      exerciseName: 'Barbell Decline Bench Press',
      animatedImagePath: 'assets/exercise_images/barbell_decline_bench_press.webp',
      iconImagePath: 'assets/exercise_images/barbell_decline_bench_press_icon.webp',
      description: 'Lower chest focused variation of the bench press.',
    ),

    'Barbell French Press': ExerciseAnimationData.animated(
      exerciseName: 'Barbell French Press',
      animatedImagePath: 'assets/exercise_images/barbell_french_press.webp',
      iconImagePath: 'assets/exercise_images/barbell_french_press_icon.webp',
      description: 'Triceps isolation exercise with barbell.',
    ),

    'Barbell Front Raise': ExerciseAnimationData.animated(
      exerciseName: 'Barbell Front Raise',
      animatedImagePath: 'assets/exercise_images/barbell_front_raise.webp',
      iconImagePath: 'assets/exercise_images/barbell_front_raise_icon.webp',
      description: 'Anterior deltoid exercise raising barbell to front.',
    ),

    'Barbell Front Squat': ExerciseAnimationData.animated(
      exerciseName: 'Barbell Front Squat',
      animatedImagePath: 'assets/exercise_images/barbell_front_squat.webp',
      iconImagePath: 'assets/exercise_images/barbell_front_squat_icon.webp',
      description: 'Quad-focused variation of the squat with front-loaded barbell.',
    ),

    'Barbell High Pull': ExerciseAnimationData.animated(
      exerciseName: 'Barbell High Pull',
      animatedImagePath: 'assets/exercise_images/barbell_high_pull.webp',
      iconImagePath: 'assets/exercise_images/barbell_high_pull_icon.webp',
      description: 'Explosive upper body pull targeting traps and shoulders.',
    ),

    'Barbell Incline Bench Press': ExerciseAnimationData.animated(
      exerciseName: 'Barbell Incline Bench Press',
      animatedImagePath: 'assets/exercise_images/barbell_incline_bench_press.webp',
      iconImagePath: 'assets/exercise_images/barbell_incline_bench_press_icon.webp',
      description: 'Upper chest focused variation of the bench press.',
    ),

    'Barbell Lying French Press': ExerciseAnimationData.animated(
      exerciseName: 'Barbell Lying French Press',
      animatedImagePath: 'assets/exercise_images/barbell_lying_french_press.webp',
      iconImagePath: 'assets/exercise_images/barbell_lying_french_press_icon.webp',
      description: 'Lying triceps extension with barbell.',
    ),

    'Barbell Pullover': ExerciseAnimationData.animated(
      exerciseName: 'Barbell Pullover',
      animatedImagePath: 'assets/exercise_images/barbell_pullover.webp',
      iconImagePath: 'assets/exercise_images/barbell_pullover_icon.webp',
      description: 'Chest and lat exercise pulling barbell over head while lying.',
    ),

    'Barbell Reverse Bicep Curl': ExerciseAnimationData.animated(
      exerciseName: 'Barbell Reverse Bicep Curl',
      animatedImagePath: 'assets/exercise_images/barbell_reverse_bicep_curl.webp',
      iconImagePath: 'assets/exercise_images/barbell_reverse_bicep_curl_icon.webp',
      description: 'Forearm and bicep exercise with reverse grip.',
    ),

    'Barbell Reverse Grip Bent Over Row': ExerciseAnimationData.animated(
      exerciseName: 'Barbell Reverse Grip Bent Over Row',
      animatedImagePath: 'assets/exercise_images/barbell_reverse_grip_bent_over.webp',
      iconImagePath: 'assets/exercise_images/barbell_reverse_grip_bent_over_icon.webp',
      description: 'Back exercise with underhand grip targeting lower lats.',
    ),

    'Barbell Shrug': ExerciseAnimationData.animated(
      exerciseName: 'Barbell Shrug',
      animatedImagePath: 'assets/exercise_images/barbell_shrug.webp',
      iconImagePath: 'assets/exercise_images/barbell_shrug_icon.webp',
      description: 'Trapezius isolation exercise with barbell.',
    ),

    // Additional Dumbbell Exercises
    'Dumbbell Alternate Bicep Curl': ExerciseAnimationData.animated(
      exerciseName: 'Dumbbell Alternate Bicep Curl',
      animatedImagePath: 'assets/exercise_images/dumbbell_alt_bicep_curl.webp',
      iconImagePath: 'assets/exercise_images/dumbbell_alt_bicep_curl_icon.webp',
      description: 'Alternating arm bicep curls with dumbbells.',
    ),

    'Dumbbell Alternate Hammer Curl': ExerciseAnimationData.animated(
      exerciseName: 'Dumbbell Alternate Hammer Curl',
      animatedImagePath: 'assets/exercise_images/dumbbell_alt_hammer_curl.webp',
      iconImagePath: 'assets/exercise_images/dumbbell_alt_hammer_curl_icon.webp',
      description: 'Alternating arm hammer curls targeting brachialis.',
    ),

    'Dumbbell Arnold Press': ExerciseAnimationData.animated(
      exerciseName: 'Dumbbell Arnold Press',
      animatedImagePath: 'assets/exercise_images/dumbbell_arnold_press.webp',
      iconImagePath: 'assets/exercise_images/dumbbell_arnold_press_icon.webp',
      description: 'Complex shoulder press with rotation movement.',
    ),

    'Dumbbell Bench Bent Over Row': ExerciseAnimationData.animated(
      exerciseName: 'Dumbbell Bench Bent Over Row',
      animatedImagePath: 'assets/exercise_images/dumbbell_bench_bent_over.webp',
      iconImagePath: 'assets/exercise_images/dumbbell_bench_bent_over_icon.webp',
      description: 'Single-arm back exercise supported on bench.',
    ),

    'Dumbbell Bench Flyes': ExerciseAnimationData.animated(
      exerciseName: 'Dumbbell Bench Flyes',
      animatedImagePath: 'assets/exercise_images/dumbbell_bench_flyes.webp',
      iconImagePath: 'assets/exercise_images/dumbbell_bench_flyes_icon.webp',
      description: 'Chest isolation exercise with wide arm movement.',
    ),

    'Dumbbell Calf Raise': ExerciseAnimationData.animated(
      exerciseName: 'Dumbbell Calf Raise',
      animatedImagePath: 'assets/exercise_images/dumbbell_calf_raise.webp',
      iconImagePath: 'assets/exercise_images/dumbbell_calf_raise_icon.webp',
      description: 'Lower leg exercise targeting calves with dumbbells.',
    ),

    'Dumbbell Concentration Curl': ExerciseAnimationData.animated(
      exerciseName: 'Dumbbell Concentration Curl',
      animatedImagePath: 'assets/exercise_images/dumbbell_concentration_bicep_curl.webp',
      iconImagePath: 'assets/exercise_images/dumbbell_concentration_bicep_curl_icon.webp',
      description: 'Seated single-arm bicep isolation exercise.',
    ),

    'Dumbbell Deadlift': ExerciseAnimationData.animated(
      exerciseName: 'Dumbbell Deadlift',
      animatedImagePath: 'assets/exercise_images/dumbbell_deadlift.webp',
      iconImagePath: 'assets/exercise_images/dumbbell_deadlift_icon.webp',
      description: 'Full body pulling exercise with dumbbells.',
    ),

    'Dumbbell Decline Bench Fly': ExerciseAnimationData.animated(
      exerciseName: 'Dumbbell Decline Bench Fly',
      animatedImagePath: 'assets/exercise_images/dumbbell_decline_bench_fly.webp',
      iconImagePath: 'assets/exercise_images/dumbbell_decline_bench_fly_icon.webp',
      description: 'Lower chest focused fly movement on decline bench.',
    ),

    'Dumbbell Decline Bench Press': ExerciseAnimationData.animated(
      exerciseName: 'Dumbbell Decline Bench Press',
      animatedImagePath: 'assets/exercise_images/dumbbell_decline_bench_press.webp',
      iconImagePath: 'assets/exercise_images/dumbbell_decline_bench_press_icon.webp',
      description: 'Lower chest focused press on decline bench.',
    ),

    'Dumbbell French Press': ExerciseAnimationData.animated(
      exerciseName: 'Dumbbell French Press',
      animatedImagePath: 'assets/exercise_images/dumbbell_french_press.webp',
      iconImagePath: 'assets/exercise_images/dumbbell_french_press_icon.webp',
      description: 'Triceps isolation exercise with dumbbell.',
    ),

    'Dumbbell Front Raise': ExerciseAnimationData.animated(
      exerciseName: 'Dumbbell Front Raise',
      animatedImagePath: 'assets/exercise_images/dumbbell_front_raise.webp',
      iconImagePath: 'assets/exercise_images/dumbbell_front_raise_icon.webp',
      description: 'Anterior deltoid exercise raising dumbbells to front.',
    ),

    'Dumbbell Incline Bench Flyes': ExerciseAnimationData.animated(
      exerciseName: 'Dumbbell Incline Bench Flyes',
      animatedImagePath: 'assets/exercise_images/dumbbell_incline_bench_flyes.webp',
      iconImagePath: 'assets/exercise_images/dumbbell_incline_bench_flyes_icon.webp',
      description: 'Upper chest focused fly movement on incline bench.',
    ),

    'Dumbbell Incline Bench Press': ExerciseAnimationData.animated(
      exerciseName: 'Dumbbell Incline Bench Press',
      animatedImagePath: 'assets/exercise_images/dumbbell_incline_bench_press.webp',
      iconImagePath: 'assets/exercise_images/dumbbell_incline_bench_press_icon.webp',
      description: 'Upper chest focused press on incline bench.',
    ),

    'Dumbbell Lunges': ExerciseAnimationData.animated(
      exerciseName: 'Dumbbell Lunges',
      animatedImagePath: 'assets/exercise_images/dumbbell_lunges.webp',
      iconImagePath: 'assets/exercise_images/dumbbell_lunges_icon.webp',
      description: 'Lower body exercise stepping forward with dumbbells.',
    ),

    // Additional Bodyweight Exercises
    'Hanging Leg Raises': ExerciseAnimationData.animated(
      exerciseName: 'Hanging Leg Raises',
      animatedImagePath: 'assets/exercise_images/bw_hang_leg_raises.webp',
      iconImagePath: 'assets/exercise_images/bw_hang_leg_raises_icon.webp',
      description: 'Advanced core exercise raising legs while hanging.',
    ),

    'Lying Leg Raises': ExerciseAnimationData.animated(
      exerciseName: 'Lying Leg Raises',
      animatedImagePath: 'assets/exercise_images/bw_lying_leg_rises.webp',
      iconImagePath: 'assets/exercise_images/bw_lying_leg_rises_icon.webp',
      description: 'Core exercise raising legs while lying on back.',
    ),
  };

  // Alternative exercise names mapping for better matching
  static final Map<String, String> _exerciseNameMappings = {
    // Common variations and synonyms
    'bicep curl': 'Dumbbell Bicep Curl',
    'biceps curl': 'Dumbbell Bicep Curl',
    'curls': 'Dumbbell Bicep Curl',
    'dumbbell curl': 'Dumbbell Bicep Curl',
    'hammer curl': 'Dumbbell Hammer Curl',
    
    'push up': 'Push-up',
    'pushup': 'Push-up',
    'push-ups': 'Push-up',
    'pushups': 'Push-up',
    
    'lunge': 'Bodyweight Lunge',
    'lunges': 'Bodyweight Lunge',
    'forward lunge': 'Bodyweight Lunge',
    
    'squat': 'Barbell Squat',
    'squats': 'Barbell Squat',
    'back squat': 'Barbell Squat',
    
    'shoulder press': 'Dumbbell Shoulder Press',
    'overhead press': 'Barbell Overhead Press',
    'military press': 'Barbell Overhead Press',
    
    'lateral raise': 'Dumbbell Lateral Raise',
    'side raise': 'Dumbbell Lateral Raise',
    'lateral raises': 'Dumbbell Lateral Raise',
    
    'bent over row': 'Dumbbell Bent Over Row',
    'dumbbell row': 'Dumbbell Bent Over Row',
    'rows': 'Dumbbell Bent Over Row',
    
    'jumping jack': 'Jumping Jacks',
    'jumping jacks': 'Jumping Jacks',
    'star jump': 'Jumping Jacks',
    
    'mountain climber': 'Mountain Climbers',
    'mountain climbers': 'Mountain Climbers',
    
    'leg raises': 'Leg Raise',
    'leg raise': 'Leg Raise',
    'lying leg raise': 'Leg Raise',
    
    'crunches': 'Crunches',
    'crunch': 'Crunch',
    'ab crunch': 'Crunch',
    
    'situp': 'Sit-up',
    'sit up': 'Sit-up',
    'situps': 'Sit-up',
    'sit ups': 'Sit-up',
  };

  // Get exercise animation data by name
  static ExerciseAnimationData? getExerciseAnimation(String exerciseName) {
    // Try exact match first
    if (_exerciseAnimations.containsKey(exerciseName)) {
      return _exerciseAnimations[exerciseName];
    }
    
    // Try case-insensitive exact match
    final lowerCaseName = exerciseName.toLowerCase();
    for (final key in _exerciseAnimations.keys) {
      if (key.toLowerCase() == lowerCaseName) {
        return _exerciseAnimations[key];
      }
    }
    
    // Try mapping variations
    if (_exerciseNameMappings.containsKey(lowerCaseName)) {
      final mappedName = _exerciseNameMappings[lowerCaseName]!;
      return _exerciseAnimations[mappedName];
    }
    
    // Try partial matching
    for (final key in _exerciseAnimations.keys) {
      if (key.toLowerCase().contains(lowerCaseName) || 
          lowerCaseName.contains(key.toLowerCase())) {
        return _exerciseAnimations[key];
      }
    }
    
    return null;
  }

  // Check if exercise has animation
  static bool hasAnimationForExercise(String exerciseName) {
    return getExerciseAnimation(exerciseName) != null;
  }

  // Get all available exercise names
  static List<String> getAllExerciseNames() {
    return _exerciseAnimations.keys.toList()..sort();
  }
  
  // Get exercises grouped by equipment type for AI understanding
  static Map<String, List<String>> getExercisesByEquipment() {
    final allExercises = _exerciseAnimations.keys.toList();
    
    return {
      'Bodyweight': allExercises.where((exercise) => 
        !exercise.toLowerCase().contains('dumbbell') &&
        !exercise.toLowerCase().contains('barbell') &&
        (exercise.toLowerCase().contains('push-up') ||
         exercise.toLowerCase().contains('pull-up') ||
         exercise.toLowerCase().contains('mountain climber') ||
         exercise.toLowerCase().contains('crunch') ||
         exercise.toLowerCase().contains('dips') ||
         exercise.toLowerCase().contains('bicycle'))
      ).toList(),
      
      'Dumbbell': allExercises.where((exercise) => 
        exercise.toLowerCase().contains('dumbbell') ||
        (!exercise.toLowerCase().contains('barbell') && (
          exercise.toLowerCase().contains('bicep curl') ||
          exercise.toLowerCase().contains('lateral raise') ||
          exercise.toLowerCase().contains('hammer curl') ||
          (exercise.toLowerCase().contains('bent over row') && !exercise.toLowerCase().contains('barbell'))
        ))
      ).toList(),
      
      'Barbell': allExercises.where((exercise) => 
        exercise.toLowerCase().contains('barbell') ||
        (!exercise.toLowerCase().contains('dumbbell') && (
          exercise.toLowerCase().contains('squat') ||
          exercise.toLowerCase().contains('bench press') ||
          exercise.toLowerCase().contains('deadlift') ||
          exercise.toLowerCase().contains('overhead press')
        ))
      ).toList(),
    };
  }
  
  // Get exercise count for AI statistics
  static Map<String, int> getExerciseStatistics() {
    final byEquipment = getExercisesByEquipment();
    return {
      'Total Available Exercises': _exerciseAnimations.length,
      'Bodyweight Exercises': byEquipment['Bodyweight']?.length ?? 0,
      'Dumbbell Exercises': byEquipment['Dumbbell']?.length ?? 0,
      'Barbell Exercises': byEquipment['Barbell']?.length ?? 0,
    };
  }

  // Search exercises by partial name
  static List<String> searchExercises(String query) {
    if (query.isEmpty) return getAllExerciseNames();
    
    final lowerQuery = query.toLowerCase();
    final results = <String>[];
    
    // Add exact matches first
    for (final name in _exerciseAnimations.keys) {
      if (name.toLowerCase().contains(lowerQuery)) {
        results.add(name);
      }
    }
    
    // Add mapped variations
    for (final entry in _exerciseNameMappings.entries) {
      if (entry.key.contains(lowerQuery) && !results.contains(entry.value)) {
        results.add(entry.value);
      }
    }
    
    return results..sort();
  }
}
