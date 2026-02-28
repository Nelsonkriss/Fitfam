import 'dart:math';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:workout_planner/bloc/routines_bloc.dart';
import 'package:workout_planner/bloc/workout_session_bloc.dart';
import 'package:workout_planner/models/workout_session.dart';
import 'package:workout_planner/models/routine.dart';
import 'package:workout_planner/models/exercise_performance.dart';
import 'package:workout_planner/models/set_performance.dart';
import 'package:workout_planner/ui/components/exercise_animation_widget.dart';

import 'components/number_ticker.dart';

class RoutineStepPage extends StatefulWidget {
  final Routine originalRoutine;
  final VoidCallback? celebrateCallback;
  final VoidCallback? onBackPressed;

  const RoutineStepPage({
    required Routine routine,
    this.celebrateCallback,
    this.onBackPressed,
    super.key,
  }) : originalRoutine = routine;

  @override
  State<RoutineStepPage> createState() => _RoutineStepPageState();
}

class _RoutineStepPageState extends State<RoutineStepPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ConfettiController _confettiController = ConfettiController(
    duration: const Duration(seconds: 4),
  );

  late Routine _currentWorkingRoutine;
  late List<Exercise> _currentExercises;

  final List<int> _exerciseIndexesInStepOrder = [];
  final List<int> _partIndexesInStepOrder = [];
  final List<int> _setsTotalInStepOrder = [];
  final List<int> _setNumberOfStep = [];
  int _currentStepIndex = 0;

  WorkoutSession? _activeWorkoutSession;

  Map<int, NumberTickerController> _weightTickerControllers = {};

  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _currentWorkingRoutine = widget.originalRoutine.copyWith(
      parts:
          widget.originalRoutine.parts.map((originalPart) {
            return originalPart.copyWith(
              exercises:
                  originalPart.exercises.map((originalExercise) {
                    return originalExercise.copyWith();
                  }).toList(),
            );
          }).toList(),
    );

    _rebuildStateFromRoutine();
    _activeWorkoutSession = WorkoutSession.startNew(
      routine: widget.originalRoutine,
    );
  }

  void _rebuildStateFromRoutine() {
    _currentExercises =
        _currentWorkingRoutine.parts.expand((p) => p.exercises).toList();
    _exerciseIndexesInStepOrder.clear();
    _partIndexesInStepOrder.clear();
    _setsTotalInStepOrder.clear();
    _setNumberOfStep.clear();
    _disposeTickerControllers();
    _weightTickerControllers = {};

    int exerciseCounter = 0;
    for (
      int partIdx = 0;
      partIdx < _currentWorkingRoutine.parts.length;
      partIdx++
    ) {
      final part = _currentWorkingRoutine.parts[partIdx];
      if (part.exercises.isEmpty) continue;

      int exercisesInThisSetGroup = 1;
      switch (part.setType) {
        case SetType.Super:
          exercisesInThisSetGroup = 2;
          break;
        case SetType.Tri:
          exercisesInThisSetGroup = 3;
          break;
        case SetType.Giant:
          exercisesInThisSetGroup = 4;
          break;
        case SetType.Regular:
        case SetType.Drop:
        default:
          exercisesInThisSetGroup = part.exercises.length;
          break;
      }

      exercisesInThisSetGroup = min(
        exercisesInThisSetGroup,
        part.exercises.length,
      );
      if (exercisesInThisSetGroup == 0) continue;

      for (int i = 0; i < exercisesInThisSetGroup; i++) {
        final currentExerciseFlatIndex = exerciseCounter + i;
        if (currentExerciseFlatIndex >= _currentExercises.length) continue;

        final exercise = _currentExercises[currentExerciseFlatIndex];
        final totalSets = exercise.sets;
        if (totalSets <= 0) continue;

        for (int setNum = 1; setNum <= totalSets; setNum++) {
          _exerciseIndexesInStepOrder.add(currentExerciseFlatIndex);
          _partIndexesInStepOrder.add(partIdx);
          _setsTotalInStepOrder.add(totalSets);
          _setNumberOfStep.add(setNum);

          if (!_weightTickerControllers.containsKey(currentExerciseFlatIndex)) {
            _weightTickerControllers[currentExerciseFlatIndex] =
                NumberTickerController(
                  initial: exercise.lastUsedWeight ?? exercise.weight,
                  step: 0.5,
                  minValue: 0,
                );
          }
        }
      }
      exerciseCounter += exercisesInThisSetGroup;
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _disposeTickerControllers();
    super.dispose();
  }

  void _disposeTickerControllers() {
    for (var c in _weightTickerControllers.values) {
      try {
        c.dispose();
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await _onWillPop() && mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.black,
        body: _finished ? _buildFinishedScreen() : _buildWorkoutInterface(),
      ),
    );
  }

  Widget _buildFinishedScreen() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black, Color(0xFF1a1a1a)],
            ),
          ),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            numberOfParticles: 18,
            emissionFrequency: 0.05,
            colors: const [
              Colors.white,
              Colors.tealAccent,
              Colors.amber,
              Colors.pinkAccent,
            ],
          ),
        ),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.emoji_events_outlined,
                color: Colors.tealAccent,
                size: 72,
              ),
              const SizedBox(height: 16),
              const Text(
                'Workout Complete!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  if (Navigator.canPop(context)) Navigator.pop(context);
                },
                child: const Text('DONE'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWorkoutInterface() {
    if (_exerciseIndexesInStepOrder.isEmpty) {
      return const Center(
        child: Text(
          'No steps generated for this routine.',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    final exerciseIdx = _exerciseIndexesInStepOrder[_currentStepIndex];
    final exercise = _currentExercises[exerciseIdx];
    final setNum = _setNumberOfStep[_currentStepIndex];
    final totalSets = _setsTotalInStepOrder[_currentStepIndex];
    final weightController = _weightTickerControllers[exerciseIdx]!;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  exercise.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Set $setNum/$totalSets',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  // Subtle animation preview keeps the page lively without clutter
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      height: 200,
                      child: ExerciseAnimationWidget(
                        exerciseName: exercise.name,
                        autoPlay: false,
                        showControls: false,
                        showDescription: false,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Tiny stats row for tests and quick glance
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Sets:',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$totalSets',
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      if (exercise.workoutType == WorkoutType.Timed)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Target:',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${int.tryParse(exercise.reps) ?? 0}',
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Weight and Reps/Seconds controls
                  Row(
                    children: [
                      if (exercise.workoutType == WorkoutType.Weight)
                        Expanded(
                          child: _metricCard(
                            label: 'Weight (kg)',
                            child: _tickerRow(weightController),
                          ),
                        ),
                      if (exercise.workoutType == WorkoutType.Weight)
                        const SizedBox(width: 12),
                      Expanded(
                        child: _metricCard(
                          label:
                              exercise.workoutType == WorkoutType.Timed
                                  ? 'Seconds'
                                  : 'Reps',
                          child: Center(
                            child: Text(
                              exercise.workoutType == WorkoutType.Timed
                                  ? '${exercise.reps} sec'
                                  : exercise.reps,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          // Primary action docked at bottom
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _handleStepContinue,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Done', style: TextStyle(fontSize: 18)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tickerRow(NumberTickerController controller) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: controller.decrement,
          icon: const Icon(Icons.remove, color: Colors.white),
          splashRadius: 20,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: GestureDetector(
            onTap: () => _showWeightEditDialog(controller),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: NumberTicker(
                controller: controller,
                textStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                ),
                fractionDigits: 1,
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          onPressed: controller.increment,
          icon: const Icon(Icons.add, color: Colors.white),
          splashRadius: 20,
        ),
      ],
    );
  }

  Widget _metricCard({required String label, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final title = widget.originalRoutine.routineName;
    final total = _exerciseIndexesInStepOrder.length;
    final current = (_currentStepIndex + 1).clamp(1, max(1, total));
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x33000000), Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () async {
              final canLeave = await _onWillPop();
              if (canLeave && Navigator.canPop(context)) Navigator.pop(context);
            },
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Step $current of $total',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleStepContinue() {
    if (_currentStepIndex >= _exerciseIndexesInStepOrder.length) return;

    try {
      final int exerciseFlatIndex =
          _exerciseIndexesInStepOrder[_currentStepIndex];
      final int setNumber = _setNumberOfStep[_currentStepIndex];
      final int setIndex = setNumber - 1;
      if (exerciseFlatIndex < _activeWorkoutSession!.exercises.length) {
        final ExercisePerformance currentExercisePerf =
            _activeWorkoutSession!.exercises[exerciseFlatIndex];
        if (setIndex >= 0 && setIndex < currentExercisePerf.sets.length) {
          final SetPerformance setToUpdate = currentExercisePerf.sets[setIndex];
          final NumberTickerController? tickerController =
              _weightTickerControllers[exerciseFlatIndex];
          final double actualWeight =
              tickerController?.number ?? setToUpdate.targetWeight;
          final exercise = _currentExercises[exerciseFlatIndex];

          int actualRepsToRecord = setToUpdate.targetReps;
          if (exercise.workoutType == WorkoutType.Timed) {
            actualRepsToRecord =
                int.tryParse(exercise.reps) ?? actualRepsToRecord;
          } else {
            actualRepsToRecord =
                int.tryParse(exercise.reps) ?? actualRepsToRecord;
          }

          final updatedSet = setToUpdate.copyWith(
            actualReps: actualRepsToRecord,
            actualWeight: actualWeight,
            isCompleted: true,
          );

          final updatedSetsList = List<SetPerformance>.from(
            currentExercisePerf.sets,
          );
          updatedSetsList[setIndex] = updatedSet;
          final updatedExercisePerf = currentExercisePerf.copyWith(
            sets: updatedSetsList,
          );

          final updatedSessionExercises = List<ExercisePerformance>.from(
            _activeWorkoutSession!.exercises,
          );
          updatedSessionExercises[exerciseFlatIndex] = updatedExercisePerf;
          _activeWorkoutSession = _activeWorkoutSession!.copyWith(
            exercises: updatedSessionExercises,
          );
        }
      }
    } catch (_) {}

    if (_currentStepIndex < _exerciseIndexesInStepOrder.length - 1) {
      setState(() => _currentStepIndex++);
    } else {
      _finishWorkout();
    }
  }

  void _finishWorkout() {
    setState(() => _finished = true);
    _confettiController.play();
    widget.celebrateCallback?.call();

    Routine routineToSave = widget.originalRoutine.copyWith(
      completionCount: widget.originalRoutine.completionCount + 1,
      lastCompletedDate: DateTime.now(),
      routineHistory: List<int>.from(widget.originalRoutine.routineHistory)
        ..add(DateTime.now().millisecondsSinceEpoch),
    );

    if (_activeWorkoutSession != null) {
      List<Part> updatedPartsData = [];
      int overallExercisePerformanceIndex = 0;
      for (int pIdx = 0; pIdx < routineToSave.parts.length; pIdx++) {
        Part currentPartTemplate = routineToSave.parts[pIdx];
        List<Exercise> updatedExercisesInPartData = [];
        for (
          int eIdx = 0;
          eIdx < currentPartTemplate.exercises.length;
          eIdx++
        ) {
          Exercise currentExerciseTemplate =
              currentPartTemplate.exercises[eIdx];
          double? newLastUsedWeightForThisExercise;
          if (overallExercisePerformanceIndex <
              _activeWorkoutSession!.exercises.length) {
            ExercisePerformance exercisePerf =
                _activeWorkoutSession!
                    .exercises[overallExercisePerformanceIndex];
            if (exercisePerf.exerciseName == currentExerciseTemplate.name) {
              SetPerformance? lastCompletedSetPerf = exercisePerf.sets
                  .lastWhere(
                    (sp) => sp.isCompleted,
                    orElse: () => _nullPlaceholderSetPerformance,
                  );
              if (lastCompletedSetPerf != _nullPlaceholderSetPerformance) {
                newLastUsedWeightForThisExercise =
                    lastCompletedSetPerf.actualWeight;
              }
            }
          }
          updatedExercisesInPartData.add(
            currentExerciseTemplate.copyWith(
              lastUsedWeight: newLastUsedWeightForThisExercise,
            ),
          );
          overallExercisePerformanceIndex++;
        }
        updatedPartsData.add(
          currentPartTemplate.copyWith(exercises: updatedExercisesInPartData),
        );
      }
      routineToSave = routineToSave.copyWith(parts: updatedPartsData);
    }

    try {
      context.read<RoutinesBloc>().updateRoutine(routineToSave);
      if (_activeWorkoutSession != null) {
        final finishedSessionForDb = _activeWorkoutSession!.copyWith(
          isCompleted: true,
          endTime: routineToSave.lastCompletedDate,
        );
        context.read<WorkoutSessionBloc>().add(
          WorkoutSessionSaveCompleted(finishedSessionForDb),
        );
      }
    } catch (_) {}
  }

  Future<void> _showWeightEditDialog(NumberTickerController controller) async {
    final TextEditingController textController = TextEditingController(
      text: controller.number.toStringAsFixed(1),
    );
    await showDialog<void>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Edit Weight'),
            content: TextField(
              controller: textController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Weight (kg)'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  final v = double.tryParse(textController.text);
                  if (v != null && v >= 0) controller.number = v;
                  Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  Future<bool> _onWillPop() async {
    if (_finished) return true;
    final shouldQuit =
        await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder:
              (dialogContext) => AlertDialog(
                title: const Text('Quit Workout?'),
                content: const Text(
                  'Your progress for this session will not be saved if you quit now.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Stay'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(dialogContext, true);
                    },
                    child: const Text(
                      'Quit Workout',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
        ) ??
        false;
    if (shouldQuit) widget.onBackPressed?.call();
    return shouldQuit;
  }
}

// Placeholder for orElse in lastWhere
final SetPerformance _nullPlaceholderSetPerformance = SetPerformance(
  targetReps: 0,
  targetWeight: 0,
  actualReps: 0,
  actualWeight: 0,
  isCompleted: false,
);
