import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For input formatters in dialog
import 'package:flutter_bloc/flutter_bloc.dart';
// Use updated models
import 'package:workout_planner/models/routine.dart';
// Needed for models used by WorkoutSession
// Needed for models used by Routine

// Import the BLoC files (Events, States, Bloc itself)
import 'package:workout_planner/bloc/workout_session_bloc.dart';

// Import the global dbProvider instance
import 'package:workout_planner/resource/db_provider.dart';

import '../models/exercise_performance.dart';
import '../models/set_performance.dart'; // Adjust path if needed
import '../ui/components/exercise_animation_widget.dart';
import '../ui/components/enhanced_animation_widgets.dart';
import '../models/exercise_animation_data.dart';
import '../services/ai_weight_recommendation_service.dart';
import '../models/user_profile.dart';
import '../resource/shared_prefs_provider.dart';

// WeightRecommendation class for AI recommendations
class WeightRecommendation {
  final double recommendedWeight;
  final String reasoning;
  final List<String> tips;
  final double? confidenceLevel;

  WeightRecommendation({
    required this.recommendedWeight,
    required this.reasoning,
    required this.tips,
    this.confidenceLevel,
  });
}

class WorkoutSessionPage extends StatelessWidget {
  final Routine routine;

  const WorkoutSessionPage({super.key, required this.routine});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<WorkoutSessionBloc>( // Explicitly type BlocProvider
      create: (context) => WorkoutSessionBloc(dbProvider: dbProvider) // Pass dbProvider
        ..add(WorkoutSessionStartNew(routine)), // Instantiate and add correct event
      child: Scaffold(
        appBar: AppBar(
          title: Text(routine.routineName),
          actions: [
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                // Optional: Confirmation Dialog
                showDialog(
                    context: context,
                    builder: (confirmCtx) => AlertDialog(
                      title: const Text('Cancel Workout?'),
                      content: const Text('Are you sure you want to cancel this session? Progress will not be saved.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(confirmCtx), child: const Text('Continue Workout')),
                        TextButton(
                            onPressed: () {
                              Navigator.pop(confirmCtx); // Close dialog
                              Navigator.pop(context); // Close page
                            },
                            child: const Text('Cancel Session', style: TextStyle(color: Colors.red))
                        ),
                      ],
                    )
                );
              },
            ),
          ],
        ),
        child: BlocBuilder<WorkoutSessionBloc, WorkoutSessionState>(
          builder: (context, state) {
            if (state.isLoading && state.session == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.session == null && !state.isLoading) {
              return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      state.errorMessage ?? 'Failed to load workout session.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.red[700]),
                    ),
                  )
              );
            }
            if (state.session != null) {
              return Stack(
                children: [
                  Column(
                    children: [
                      _TimerDisplay(),
                      Expanded(
                        child: _ExerciseList(),
                      ),
                      _SessionControls(),
                    ],
                  ),
                  if (state.isLoading && state.isFinished) // Show loading overlay when finishing
                    Container(
                      color: Colors.black.withOpacity(0.5),
                      child: const Center(
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(color: Colors.white),
                                SizedBox(height: 10),
                                Text("Finishing...", style: TextStyle(color: Colors.white, fontSize: 16)),
                              ]
                          )
                      ),
                    ),
                ],
              );
            }
            return const Center(child: Text('An unexpected error occurred.')); // Fallback
          },
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
        floatingActionButton: BlocBuilder<WorkoutSessionBloc, WorkoutSessionState>(
          builder: (context, state) {
            if (state.session != null && state.session!.exercises.isNotEmpty && state.session!.currentExerciseIndex < state.session!.exercises.length) {
              final currentExerciseName = state.session!.exercises[state.session!.currentExerciseIndex].exerciseName;
              print('[FAB] Current Exercise Name: "$currentExerciseName"');
              bool hasAnimation = ExerciseAnimationData.hasAnimationForExercise(currentExerciseName);
              print('[FAB] Has Animation: $hasAnimation');
              Widget fabContent;

              if (hasAnimation) {
                print('[FAB] Using ExerciseAnimationWidget for FAB.');
                fabContent = ExerciseAnimationWidget(
                  exerciseName: currentExerciseName,
                  width: 40, // Smaller size for FAB
                  height: 40,
                  autoPlay: true,
                  showControls: false,
                  showDescription: false,
                );
              } else {
                print('[FAB] Taking fallback path for icon in FAB.');
                final iconPath = _getExerciseIconPath(currentExerciseName);
                print('[FAB] Icon path from _getExerciseIconPath for FAB: "$iconPath"');
                fabContent = Image.asset(
                  iconPath,
                  width: 24, // Standard icon size
                  height: 24,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    print('[FAB] Error loading icon asset "$iconPath" for FAB: $error');
                    return const Icon(Icons.fitness_center, size: 24); // Fallback dumbbell
                  },
                );
              }

              return FloatingActionButton(
                onPressed: () {
                  _showExerciseAnimationDialogGlobal(context, currentExerciseName);
                },
                child: fabContent,
                mini: true, // Make it a bit smaller
              );
            }
            return const SizedBox.shrink(); // Return empty if no current exercise or session
          },
        ),
      ),
    );
  }
}

