import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/workout_session_bloc.dart';
import '../models/exercise_performance.dart';
import '../models/set_performance.dart';
import '../models/exercise.dart';

class _ExerciseList extends StatelessWidget {
  void _showSetPreparationDialog(
    BuildContext context,
    int exerciseIndex,
    int setIndex,
    String exerciseName,
    SetPerformance set,
  ) {
    // Get the exercise performance from the bloc state
    final exercisePerformance = context.read<WorkoutSessionBloc>().state.session?.exercises[exerciseIndex];
    final isTimedExercise = exercisePerformance?.workoutType == WorkoutType.Timed;
    
    final weightController = TextEditingController(text: isTimedExercise ? '0' : set.targetWeight.toString());
    final repsController = TextEditingController(text: set.targetReps.toString());
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isTimedExercise ? 'Log Time' : 'Log Set'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isTimedExercise) ...[
                TextFormField(
                  controller: weightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
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
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: repsController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: isTimedExercise ? 'Time (seconds)' : 'Reps',
                  border: const OutlineInputBorder(),
                  suffixIcon: Icon(isTimedExercise ? Icons.timer : Icons.repeat),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return isTimedExercise ? 'Please enter time in seconds' : 'Please enter number of reps';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                final weight = double.tryParse(weightController.text) ?? 0.0;
                final reps = int.tryParse(repsController.text) ?? 0;

                context.read<WorkoutSessionBloc>().add(
                  WorkoutSetCompleted(
                    exerciseIndex: exerciseIndex,
                    setIndex: setIndex,
                    actualWeight: weight,
                    actualReps: reps,
                  ),
                );

                Navigator.pop(dialogContext);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
