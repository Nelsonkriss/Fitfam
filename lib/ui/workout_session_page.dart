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
                  // Action removed for simplicity, maybe add an error clear event/button later
                ),
              );
            } else if (state.isFinished) { // Check isFinished flag
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Workout Finished and Saved!'), backgroundColor: Colors.green),
              );
              // Consider navigating back after a delay or adding a "Done" button
              // Future.delayed(const Duration(seconds: 2), () {
              //   if (Navigator.canPop(context)) {
              //     Navigator.pop(context);
              //   }
              // });
            }
          },
          child: BlocBuilder<WorkoutSessionBloc, WorkoutSessionState>(
            builder: (context, state) {
              // Handle initial loading or error state where session is null
              // Check isLoading AND session is null for the very initial load
              if (state.isLoading && state.session == null) {
                return const Center(child: CircularProgressIndicator());
              }
              // If not loading but session is still null, something went wrong
              if (state.session == null && !state.isLoading) {
                return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        state.errorMessage ?? 'Failed to load workout session.', // Show specific error if available
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.red[700]),
                      ),
                    )
                );
              }
              // If session is not null, proceed to build the main layout
              if (state.session != null) {
                return Stack( // Use Stack for overlaying loading indicator during save
                  children: [
                    Column(
                      children: [
                        _TimerDisplay(), // Reads displayDuration from state
                        Expanded(
                          child: _ExerciseList(), // Reads session exercises from state
                        ),
                        _SessionControls(), // Reads flags for button state
                      ],
                    ),
                    // Loading overlay during saving (check isLoading flag)
                    if (state.isLoading) // Check isLoading flag
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
              // Fallback - should ideally not be reached if logic above is correct
              return const Center(child: Text('An unexpected error occurred.'));
            },
          ),
        ),
      ),
    );
  }
}

// --- _TimerDisplay (Uses displayDuration) ---
class _TimerDisplay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Select only the displayDuration and isResting flag
    final duration = context.select((WorkoutSessionBloc bloc) => bloc.state.displayDuration);
    final isResting = context.select((WorkoutSessionBloc bloc) => bloc.state.isResting);

    String formatDuration(Duration d) {
      // Handle potential negative duration during rest timer transition
      final seconds = d.inSeconds < 0 ? 0 : d.inSeconds;
      final minutes = seconds ~/ 60;
      final remainingSeconds = seconds % 60;
      return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      color: isResting ? Colors.blue[100] : Colors.transparent, // Indicate resting state
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isResting)
            const Text("REST", style: TextStyle(fontSize: 16, color: Colors.blue, fontWeight: FontWeight.bold)),
          if (isResting)
            const SizedBox(height: 4),
          Center(
            child: Text(
              formatDuration(duration),
              style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, fontFamily: 'RobotoMono'), // Use monospaced font?
            ),
          ),
        ],
      ),
    );
  }
}