// --- _TimerDisplay ---
class _TimerDisplay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final duration = context.select((WorkoutSessionBloc bloc) => bloc.state.displayDuration);
    final isResting = context.select((WorkoutSessionBloc bloc) => bloc.state.isResting);
    const double actualTotalRestSeconds = 60.0; // Placeholder

    String formatDuration(Duration d) {
      final seconds = d.inSeconds.clamp(0, 3599);
      final minutes = seconds ~/ 60;
      final remainingSeconds = seconds % 60;
      return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
    }

    double progressIndicatorValue;
    Color progressColor;
    Color progressTrackColor = Theme.of(context).colorScheme.surfaceContainerHighest;

    if (isResting) {
      double elapsedRestSeconds = actualTotalRestSeconds - duration.inSeconds.clamp(0, actualTotalRestSeconds.toInt()).toDouble();
      progressIndicatorValue = (actualTotalRestSeconds > 0) ? (elapsedRestSeconds / actualTotalRestSeconds).clamp(0.0, 1.0) : 0.0;
      progressColor = Colors.blueAccent;
    } else {
      progressIndicatorValue = 1.0;
      progressColor = Theme.of(context).primaryColor;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (isResting)
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Text(
                "RESTING",
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.blueAccent,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          SizedBox(
            width: 180,
            height: 180,
            child: Stack(
              fit: StackFit.expand,
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progressIndicatorValue,
                  strokeWidth: 14,
                  backgroundColor: progressTrackColor,
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  strokeCap: StrokeCap.round,
                ),
                Center(
                  child: Text(
                    formatDuration(duration),
                    style: TextStyle(
                      fontSize: 46,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'RobotoMono',
                      color: Theme.of(context).textTheme.headlineSmall?.color ?? Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Helper function to get the exercise icon path (moved to top-level)
String _getExerciseIconPath(String exerciseName) {
  final animationData = ExerciseAnimationData.getExerciseAnimation(exerciseName);
  if (animationData != null && animationData.iconImagePath != null && animationData.iconImagePath!.isNotEmpty) {
    // Prefer specific icon path from data if available
    print('[WorkoutSessionPage] Using iconImagePath from ExerciseAnimationData for $exerciseName: ${animationData.iconImagePath}');
    return animationData.iconImagePath!;
  } else {
    // Fallback to generated path (current logic)
    final iconName = exerciseName.toLowerCase().replaceAll(' ', '_');
    final generatedPath = 'assets/exercise_images/${iconName}_icon.webp';
    print('[WorkoutSessionPage] Using generated icon path for $exerciseName: $generatedPath');
    return generatedPath;
  }
}

// Helper function to show exercise animation dialog (moved to top-level)
void _showExerciseAnimationDialogGlobal(BuildContext context, String exerciseName) {
  showDialog(
    context: context,
    builder: (dialogContext) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    exerciseName,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  icon: const Icon(Icons.close),
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ExerciseAnimationWidget(
                exerciseName: exerciseName,
                width: 300,
                height: 300,
                autoPlay: true,
                showControls: true,
                showDescription: true,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// --- _ExerciseList ---
class _ExerciseList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<WorkoutSessionBloc>().state;
    final session = state.session!;

    return ListView.builder(
      itemCount: session.exercises.length,
      itemBuilder: (context, exerciseIndex) {
        final ExercisePerformance exercise = session.exercises[exerciseIndex];
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).shadowColor.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              exercise.exerciseName,
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                            const SizedBox(height: 4),
                            // Debug logging for exercise names
                            Builder(
                              builder: (context) {
                                print('[WorkoutSessionPage] Exercise name from DB: "${exercise.exerciseName}"');
                                print('[WorkoutSessionPage] Has animation: ${ExerciseAnimationData.hasAnimationForExercise(exercise.exerciseName)}');
                                return const SizedBox.shrink();
                              },
                            ),
                            if (ExerciseAnimationData.hasAnimationForExercise(exercise.exerciseName))
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.play_circle_outline,
                                    size: 16,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      'Animation available',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Theme.of(context).colorScheme.primary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (ExerciseAnimationData.hasAnimationForExercise(exercise.exerciseName))
                        Flexible(
                          flex: 1,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: 80,
                              maxHeight: 80,
                            ),
                            child: ExerciseAnimationWidget(
                              exerciseName: exercise.exerciseName,
                              width: 80,
                              height: 80,
                              autoPlay: true,
                              showControls: false,
                              showDescription: false,
                            ),
                          ),
                        )
                      else
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.asset(
                              _getExerciseIconPath(exercise.exerciseName),
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.fitness_center,
                                      size: 24,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'No Icon',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
              const SizedBox(height: 12),
              // Animation button for full view
              if (ExerciseAnimationData.hasAnimationForExercise(exercise.exerciseName))
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: OutlinedButton.icon(
                    onPressed: () => _showExerciseAnimationDialogGlobal(context, exercise.exerciseName),
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('View Exercise Demo'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      textStyle: const TextStyle(fontSize: 13),
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                      ),
                    ),
                  ),
                ),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: exercise.sets.length,
                itemBuilder: (context, setIndex) {
                  final SetPerformance set = exercise.sets[setIndex];
                  final bool isButtonDisabled = state.isLoading || state.isFinished;

  // Check if this is a timed exercise by workoutType field
  final isTimedExercise = exercise.workoutType == WorkoutType.Timed;
  
  return ListTile(
    contentPadding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 0),
    title: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Set ${setIndex + 1}:  ${isTimedExercise ? '${set.targetReps} seconds' : '${set.targetReps} reps'}',
          style: Theme.of(context).textTheme.bodyMedium
        ),
      ],
    ),

                    trailing: set.isCompleted
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  isTimedExercise 
                                    ? '${set.actualReps} seconds'
                                    : '${set.actualWeight} kg x ${set.actualReps} reps',
                                  style: TextStyle(
                                    color: Colors.green[700],
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.check_circle_outline, color: Colors.green[700], size: 20),
                            ],
                          )
                        : ElevatedButton.icon(
                            icon: const Icon(Icons.fitness_center, size: 18),
                            label: const Text('Log Set'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Theme.of(context).colorScheme.onPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ).copyWith(
                              elevation: WidgetStateProperty.all(isButtonDisabled ? 0 : 2),
                              backgroundColor: WidgetStateProperty.resolveWith<Color?>(
                                (Set<WidgetState> states) {
                                  if (states.contains(WidgetState.disabled)) {
                                    return Theme.of(context).colorScheme.onSurface.withOpacity(0.12);
                                  }
                                  return Theme.of(context).colorScheme.primary;
                                },
                              ),
                              foregroundColor: WidgetStateProperty.resolveWith<Color?>(
                                (Set<WidgetState> states) {
                                  if (states.contains(WidgetState.disabled)) {
                                    return Theme.of(context).colorScheme.onSurface.withOpacity(0.38);
                                  }
                                  return Theme.of(context).colorScheme.onPrimary;
                                }
                              )
                            ),
                            onPressed: isButtonDisabled
                                ? null
                                : () => _showSetPreparationDialog(
                                        context,
                                        exerciseIndex,
                                        setIndex,
                                        exercise.exerciseName,
                                        set,
                                      ),
                          ),

                  );
                },
                separatorBuilder: (context, index) => const Divider(height: 1, thickness: 0.5),
              ),
            ],
          ),
        );
      },
    );
  }


  void _showWeightEditDialog({
    required BuildContext context,
    required int exerciseIndex,
    required int setIndex,
    required double currentWeight,
  }) {
    final controller = TextEditingController(text: currentWeight.toString());
    final formKey = GlobalKey<FormState>();
    final state = context.read<WorkoutSessionBloc>().state;
    final session = state.session!;
    final exercise = session.exercises[exerciseIndex];

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.fitness_center, size: 20),
                const SizedBox(width: 8),
                const Expanded(child: Text('Edit Target Weight')),
                IconButton(
                  icon: const Icon(Icons.psychology, size: 20),
                  onPressed: () => _showAIRecommendationDialog(
                    dialogContext,
                    exercise.exerciseName,
                    currentWeight,
                    controller,
                  ),
                  tooltip: 'Get AI Recommendation',
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Weight (kg)',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.fitness_center),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a weight';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Please enter a valid number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Tap the AI icon for personalized weight recommendations',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  controller.dispose();
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (formKey.currentState?.validate() ?? false) {
                    final weight = double.tryParse(controller.text) ?? currentWeight;
                    context.read<WorkoutSessionBloc>().add(
                      WorkoutSetTargetWeightChanged(
                        exerciseIndex: exerciseIndex,
                        setIndex: setIndex,
                        targetWeight: weight,
                      ),
                    );
                    Navigator.pop(dialogContext);
                    controller.dispose();
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAIRecommendationDialog(
    BuildContext context,
    String exerciseName,
    double currentWeight,
    TextEditingController weightController,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Getting AI recommendation...'),
          ],
        ),
      ),
    );

    try {
      // Get user profile for personalized recommendations
      final userProfile = await sharedPrefsProvider.getUserProfile();
      
      // Get AI recommendation using instance method
      final aiService = AIWeightRecommendationService();
      final recommendedWeight = await aiService.getRecommendedWeight(
        exerciseName: exerciseName,
        userProfile: userProfile,
        targetReps: 10, // Default target reps
      );
      
      // Get confidence level
      final confidence = await aiService.getRecommendationConfidence(
        exerciseName: exerciseName,
        userProfile: userProfile,
      );
      
      // Create recommendation object
      final recommendation = WeightRecommendation(
        recommendedWeight: recommendedWeight,
        reasoning: _generateReasoningText(recommendedWeight, currentWeight, userProfile),
        tips: _generateTips(exerciseName, recommendedWeight),
        confidenceLevel: confidence,
      );

      // Close loading dialog
      if (context.mounted) {
        Navigator.pop(context);
      }

      // Show recommendation dialog
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (recommendationContext) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  Icons.psychology,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Expanded(child: Text('AI Recommendation')),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.trending_up,
                            color: Theme.of(context).colorScheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Recommended Weight',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${recommendation.recommendedWeight.toStringAsFixed(1)} kg',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                      if (recommendation.confidenceLevel != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.verified,
                              size: 16,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Confidence: ${(recommendation.confidenceLevel! * 100).toInt()}%',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (recommendation.reasoning.isNotEmpty) ...[
                  Text(
                    'Reasoning:',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      recommendation.reasoning,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (recommendation.tips.isNotEmpty) ...[
                  Text(
                    'Tips:',
                    style: Theme.of(context).textTheme.titleSmall
