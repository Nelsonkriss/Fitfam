import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:workout_planner/bloc/workout_session_bloc.dart';
import 'package:workout_planner/models/workout_session.dart';

class WorkoutSessionPage extends StatelessWidget {
  final WorkoutSession session;

  const WorkoutSessionPage({Key? key, required this.session}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Use existing bloc instance instead of creating new one
    workoutSessionBloc.startNewSession(session);
    return BlocProvider.value(
      value: workoutSessionBloc,
      child: Scaffold(
        appBar: AppBar(
          title: Text(session.routine.routineName),
          actions: [
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        body: Column(
          children: [
            _TimerDisplay(),
            Expanded(
              child: _ExerciseList(),
            ),
            _SessionControls(),
          ],
        ),
      ),
    );
  }
}

class _TimerDisplay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WorkoutSessionBloc, WorkoutSessionState>(
      builder: (context, state) {
        final duration = state.currentDuration;
        final isResting = state.isResting;
        
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
      },
    );
  }
}

class _ExerciseList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WorkoutSessionBloc, WorkoutSessionState>(
      builder: (context, state) {
        final session = state.session;
        if (session == null) return const Center(child: CircularProgressIndicator());

        return ListView.builder(
          itemCount: session.exercises.length,
          itemBuilder: (context, exerciseIndex) {
            final exercise = session.exercises[exerciseIndex];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.exerciseName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    ...exercise.sets.asMap().entries.map((setEntry) {
                      final setIndex = setEntry.key;
                      final set = setEntry.value;
                      return ListTile(
                        title: Text('Set ${setIndex + 1}'),
                        subtitle: Text('${set.targetReps} reps x ${set.targetWeight} kg'),
                        trailing: set.isCompleted
                            ? Text('${set.actualReps} x ${set.actualWeight} kg')
                            : ElevatedButton(
                                onPressed: () => _completeSet(context, exerciseIndex, setIndex),
                                child: const Text('Complete'),
                              ),
                      );
                    }),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _completeSet(BuildContext context, int exerciseIndex, int setIndex) {
    final exercise = context.read<WorkoutSessionBloc>().currentSession.value!
        .exercises[exerciseIndex];
    final set = exercise.sets[setIndex];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Complete ${exercise.exerciseName} - Set ${setIndex + 1}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(labelText: 'Reps Completed'),
              keyboardType: TextInputType.number,
              onChanged: (value) => set.actualReps = int.tryParse(value) ?? 0,
            ),
            TextField(
              decoration: const InputDecoration(labelText: 'Weight (kg)'),
              keyboardType: TextInputType.number,
              onChanged: (value) => set.actualWeight = double.tryParse(value) ?? 0,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final bloc = context.read<WorkoutSessionBloc>();
              bloc.completeSet(
                exerciseIndex, 
                setIndex,
                set.actualReps,
                set.actualWeight,
              );
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _SessionControls extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: BlocBuilder<WorkoutSessionBloc, WorkoutSessionState>(
        builder: (context, state) {
          return ElevatedButton(
            onPressed: () async {
              await context.read<WorkoutSessionBloc>().completeSession();
              Navigator.pop(context);
            },
            child: const Text('Finish Workout'),
          );
        },
      ),
    );
  }
}

// Simple state class for the bloc (would normally be in separate file)
class WorkoutSessionState {
  final WorkoutSession? session;
  final Duration currentDuration;
  final bool isResting;

  WorkoutSessionState({
    required this.session,
    required this.currentDuration,
    required this.isResting,
  });
}