// --- _ExerciseList (Reads state flags for button disable) ---
class _ExerciseList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Use watch to rebuild when state changes (including session updates)
    final state = context.watch<WorkoutSessionBloc>().state;
    final session = state.session!; // Guaranteed non-null by parent builder

    return ListView.builder(
      itemCount: session.exercises.length,
      itemBuilder: (context, exerciseIndex) {
        final ExercisePerformance exercise = session.exercises[exerciseIndex];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          elevation: 2, // Subtle elevation
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.exerciseName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 10),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: exercise.sets.length,
                  itemBuilder: (context, setIndex) {
                    final SetPerformance set = exercise.sets[setIndex];
                    // Determine if button should be disabled based on overall state
                    final bool isButtonDisabled = state.isLoading || state.isFinished;

                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                          'Set ${setIndex + 1}: Target ${set.targetReps} reps x ${set.targetWeight} kg'),
                      trailing: set.isCompleted
                          ? Tooltip( // Add tooltip for completed sets
                        message: "Completed: ${set.actualWeight} kg x ${set.actualReps} reps",
                        child: Row( // Use Row for icon + text
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${set.actualReps} x ${set.actualWeight} kg',
                                style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.check_circle, color: Colors.green[800], size: 18),
                            ]
                        ),
                      )
                          : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            backgroundColor: isButtonDisabled ? Colors.grey : null,
                            textStyle: const TextStyle(fontSize: 13) // Slightly smaller text
                        ),
                        onPressed: isButtonDisabled
                            ? null
                            : () => _showCompleteSetDialog(
                            context, // Original context
                            exerciseIndex,
                            setIndex,
                            exercise.exerciseName,
                            set // Pass current set data
                        ),
                        child: const Text('Log Set'),
                      ),
                    );
                  },
                  separatorBuilder: (context, index) => const Divider(height: 1, thickness: 0.5),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- Dialog Function (Improved Disposal) ---
  void _showCompleteSetDialog(
      BuildContext providerContext, // Context with access to Bloc
      int exerciseIndex,
      int setIndex,
      String exerciseName,
      SetPerformance currentSet) {

    // Initialize with target values as hints or initial values
    final repsController = TextEditingController(text: currentSet.targetReps.toString());
    final weightController = TextEditingController(text: currentSet.targetWeight.toString());
    final formKey = GlobalKey<FormState>();

    // Function to dispose controllers safely
    void disposeControllers() {
      try {
        repsController.dispose();
        weightController.dispose();
      } catch(e) {
        debugPrint("Error disposing controllers: $e");
      }
    }

    showDialog(
      context: providerContext, // Use the context that has the BlocProvider
      barrierDismissible: false, // Prevent accidental dismissal
      builder: (dialogContext) { // Context specific to the dialog
        return AlertDialog(
          title: Text('Log $exerciseName - Set ${setIndex + 1}'),
          contentPadding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 0.0), // Adjust padding
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min, // Prevent excessive height
              children: [
                TextFormField(
                  controller: repsController,
                  autofocus: true, // Focus reps field first
                  decoration: InputDecoration(
                      labelText: 'Reps Completed',
                      hintText: 'Target: ${currentSet.targetReps}', // Show target as hint
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
                const SizedBox(height: 16), // Increased spacing
                TextFormField(
                  controller: weightController,
                  decoration: InputDecoration(
                      labelText: 'Weight (kg)', // Add unit
                      hintText: 'Target: ${currentSet.targetWeight} kg',
                      border: const OutlineInputBorder(),
                      suffixIcon: const Icon(Icons.fitness_center)
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))], // Allow decimal
                  validator: (value) {
                    if (value != null && value.isNotEmpty && double.tryParse(value) == null) {
                      return 'Enter valid weight'; // Validate only if not empty
                    }
                    return null; // Allow empty (interpreted as 0 or target)
                  },
                ),
                const SizedBox(height: 20), // Space before buttons
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext); // Close the dialog
                disposeControllers(); // Dispose on cancel
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton( // Make Save more prominent
              onPressed: () {
                // Validate the form first
                if (formKey.currentState?.validate() ?? false) {
                  // Use tryParse with defaults based on target values
                  final actualReps = int.tryParse(repsController.text) ?? currentSet.targetReps;
                  // If empty, default to target weight, otherwise parse or default to 0.0 if parse fails
                  final actualWeight = weightController.text.isEmpty
                      ? currentSet.targetWeight
                      : (double.tryParse(weightController.text) ?? currentSet.targetWeight);

                  // Use the providerContext to find the BLoC and add the event
                  providerContext.read<WorkoutSessionBloc>().add(
                    WorkoutSetMarkedComplete( // Use correct event name
                      exerciseIndex: exerciseIndex,
                      setIndex: setIndex,
                      actualReps: actualReps,
                      actualWeight: actualWeight,
                    ),
                  );
                  Navigator.pop(dialogContext); // Close the dialog
                  disposeControllers(); // Dispose on save
                }
              },
              child: const Text('Save Set'),
            ),
          ],
        );
      },
    );
    // No need for .then() if dispose is handled in actions
  }
}


// --- _SessionControls (Uses boolean state flags) ---
class _SessionControls extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      // Watch the state to rebuild when flags change
      child: BlocBuilder<WorkoutSessionBloc, WorkoutSessionState>(
        // Rebuild only when relevant flags change
        buildWhen: (prev, current) =>
        prev.isLoading != current.isLoading || prev.isFinished != current.isFinished,
        builder: (context, state) {
          // Use boolean flags directly
          final bool isFinished = state.isFinished;
          final bool isLoading = state.isLoading;
          // Determine if the finish button should be enabled
          final bool canFinish = !isLoading && !isFinished && state.session != null;

          return ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48), // Full width
              backgroundColor: isFinished ? Colors.grey : (isLoading ? Colors.orangeAccent : Theme.of(context).primaryColor),
              foregroundColor: Colors.white, // Text color
              textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            // Disable button if loading or already finished
            onPressed: !canFinish ? null : () {
              // Optional: Confirmation Dialog before finishing
              showDialog(
                  context: context,
                  barrierDismissible: false, // Prevent accidental dismissal
                  builder: (confirmContext) => AlertDialog(
                    title: const Text('Finish Workout?'),
                    content: const Text('Are you sure you want to end and save this session?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(confirmContext),
                          child: const Text('Cancel')
                      ),
                      ElevatedButton( // Make Finish more prominent
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                          onPressed: () {
                            Navigator.pop(confirmContext); // Close dialog
                            // Dispatch the correct event to finish
                            context.read<WorkoutSessionBloc>().add(WorkoutSessionFinishAttempt());
                          },
                          child: const Text('Finish & Save')
                      ),
                    ],
                  )
              );
            },
            child: isLoading
                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3,))
                : Text(isFinished ? 'Workout Finished' : 'Finish Workout'),
          );
        },
      ),
    );
  }
}