import 'dart:async';
import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:workout_planner/bloc/routines_bloc.dart';
import 'package:workout_planner/bloc/workout_session_bloc.dart';
import 'package:workout_planner/models/workout_session.dart';
import 'package:workout_planner/models/exercise_performance.dart';
import 'package:workout_planner/models/set_performance.dart';
import 'package:workout_planner/utils/android_animations.dart';
import 'package:workout_planner/ui/components/exercise_animation_widget.dart';

import 'components/number_ticker.dart';

class RoutineStepPageV2 extends StatefulWidget {
  final Routine originalRoutine;
  final VoidCallback? celebrateCallback;
  final VoidCallback? onBackPressed;

  const RoutineStepPageV2({
    required Routine routine,
    this.celebrateCallback,
    this.onBackPressed,
    super.key,
  }) : originalRoutine = routine;

  @override
  State<RoutineStepPageV2> createState() => _RoutineStepPageV2State();
}

class _RoutineStepPageV2State extends State<RoutineStepPageV2> with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ConfettiController _confettiController = ConfettiController(duration: const Duration(seconds: 5));

  late Routine _currentWorkingRoutine;
  late List<Exercise> _currentExercises;
  bool _finished = false;

  final List<int> _exerciseIndexesInStepOrder = [];
  final List<int> _partIndexesInStepOrder = [];
  final List<int> _setsTotalInStepOrder = [];
  final List<int> _setNumberOfStep = [];
  int _currentStepIndex = 0;

  WorkoutSession? _activeWorkoutSession;

  Map<int, NumberTickerController> _weightTickerControllers = {};
  Map<int, NumberTickerController> _repsTickerControllers = {};

  late AnimationController _setTransitionController;
  late AnimationController _exerciseTransitionController;
  late AnimationController _restPeriodController;
  late AnimationController _preparationController;
  late AnimationController _completionController;

  bool _isInRestPeriod = false;
  bool _isInPreparation = false;
  bool _showingPersonalRecord = false;
  bool _showingExerciseTransition = false;
  int _restTimeRemaining = 0;
  int _preparationTimeRemaining = 3;
  Timer? _restTimer;
  Timer? _preparationTimer;
  Timer? _exerciseTimer;
  int _timedExerciseRemainingSeconds = 0;
  bool _isTimedExerciseActive = false;

  @override
  void initState() {
    super.initState();

    _setTransitionController = AnimationController(duration: AndroidAnimations.m3LongDuration, vsync: this);
    _exerciseTransitionController = AnimationController(duration: AndroidAnimations.m3MediumDuration, vsync: this);
    _restPeriodController = AnimationController(duration: AndroidAnimations.m3MediumDuration, vsync: this);
    _preparationController = AnimationController(duration: AndroidAnimations.m3MediumDuration, vsync: this);
    _completionController = AnimationController(duration: AndroidAnimations.m3ExtraLongDuration, vsync: this);

    _currentWorkingRoutine = widget.originalRoutine.copyWith(
      parts: widget.originalRoutine.parts.map((originalPart) {
        return originalPart.copyWith(
          exercises: originalPart.exercises.map((originalExercise) {
            return originalExercise.copyWith();
          }).toList(),
        );
      }).toList(),
    );

    _rebuildStateFromRoutine();

    _activeWorkoutSession = WorkoutSession.startNew(routine: widget.originalRoutine);
    debugPrint("RoutineStepPage: Initialized _activeWorkoutSession with ID: ${_activeWorkoutSession?.id}");

    _startSetPreparation();
  }

  void _rebuildStateFromRoutine() {
    _currentExercises = _currentWorkingRoutine.parts.expand((p) => p.exercises).toList();
    _exerciseIndexesInStepOrder.clear();
    _partIndexesInStepOrder.clear();
    _setsTotalInStepOrder.clear();
    _setNumberOfStep.clear();
    _disposeTickerControllers();
    _weightTickerControllers = {};
    _repsTickerControllers = {};

    int exerciseCounter = 0;

    for (int partIdx = 0; partIdx < _currentWorkingRoutine.parts.length; partIdx++) {
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

      exercisesInThisSetGroup = min(exercisesInThisSetGroup, part.exercises.length);
      if (exercisesInThisSetGroup == 0) continue;

      for (int i = 0; i < exercisesInThisSetGroup; i++) {
        final currentExerciseFlatIndex = exerciseCounter + i;
        if (currentExerciseFlatIndex >= _currentExercises.length) {
          debugPrint("Warning: Exercise index ($currentExerciseFlatIndex) out of bounds during step generation.");
          continue;
        }

        final exercise = _currentExercises[currentExerciseFlatIndex];
        final totalSets = exercise.sets;
        if (totalSets <= 0) continue;

        for (int setNum = 1; setNum <= totalSets; setNum++) {
          _exerciseIndexesInStepOrder.add(currentExerciseFlatIndex);
          _partIndexesInStepOrder.add(partIdx);
          _setsTotalInStepOrder.add(totalSets);
          _setNumberOfStep.add(setNum);

          if (!_weightTickerControllers.containsKey(currentExerciseFlatIndex)) {
            final exerciseTemplate = _currentExercises[currentExerciseFlatIndex];
            _weightTickerControllers[currentExerciseFlatIndex] = NumberTickerController(
                initial: exerciseTemplate.lastUsedWeight ?? exerciseTemplate.weight, step: 0.5, minValue: 0);
            
            // Handle reps that might be ranges like "6-8" or single numbers
            double initialReps = 8.0; // Default fallback
            try {
              final repsString = exerciseTemplate.reps.trim();
              if (repsString.contains('-')) {
                // Handle range like "6-8", take the first number
                final parts = repsString.split('-');
                if (parts.isNotEmpty) {
                  initialReps = double.parse(parts[0].trim());
                }
              } else {
                // Handle single number
                initialReps = double.parse(repsString);
              }
            } catch (e) {
              debugPrint("Error parsing reps '${exerciseTemplate.reps}': $e. Using default value.");
              initialReps = 8.0;
            }
            
            _repsTickerControllers[currentExerciseFlatIndex] =
                NumberTickerController(initial: initialReps, step: 1, minValue: 0);
          }
        }
      }
      exerciseCounter += exercisesInThisSetGroup;
    }
    debugPrint("Generated ${_exerciseIndexesInStepOrder.length} total steps for the workout.");
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _disposeTickerControllers();
    _setTransitionController.dispose();
    _exerciseTransitionController.dispose();
    _restPeriodController.dispose();
    _preparationController.dispose();
    _completionController.dispose();
    _restTimer?.cancel();
    _preparationTimer?.cancel();
    _exerciseTimer?.cancel();
    super.dispose();
  }

  void _disposeTickerControllers() {
    for (var controller in _weightTickerControllers.values) {
      try {
        controller.dispose();
      } catch (e) {
        debugPrint("Error disposing NumberTickerController: $e");
      }
    }
    for (var controller in _repsTickerControllers.values) {
      try {
        controller.dispose();
      } catch (e) {
        debugPrint("Error disposing NumberTickerController: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.black,
        body: _finished ? _buildFinishedScreen() : _buildWorkoutInterface(),
      ),
    );
  }

  Widget _buildFinishedScreen() {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              maxBlastForce: 10,
              minBlastForce: 5,
              emissionFrequency: 0.04,
              numberOfParticles: 15,
              gravity: 0.1,
              colors: [
                theme.colorScheme.secondary,
                theme.colorScheme.primaryContainer,
                theme.colorScheme.tertiary,
                Colors.lightGreenAccent
              ],
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Workout Complete! 🎉',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(color: theme.colorScheme.onPrimary),
              ),
              const SizedBox(height: 20),
              Icon(Icons.emoji_events_outlined, size: 80, color: theme.colorScheme.secondary),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                },
                child: const Text('DONE'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutInterface() {
    if (_exerciseIndexesInStepOrder.isEmpty) {
      return const Center(
        child: Text(
          "No steps generated for this routine.",
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
      );
    }
    if (_currentStepIndex >= _exerciseIndexesInStepOrder.length) {
      return const Center(
        child: Text(
          "Workout progression error.",
          style: TextStyle(color: Colors.red, fontSize: 18),
        ),
      );
    }

    final exerciseIdx = _exerciseIndexesInStepOrder[_currentStepIndex];
    final exercise = _currentExercises[exerciseIdx];
    final setNum = _setNumberOfStep[_currentStepIndex];
    final totalSets = _setsTotalInStepOrder[_currentStepIndex];
    final weightController = _weightTickerControllers[exerciseIdx]!;
    final repsController = _repsTickerControllers[exerciseIdx]!;

    return Stack(
      children: [
        // Background gradient
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black, Color(0xFF1a1a1a)],
            ),
          ),
        ),
        // Exercise animation - positioned in center with better visibility
        Positioned(
          top: 100,
          left: 0,
          right: 0,
          child: ExerciseAnimationWidget(
            exerciseName: exercise.name,
            width: double.infinity,
            height: 400,
            autoPlay: !_isInRestPeriod && !_isInPreparation,
            showControls: false,
            showDescription: false,
          ),
        ),
        SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _buildExerciseInfo(exercise, setNum, totalSets),
              ),
              _buildInputControls(weightController, repsController, exercise),
              _buildActionButtons(),
              _buildNextExerciseInfo(),
              const SizedBox(height: 20),
            ],
          ),
        ),
        if (_isInRestPeriod) _buildRestPeriodOverlay(),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          const Text(
            'Workout',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseInfo(Exercise exercise, int setNum, int totalSets) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          exercise.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
        const SizedBox(height: 8),
        Text(
          'Set $setNum of $totalSets',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildInputControls(
      NumberTickerController weightController, NumberTickerController repsController, Exercise exercise) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildControlColumn("Weight (kg)", weightController),
          _buildControlColumn("Reps", repsController),
        ],
      ),
    );
  }

  Widget _buildControlColumn(String label, NumberTickerController controller) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton(
              onPressed: () => controller.decrement(),
              icon: const Icon(Icons.remove, color: Colors.white),
            ),
            GestureDetector(
              onTap: () => _showNumberInputDialog(label, controller),
              child: NumberTicker(
                controller: controller,
                textStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              onPressed: () => controller.increment(),
              icon: const Icon(Icons.add, color: Colors.white),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: _handleStepContinue,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Done', style: TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: OutlinedButton(
              onPressed: _skipExercise,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white54),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Skip', style: TextStyle(fontSize: 18, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextExerciseInfo() {
    if (_currentStepIndex >= _exerciseIndexesInStepOrder.length - 1) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text(
          'Last Exercise!',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 16,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    final nextExerciseIdx = _exerciseIndexesInStepOrder[_currentStepIndex + 1];
    final nextExercise = _currentExercises[nextExerciseIdx];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Text(
        'Next: ${nextExercise.name}',
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 16,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildRestPeriodOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.8),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Rest Time',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '${_restTimeRemaining}s',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 48,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _endRestPeriod,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              ),
              child: const Text('Skip Rest'),
            ),
          ],
        ),
      ),
    );
  }

  void _handleStepContinue() {
    if (_currentStepIndex >= _exerciseIndexesInStepOrder.length) return;

    final exerciseIdx = _exerciseIndexesInStepOrder[_currentStepIndex];
    final exercise = _currentExercises[exerciseIdx];
    final weight = _weightTickerControllers[exerciseIdx]!.value;
    final reps = _repsTickerControllers[exerciseIdx]!.value.toInt();

    final setPerformance = SetPerformance(
      targetReps: int.tryParse(exercise.reps) ?? 0,
      targetWeight: exercise.weight,
      actualReps: reps,
      actualWeight: weight,
      isCompleted: true,
    );

    final exercisePerformances = _activeWorkoutSession!.exercises.map((ep) {
      if (ep.exerciseName == exercise.name) {
        final newSets = List<SetPerformance>.from(ep.sets)..add(setPerformance);
        return ep.copyWith(sets: newSets);
      }
      return ep;
    }).toList();

    _activeWorkoutSession = _activeWorkoutSession?.copyWith(exercises: exercisePerformances);

    if (_currentStepIndex < _exerciseIndexesInStepOrder.length - 1) {
      setState(() {
        _currentStepIndex++;
      });
      _startRestPeriod(duration: 60); // Assuming 60 seconds rest
    } else {
      _finishWorkout();
    }
  }

  void _skipExercise() {
    if (_currentStepIndex >= _exerciseIndexesInStepOrder.length - 1) {
      _finishWorkout();
      return;
    }

    setState(() {
      _currentStepIndex++;
    });
  }

  void _startRestPeriod({int duration = 60}) {
    if (duration <= 0) {
      _startSetPreparation();
      return;
    }
    setState(() {
      _isInRestPeriod = true;
      _restTimeRemaining = duration;
    });
    _restPeriodController.forward(from: 0);
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_restTimeRemaining > 1) {
        setState(() {
          _restTimeRemaining--;
        });
      } else {
        _endRestPeriod();
      }
    });
  }

  void _endRestPeriod() {
    _restTimer?.cancel();
    _restPeriodController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _isInRestPeriod = false;
        });
        _startSetPreparation();
      }
    });
  }

  void _startSetPreparation() {
    setState(() {
      _isInPreparation = true;
      _preparationTimeRemaining = 3;
    });
    _preparationController.forward(from: 0);
    _preparationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_preparationTimeRemaining > 1) {
        setState(() {
          _preparationTimeRemaining--;
        });
      } else {
        timer.cancel();
        _preparationController.reverse().then((_) {
          if (mounted) {
            setState(() {
              _isInPreparation = false;
            });
          }
        });
      }
    });
  }

  void _finishWorkout() {
    final finalSession = _activeWorkoutSession?.copyWith(
      endTime: DateTime.now(),
      isCompleted: true,
    );
    if (finalSession != null) {
      Provider.of<WorkoutSessionBloc>(context, listen: false).add(WorkoutSessionSaveCompleted(finalSession));
      Provider.of<RoutinesBloc>(context, listen: false).updateRoutine(widget.originalRoutine.copyWith(
            completionCount: widget.originalRoutine.completionCount + 1,
            lastCompletedDate: DateTime.now(),
          ));
    }

    setState(() {
      _finished = true;
    });
    _completionController.forward();
    _confettiController.play();
    widget.celebrateCallback?.call();
  }

  Future<void> _showNumberInputDialog(String label, NumberTickerController controller) async {
    final TextEditingController textController = TextEditingController(
      text: controller.value.toString(),
    );

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Enter $label'),
          content: TextField(
            controller: textController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: InputDecoration(
              labelText: label,
              suffixText: label == 'Weight (kg)' ? 'kg' : null,
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            TextButton(
              onPressed: () {
                final newValue = double.tryParse(textController.text);
                if (newValue != null) {
                  controller.number = newValue;
                }
                Navigator.pop(context);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _onWillPop() async {
    if (_finished) return true;

    final shouldQuit = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Quit Workout?'),
            content: const Text('Your progress for this session will not be saved if you quit now.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Stay'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext, true);
                },
                child: const Text('Quit Workout', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;

    if (shouldQuit) {
      widget.onBackPressed?.call();
    }
    return shouldQuit;
  }
}
