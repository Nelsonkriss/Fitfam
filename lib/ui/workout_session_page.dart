import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for input formatters
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dumbbell_new/models/workout_session.dart';
import 'package:dumbbell_new/models/routine.dart';

abstract class WorkoutSessionEvent {}

class WorkoutSessionStarted extends WorkoutSessionEvent {
  final WorkoutSession session;
  WorkoutSessionStarted(this.session);
}

class WorkoutSetCompleted extends WorkoutSessionEvent {
  final int exerciseIndex;
  final int setIndex;
  final int actualReps;
  final double actualWeight;
  WorkoutSetCompleted({
    required this.exerciseIndex,
    required this.setIndex,
    required this.actualReps,
    required this.actualWeight,
  });
}

class WorkoutSessionFinished extends WorkoutSessionEvent {}

// --- Placeholder BLoC State (Define in your bloc file) ---
// Make sure this state is immutable
@immutable // Good practice to mark state as immutable
class WorkoutSessionState {
  final WorkoutSession? session;
  final Duration currentDuration;
  final bool isResting;
  final bool isLoading; // Example: Add loading/saving state
  final String? error;   // Example: Add error state

  const WorkoutSessionState({
    this.session,
    this.currentDuration = Duration.zero,
    this.isResting = false,
    this.isLoading = false,
    this.error,
  });

  // Helper for immutability
  WorkoutSessionState copyWith({
    WorkoutSession? session, // Allow nullable to potentially clear session
    Duration? currentDuration,
    bool? isResting,
    bool? isLoading,
    String? error,
    bool clearError = false, // Helper to explicitly clear error
  }) {
    return WorkoutSessionState(
      session: session ?? this.session,
      currentDuration: currentDuration ?? this.currentDuration,
      isResting: isResting ?? this.isResting,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
    );
  }
}

