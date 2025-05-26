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
        body: BlocListener<WorkoutSessionBloc, WorkoutSessionState>(
          listener: (context, state) {
            // Handle non-UI side effects using boolean flags
            if (state.errorMessage != null) { // Check error message directly
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.errorMessage!),
                  backgroundColor: Colors.red,
                ),
              );
            } else if (state.isFinished) { // Check isFinished flag
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Workout Finished and Saved!'), backgroundColor: Colors.green),
              );
            }
          },
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
              Text(
                exercise.exerciseName,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 10),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: exercise.sets.length,
                itemBuilder: (context, setIndex) {
                  final SetPerformance set = exercise.sets[setIndex];
                  final bool isButtonDisabled = state.isLoading || state.isFinished;

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 0),
                    title: Row(
                      children: [
                        Text('Set ${setIndex + 1}:  ${set.targetReps} reps @ ', style: Theme.of(context).textTheme.bodyMedium),
                        GestureDetector(
                          onTap: () {
                            _showWeightEditDialog(
                              context: context,
                              exerciseIndex: exerciseIndex,
                              setIndex: setIndex,
                              currentWeight: set.targetWeight,
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${set.targetWeight} kg',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSecondaryContainer,
                                fontSize: Theme.of(context).textTheme.bodyMedium?.fontSize,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    trailing: set.isCompleted
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${set.actualWeight} kg x ${set.actualReps} reps',
                                style: TextStyle(
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
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
                                : () => _showCompleteSetDialog(
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

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Target Weight'),
        content: Form(
          key: formKey,
          child: TextFormField(
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
      ),
    );
  }

  void _showCompleteSetDialog(
      BuildContext providerContext,
      int exerciseIndex,
      int setIndex,
      String exerciseName,
      SetPerformance currentSet) {
    final repsController = TextEditingController(text: currentSet.targetReps.toString());
    final weightController = TextEditingController(text: currentSet.targetWeight.toString());
    final formKey = GlobalKey<FormState>();

    void disposeControllers() {
      try {
        repsController.dispose();
        weightController.dispose();
      } catch(e) {
        debugPrint("Error disposing controllers: $e");
      }
    }

    showDialog(
      context: providerContext,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Log $exerciseName - Set ${setIndex + 1}'),
          contentPadding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 0.0),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: repsController,
                  autofocus: true,
                  decoration: InputDecoration(
                      labelText: 'Reps Completed',
                      hintText: 'Target: ${currentSet.targetReps}',
                      border: const OutlineInputBorder(),
                      suffixIcon: const Icon(Icons.repeat)
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (value) {
                    if (value == null || value.isEmpty || int.tryParse(value) == null) {
                      return 'Enter valid reps';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: weightController,
                  decoration: InputDecoration(
                      labelText: 'Weight (kg)',
                      hintText: 'Target: ${currentSet.targetWeight} kg',
                      border: const OutlineInputBorder(),
                      suffixIcon: const Icon(Icons.fitness_center)
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                  validator: (value) {
                    if (value != null && value.isNotEmpty && double.tryParse(value) == null) {
                      return 'Enter valid weight';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                disposeControllers();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  final actualReps = int.tryParse(repsController.text) ?? currentSet.targetReps;
                  final actualWeight = weightController.text.isEmpty
                      ? currentSet.targetWeight
                      : (double.tryParse(weightController.text) ?? currentSet.targetWeight);

                  providerContext.read<WorkoutSessionBloc>().add(
                    WorkoutSetMarkedComplete(
                      exerciseIndex: exerciseIndex,
                      setIndex: setIndex,
                      actualReps: actualReps,
                      actualWeight: actualWeight,
                    ),
                  );
                  Navigator.pop(dialogContext);
                  disposeControllers();
                }
              },
              child: const Text('Save Set'),
            ),
          ],
        );
      },
    );
  }
}

// --- _SessionControls ---
class _SessionControls extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: BlocBuilder<WorkoutSessionBloc, WorkoutSessionState>(
        buildWhen: (prev, current) =>
        prev.isLoading != current.isLoading || prev.isFinished != current.isFinished,
        builder: (context, state) {
          final bool isFinished = state.isFinished;
          final bool isLoading = state.isLoading;
          final bool canFinish = !isLoading && !isFinished && state.session != null;

          return ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              backgroundColor: isLoading && !isFinished // Show orange only if loading AND not yet finished
                  ? Colors.orangeAccent
                  : isFinished
                      ? Theme.of(context).colorScheme.surfaceContainerHighest
                      : Theme.of(context).colorScheme.primary,
              foregroundColor: isLoading && !isFinished
                  ? Colors.white
                  : isFinished
                      ? Theme.of(context).colorScheme.onSurfaceVariant
                      : Theme.of(context).colorScheme.onPrimary,
              textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 0.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: isFinished ? 0 : 2,
            ),
            onPressed: !canFinish ? null : () {
              showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (confirmContext) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: const Text('Finish Workout?', style: TextStyle(fontWeight: FontWeight.w600)),
                    content: const Text('Are you sure you want to end and save this session?'),
                    actionsAlignment: MainAxisAlignment.spaceBetween,
                    actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    actions: [
                      TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => Navigator.pop(confirmContext),
                          child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold))
                      ),
                      ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Theme.of(context).colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            textStyle: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onPressed: () {
                            Navigator.pop(confirmContext);
                            context.read<WorkoutSessionBloc>().add(WorkoutSessionFinishAttempt());
                          },
                          child: const Text('Finish & Save')
                      ),
                    ],
                  )
              );
            },
            child: isLoading && !isFinished // Show spinner only if loading AND not yet finished
                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3,))
                : Text(isFinished ? 'Workout Finished' : 'Finish Workout'),
          );
        },
      ),
    );
  }
}