// --- Placeholder BLoC (Define and implement in your bloc file) ---
class WorkoutSessionBloc extends Bloc<WorkoutSessionEvent, WorkoutSessionState> {
  // Constructor requires initial state
  WorkoutSessionBloc() : super(const WorkoutSessionState()) { // Initial empty state
    on<WorkoutSessionStarted>(_onWorkoutSessionStarted);
    on<WorkoutSetCompleted>(_onWorkoutSetCompleted);

class WorkoutSessionPage extends StatelessWidget {
  final Routine routine;

  const WorkoutSessionPage({Key? key, required this.routine}) : super(key: key);

  WorkoutSession _createInitialSession(Routine routine) {
    return WorkoutSession(
      routine: routine,
      startTime: DateTime.now(),
    );
  }


  @override
  Widget build(BuildContext context) {
    // Create and provide the BLoC instance for this page
    return BlocProvider(
      // Use lazy: false if you need the bloc immediately (e.g., for starting timer)
      // Otherwise, lazy: true (default) is fine.
      create: (context) {
        final bloc = WorkoutSessionBloc();
        // Create the initial session state object
        final initialSession = _createInitialSession(routine);
        // Dispatch the event to initialize the BLoC's state
        bloc.add(WorkoutSessionStarted(initialSession));
        return bloc;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(routine.routineName), // Use routine name passed in
          actions: [
            IconButton(
              icon: const Icon(Icons.close),
              // Use BlocListener potentially for side-effects like navigation after finish
              onPressed: () => Navigator.pop(context), // Simple close for now
            ),
          ],
        ),
        // Use BlocListener for handling navigation/snackbars based on state changes
        // e.g., navigating away after WorkoutSessionFinished completes successfully.
        body: BlocConsumer<WorkoutSessionBloc, WorkoutSessionState>(
          listener: (context, state) {
            // Example: Show error messages
            if (state.error != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.error!), backgroundColor: Colors.red),
              );
              // Optionally clear the error from state after showing it
              // context.read<WorkoutSessionBloc>().add(ClearErrorEvent());
            }
            // Example: Navigate back when session is finished *and* saved
            // Check for a specific flag like `isSessionCompleteAndSaved` if needed
          },
          builder: (context, state) {
            // Show loading indicator if session data isn't ready yet
            if (state.session == null || (state.isLoading && state.session == null)) { // Check if initial loading
              return const Center(child: CircularProgressIndicator());
            }

            // Optionally show overlay loading indicator during operations like saving
            return Stack(
              children: [
                Column(
                  children: [
                    _TimerDisplay(), // Reads from bloc state
                    Expanded(
                      child: _ExerciseList(), // Reads from bloc state
                    ),
                    _SessionControls(), // Dispatches events to bloc
                  ],
                ),
                if (state.isLoading) // Show loading overlay during async ops
                  Container(
                    color: Colors.black.withOpacity(0.3),
                    child: const Center(child: CircularProgressIndicator()),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TimerDisplay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Select specific parts of the state to rebuild only when they change
    final duration = context.select((WorkoutSessionBloc bloc) => bloc.state.currentDuration);
    final isResting = context.select((WorkoutSessionBloc bloc) => bloc.state.isResting);

    return Container(
      padding: const EdgeInsets.all(16),
      color: isResting ? Colors.blue[100] : Colors.transparent,
      child: Center(
        child: Text(
          '${duration.inMinutes.toString().padLeft(2, '0')}:'
              '${(duration.inSeconds % 60).toString().padLeft(2, '0')}',
          style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _ExerciseList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // No need for BlocBuilder here if the parent (BlocConsumer) handles the main state changes (like session loading)
    // We only need to read the current session which is guaranteed to be non-null by the builder logic above.
    final session = context.read<WorkoutSessionBloc>().state.session!;

    return ListView.builder(
      itemCount: session.exercises.length,
      itemBuilder: (context, exerciseIndex) {
        final exercise = session.exercises[exerciseIndex];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.exerciseName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                // Using ListView.separated for dividers between sets
                ListView.separated(
                  shrinkWrap: true, // Important inside another scroll view
                  physics: const NeverScrollableScrollPhysics(), // Disable scrolling
                  itemCount: exercise.sets.length,
                  itemBuilder: (context, setIndex) {
                    final set = exercise.sets[setIndex];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                          'Set ${setIndex + 1}: Target ${set.targetReps} reps x ${set.targetWeight} kg'),
                      trailing: set.isCompleted
                          ? Text(
                        '${set.actualReps} x ${set.actualWeight} kg',
                        style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.bold),
                      )
                          : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onPressed: () => _showCompleteSetDialog(
                            context, exerciseIndex, setIndex, exercise.exerciseName, set),
                        child: const Text('Complete'),
                      ),
                    );
                  },
                  separatorBuilder: (context, index) => const Divider(height: 1),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- Improved Dialog Function ---
  void _showCompleteSetDialog(
      BuildContext context, // Original context needed for Bloc access and showing dialog
      int exerciseIndex,
      int setIndex,
      String exerciseName,
      SetPerformance currentSet // Pass the set for default values
      ) {
    // Controllers to manage text field state locally within the dialog
    final repsController = TextEditingController(text: currentSet.targetReps.toString());
    final weightController = TextEditingController(text: currentSet.targetWeight.toString());
    final formKey = GlobalKey<FormState>(); // For validation

    showDialog(
      context: context,
      // Prevent dismissal by tapping outside
      barrierDismissible: false,
      builder: (dialogContext) { // Use a different context name for the dialog
        return AlertDialog(
          title: Text('Complete $exerciseName - Set ${setIndex + 1}'),
          content: StatefulBuilder( // Use StatefulBuilder to manage local state (controllers)
              builder: (stfContext, stfSetState) {
                return Form( // Wrap in Form for validation
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: repsController,
                        decoration: const InputDecoration(
                            labelText: 'Reps Completed',
                            hintText: 'Enter reps'
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly], // Allow only numbers
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter reps';
                          }
                          if (int.tryParse(value) == null) {
                            return 'Invalid number';
                          }
                          return null; // Valid
                        },
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: weightController,
                        decoration: const InputDecoration(
                            labelText: 'Weight (kg)',
                            hintText: 'Enter weight'
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))], // Allow numbers and decimals
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            // Allow zero weight
                            return null; // Valid (or add specific validation if needed)
                          }
                          if (double.tryParse(value) == null) {
                            return 'Invalid number';
                          }
                          return null; // Valid
                        },
                      ),
                    ],
                  ),
                );
              }
          ),
          actions: [
            TextButton(
              onPressed: () {
                // Dispose controllers before closing
                repsController.dispose();
                weightController.dispose();
                Navigator.pop(dialogContext); // Close the dialog
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                // Validate the form first
                if (formKey.currentState!.validate()) {
                  final actualReps = int.tryParse(repsController.text) ?? 0; // Use 0 or handle error
                  final actualWeight = double.tryParse(weightController.text) ?? 0.0; // Use 0.0 or handle error

                  // Use the *original* context to find the BLoC
                  context.read<WorkoutSessionBloc>().add(
                    WorkoutSetCompleted(
                      exerciseIndex: exerciseIndex,
                      setIndex: setIndex,
                      actualReps: actualReps,
                      actualWeight: actualWeight,
                    ),
                  );

                  // Dispose controllers before closing
                  repsController.dispose();
                  weightController.dispose();
                  Navigator.pop(dialogContext); // Close the dialog only on success
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    ).then((_) {
      // Ensure controllers are disposed even if dialog is dismissed unexpectedly
      // Although barrierDismissible=false prevents this case often.
      // If they weren't disposed in actions, dispose here.
      // repsController.dispose();
      // weightController.dispose();
    });
  }
}


class _SessionControls extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: BlocBuilder<WorkoutSessionBloc, WorkoutSessionState>(
        // Build only when loading state changes to enable/disable button
        buildWhen: (previous, current) => previous.isLoading != current.isLoading || previous.session?.endTime != current.session?.endTime,
        builder: (context, state) {
          final bool isFinished = state.session?.endTime != null;
          return ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48), // Make button wider
              backgroundColor: isFinished ? Colors.grey : Theme.of(context).primaryColor, // Grey out if finished
            ),
            // Disable button while loading/saving or if already finished
            onPressed: (state.isLoading || isFinished) ? null : () {
              // Dispatch event to finish the session
              context.read<WorkoutSessionBloc>().add(WorkoutSessionFinished());
              // Consider showing confirmation dialog before finishing?
              // Navigation back should ideally be handled by a BlocListener
              // listening for the successful completion state after saving.
              // Navigator.pop(context); // Avoid popping immediately here
            },
            child: state.isLoading
                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white,))
                : Text(isFinished ? 'Workout Finished' : 'Finish Workout', style: const TextStyle(fontSize: 18)),
          );
        },
      ),
    );
  }
}