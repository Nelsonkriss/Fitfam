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
import 'package:workout_planner/utils/routine_helpers.dart'; 

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

// Define TextStyles (consider moving to a theme file or using Theme.of(context).textTheme)
// These will be updated to use theme values later.
final _kLabelTextStyle = TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12);
final _kValueTextStyle = const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold);

class _RoutineStepPageState extends State<RoutineStepPage> with TickerProviderStateMixin {
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

  Map<int, NumberTickerController> _tickerControllers = {}; 

  @override
  void initState() {
    super.initState();
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
  }

  void _rebuildStateFromRoutine() {
    _currentExercises = _currentWorkingRoutine.parts.expand((p) => p.exercises).toList();
    _exerciseIndexesInStepOrder.clear();
    _partIndexesInStepOrder.clear();
    _setsTotalInStepOrder.clear();
    _setNumberOfStep.clear();
    _disposeTickerControllers(); 
    _tickerControllers = {}; 

    int exerciseCounter = 0; 

    for (int partIdx = 0; partIdx < _currentWorkingRoutine.parts.length; partIdx++) {
      final part = _currentWorkingRoutine.parts[partIdx];
      if (part.exercises.isEmpty) continue; 

      int exercisesInThisSetGroup = 1;
      switch (part.setType) {
        case SetType.Super: exercisesInThisSetGroup = 2; break;
        case SetType.Tri:   exercisesInThisSetGroup = 3; break;
        case SetType.Giant: exercisesInThisSetGroup = 4; break;
        case SetType.Regular:
        case SetType.Drop:
        default: exercisesInThisSetGroup = 1; break;
      }

      exercisesInThisSetGroup = min(exercisesInThisSetGroup, part.exercises.length);
      if (exercisesInThisSetGroup == 0) continue;

      final totalSets = part.exercises.first.sets;
      if (totalSets <= 0) continue; 

      for (int setNum = 1; setNum <= totalSets; setNum++) { 
        for (int i = 0; i < exercisesInThisSetGroup; i++) { 
          final currentExerciseFlatIndex = exerciseCounter + i; 

          if (currentExerciseFlatIndex < _currentExercises.length) {
            _exerciseIndexesInStepOrder.add(currentExerciseFlatIndex);
            _partIndexesInStepOrder.add(partIdx);
            _setsTotalInStepOrder.add(totalSets);
            _setNumberOfStep.add(setNum);

            if (!_tickerControllers.containsKey(currentExerciseFlatIndex)) {
              final exerciseTemplate = _currentExercises[currentExerciseFlatIndex];
              _tickerControllers[currentExerciseFlatIndex] = NumberTickerController(
                  initial: exerciseTemplate.lastUsedWeight ?? exerciseTemplate.weight, 
                  step: 0.5, 
                  minValue: 0  
              );
            }
          } else {
            debugPrint("Warning: Exercise index ($currentExerciseFlatIndex) out of bounds during step generation.");
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
    super.dispose();
  }

  void _disposeTickerControllers() {
    for (var controller in _tickerControllers.values) {
      try {
        controller.dispose();
      } catch (e) {
        debugPrint("Error disposing NumberTickerController: $e");
      }
    }
  }

  Future<bool> _checkConnection() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      if (!mounted) return false;
      _showSnackBar('No Internet Connection', isError: true); 
      return false;
    }
    return true;
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return; 
    ScaffoldMessenger.of(context).removeCurrentSnackBar(); 
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.redAccent : null, 
          duration: const Duration(seconds: 3) 
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // Get theme for styling

    String title = 'Workout'; 
    if (!_finished && _currentStepIndex < _exerciseIndexesInStepOrder.length) {
      final currentPartIdx = _partIndexesInStepOrder[_currentStepIndex];
      if (currentPartIdx >= 0 && currentPartIdx < _currentWorkingRoutine.parts.length) {
        final currentPart = _currentWorkingRoutine.parts[currentPartIdx];
        try {
          final bodyPartStr = targetedBodyPartToStringConverter(currentPart.targetedBodyPart);
          final setTypeStr = setTypeToStringConverter(currentPart.setType);
          title = '$bodyPartStr - $setTypeStr';
        } catch (e) {
          debugPrint("Error converting enum to string for title: $e");
        }
      }
    } else if (_finished) {
      title = 'Finished!';
    }

    final totalSteps = _exerciseIndexesInStepOrder.length;
    final progress = totalSteps == 0 ? 0.0 : ((_currentStepIndex + (_finished ? 1: 0)) / totalSteps);

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        key: _scaffoldKey, 
        appBar: AppBar(
          // title: Text(title, style: const TextStyle(color: Colors.white70, fontSize: 16)), // Will use AppBarTheme
          title: Text(title), // AppBarTheme will style this
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4.0),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0), 
              backgroundColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5), // Themed
              valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.secondary), // Themed
            ),
          ),
          // backgroundColor: Theme.of(context).primaryColor, // Will use AppBarTheme
          // iconTheme: const IconThemeData(color: Colors.white), // Will use AppBarTheme
        ),
        // backgroundColor: Theme.of(context).primaryColor, // Will use Scaffold's background from theme
        body: _finished ? _buildFinishedScreen() : _buildStepper(),
      ),
    );
  }

  Widget _buildFinishedScreen() {
    final theme = Theme.of(context);
    return Container( // Keep gradient for finished screen, or adapt to theme
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
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
              maxBlastForce: 10, minBlastForce: 5,
              emissionFrequency: 0.04, numberOfParticles: 15,
              gravity: 0.1,
              colors: [ 
                theme.colorScheme.secondary, theme.colorScheme.primaryContainer, 
                theme.colorScheme.tertiary, Colors.lightGreenAccent
              ],
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center, 
            mainAxisSize: MainAxisSize.min,
            children: [
              Text( 'Workout Complete! 🎉',
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
                // Style will come from ElevatedButtonThemeData
                child: const Text( 'DONE'), 
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepper() {
    final theme = Theme.of(context);
    if (_exerciseIndexesInStepOrder.isEmpty) {
      return Center(child: Text("No steps generated for this routine.", style: theme.textTheme.bodyMedium));
    }
    if (_currentStepIndex >= _exerciseIndexesInStepOrder.length) {
      return Center(child: Text("Workout progression error.", style: TextStyle(color: theme.colorScheme.error)));
    }

    return ListView(
      physics: const ClampingScrollPhysics(), 
      children: [
        Theme( // Override Stepper theme locally if needed, or rely on global theme
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: theme.colorScheme.secondary, // Active step color
              onSurface: theme.colorScheme.onSurface, // Step title color etc.
              surface: theme.colorScheme.surface, 
            ),
            dividerColor: theme.dividerColor.withOpacity(0.5),
          ),
          child: Stepper(
            physics: const NeverScrollableScrollPhysics(), 
            type: StepperType.vertical,
            currentStep: _currentStepIndex,
            onStepTapped: null, 
            onStepCancel: null, 
            onStepContinue: _handleStepContinue, 
            controlsBuilder: (BuildContext context, ControlsDetails details) {
              return Padding(
                padding: const EdgeInsets.only(top: 24.0, bottom: 16.0), 
                child: Center(
                  child: ElevatedButton( // Will use ElevatedButtonThemeData
                    onPressed: details.onStepContinue, 
                    child: const Text('NEXT SET'),
                  ),
                ),
              );
            },
            steps: List.generate(_exerciseIndexesInStepOrder.length, (stepIdx) {
              final exerciseIdx = _exerciseIndexesInStepOrder[stepIdx];
              final setNum = _setNumberOfStep[stepIdx];
              final totalSets = _setsTotalInStepOrder[stepIdx];

              if (exerciseIdx >= _currentExercises.length) {
                return Step(title: Text("Error: Invalid Exercise Index", style: TextStyle(color: theme.colorScheme.error)), content: const SizedBox());
              }
              final exercise = _currentExercises[exerciseIdx];

              final isActive = stepIdx == _currentStepIndex;
              final isCompleted = stepIdx < _currentStepIndex;

              String stepTitle = "${exercise.name} (Set $setNum of $totalSets)";
              Color stepTitleColor = isActive 
                  ? theme.colorScheme.secondary // Or primary
                  : (isCompleted ? theme.textTheme.bodySmall!.color!.withOpacity(0.6) : theme.textTheme.bodyLarge!.color!);


              return Step(
                title: Text(
                  stepTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    color: stepTitleColor,
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                content: isActive ? _buildStepContent(exerciseIdx) : const SizedBox.shrink(),
                isActive: isActive,
                state: isCompleted ? StepState.complete : StepState.indexed,
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildStepContent(int exerciseIndex) {
    final theme = Theme.of(context);
    if (!_tickerControllers.containsKey(exerciseIndex)) { 
      debugPrint("Error: Ticker controller missing for exercise index $exerciseIndex");
      return Center(child: Text("Error loading controls.", style: TextStyle(color: theme.colorScheme.error)));
    }
    final exercise = _currentExercises[exerciseIndex];
    final tickerController = _tickerControllers[exerciseIndex]!;
    final setNum = _setNumberOfStep[_currentStepIndex];
    final totalSets = _setsTotalInStepOrder[_currentStepIndex];

    final labelStyle = theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7));
    final valueStyle = theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.onSurface);


    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildWeightButton(Icons.remove, tickerController),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Column(
                    children: [
                      Text("WEIGHT (kg)", style: labelStyle),
                      const SizedBox(height: 4),
                      NumberTicker(
                        controller: tickerController,
                        textStyle: (theme.textTheme.displaySmall ?? const TextStyle(fontSize: 56, fontFamily: 'RobotoMono')).copyWith( // Provide default if displaySmall is null
                            color: theme.colorScheme.onSurface,
                            // fontFamily: 'RobotoMono' // Already in default or displaySmall
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _buildWeightButton(Icons.add, tickerController),
            ],
          ),
          const SizedBox(height: 24), 

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildInfoColumn("SET", "$setNum / $totalSets", labelStyle, valueStyle),
              _buildInfoColumn(
                  exercise.workoutType == WorkoutType.Cardio ? "TIME (sec)" : "REPS",
                  exercise.reps,
                  labelStyle, valueStyle
              ),
            ],
          ),
          const SizedBox(height: 16),

          TextButton.icon(
            icon: Icon(Icons.info_outline, color: theme.colorScheme.onSurface.withOpacity(0.7), size: 18),
            label: Text("Exercise Info", style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7))),
            onPressed: () => _launchURL(exercise.name),
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoColumn(String label, String value, TextStyle? labelStyle, TextStyle? valueStyle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: labelStyle),
        const SizedBox(height: 4),
        Text(value, style: valueStyle),
      ],
    );
  }

  Widget _buildWeightButton(IconData icon, NumberTickerController controller) {
    final theme = Theme.of(context);
    VoidCallback action;
    if (icon == Icons.add) {
      action = controller.increment; 
    } else {
      action = controller.decrement; 
    }

    return ElevatedButton(
      onPressed: action, 
      style: ElevatedButton.styleFrom(
        shape: const CircleBorder(),
        padding: const EdgeInsets.all(16),
        backgroundColor: theme.colorScheme.secondaryContainer.withOpacity(0.5), // Themed
        foregroundColor: theme.colorScheme.onSecondaryContainer, // Themed
      ),
      child: Icon(icon, size: 28),
    );
  }

  void _handleStepContinue() {
    if (_exerciseIndexesInStepOrder.isEmpty || _currentStepIndex >= _exerciseIndexesInStepOrder.length) {
      debugPrint("Cannot continue: Invalid step state.");
      return;
    }

    if (_activeWorkoutSession != null) {
      final int exerciseFlatIndex = _exerciseIndexesInStepOrder[_currentStepIndex];
      final int setNumber = _setNumberOfStep[_currentStepIndex]; 
      final int setIndex = setNumber - 1; 

      if (exerciseFlatIndex < _activeWorkoutSession!.exercises.length) {
        final ExercisePerformance currentExercisePerf = _activeWorkoutSession!.exercises[exerciseFlatIndex];

        if (setIndex >= 0 && setIndex < currentExercisePerf.sets.length) {
          final SetPerformance setToUpdate = currentExercisePerf.sets[setIndex];

          final NumberTickerController? tickerController = _tickerControllers[exerciseFlatIndex];
          final double actualWeight = tickerController?.number ?? setToUpdate.targetWeight; 

          final int actualReps = setToUpdate.targetReps; 

          final updatedSet = setToUpdate.copyWith(
            actualReps: actualReps,
            actualWeight: actualWeight,
            isCompleted: true,
          );

          final updatedSetsList = List<SetPerformance>.from(currentExercisePerf.sets);
          updatedSetsList[setIndex] = updatedSet;

          final updatedExercisePerf = currentExercisePerf.copyWith(sets: updatedSetsList);

          final updatedSessionExercises = List<ExercisePerformance>.from(_activeWorkoutSession!.exercises);
          updatedSessionExercises[exerciseFlatIndex] = updatedExercisePerf;

          _activeWorkoutSession = _activeWorkoutSession!.copyWith(exercises: updatedSessionExercises);
          debugPrint("Updated _activeWorkoutSession for Exercise: ${updatedExercisePerf.exerciseName}, Set: $setNumber, Weight: $actualWeight, Reps: $actualReps");

        } else {
          debugPrint("Error: Invalid set index ($setIndex) for ExercisePerformance '${currentExercisePerf.exerciseName}'.");
        }
      } else {
        debugPrint("Error: Invalid exercise index ($exerciseFlatIndex) for _activeWorkoutSession.");
      }
    } else {
      debugPrint("Error: _activeWorkoutSession is null in _handleStepContinue.");
    }

    setState(() {
      if (_currentStepIndex < _exerciseIndexesInStepOrder.length - 1) {
        _currentStepIndex++; 
        debugPrint('Advanced to step index: $_currentStepIndex');
      } else {
        _finishWorkout(); 
      }
    });
  }

  void _finishWorkout() {
    debugPrint('Routine completed! Preparing final routine state...');
    setState(() => _finished = true);
    _confettiController.play(); 
    widget.celebrateCallback?.call(); 

    Routine routineToSave = widget.originalRoutine.copyWith(
      completionCount: widget.originalRoutine.completionCount + 1,
      lastCompletedDate: DateTime.now(),
      routineHistory: List<int>.from(widget.originalRoutine.routineHistory)..add(DateTime.now().millisecondsSinceEpoch),
    );

    if (_activeWorkoutSession != null) {
      List<Part> updatedPartsData = [];
      int overallExercisePerformanceIndex = 0; 

      for (int pIdx = 0; pIdx < routineToSave.parts.length; pIdx++) {
        Part currentPartTemplate = routineToSave.parts[pIdx];
        List<Exercise> updatedExercisesInPartData = [];

        for (int eIdx = 0; eIdx < currentPartTemplate.exercises.length; eIdx++) {
          Exercise currentExerciseTemplate = currentPartTemplate.exercises[eIdx];
          double? newLastUsedWeightForThisExercise;

          if (overallExercisePerformanceIndex < _activeWorkoutSession!.exercises.length) {
            ExercisePerformance exercisePerf = _activeWorkoutSession!.exercises[overallExercisePerformanceIndex];
            
            if (exercisePerf.exerciseName == currentExerciseTemplate.name) {
                SetPerformance? lastCompletedSetPerf = exercisePerf.sets.lastWhere(
                    (sp) => sp.isCompleted,
                    orElse: () => _nullPlaceholderSetPerformance 
                );

                if (lastCompletedSetPerf != _nullPlaceholderSetPerformance) {
                    newLastUsedWeightForThisExercise = lastCompletedSetPerf.actualWeight;
                }
            } else {
              debugPrint("Warning: Exercise name mismatch during lastUsedWeight update. Template: '${currentExerciseTemplate.name}', Perf: '${exercisePerf.exerciseName}'. Skipping lastUsedWeight update for this exercise.");
            }
          }
          
          updatedExercisesInPartData.add(currentExerciseTemplate.copyWith(
            lastUsedWeight: newLastUsedWeightForThisExercise 
          ));
          overallExercisePerformanceIndex++;
        }
        updatedPartsData.add(currentPartTemplate.copyWith(exercises: updatedExercisesInPartData));
      }
      routineToSave = routineToSave.copyWith(parts: updatedPartsData);
    }

    try {
      context.read<RoutinesBloc>().updateRoutine(routineToSave); 
      debugPrint("Final routine update (with lastUsedWeights) sent to BLoC.");

      if (_activeWorkoutSession != null) {
        final finishedSessionForDb = _activeWorkoutSession!.copyWith(
          isCompleted: true,
          endTime: routineToSave.lastCompletedDate, 
        );
        context.read<WorkoutSessionBloc>().add(WorkoutSessionSaveCompleted(finishedSessionForDb));
        debugPrint("WorkoutSessionSaveCompleted event added for session ID: ${finishedSessionForDb.id}.");
      } else {
        debugPrint("Error: _activeWorkoutSession was null. Cannot save WorkoutSession.");
        _showSnackBar("Critical Error: Could not record session details.", isError: true);
      }

    } catch(e) {
      debugPrint("Error updating routine or session in BLoC after finish: $e");
      _showSnackBar("Error saving final workout state.", isError: true);
    }
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
    ) ?? false; 

    if (shouldQuit) {
      widget.onBackPressed?.call();
    }
    return shouldQuit; 
  }

  Future<void> _launchURL(String exerciseName) async {
    if (exerciseName.trim().isEmpty) return;
    if (!await _checkConnection()) return; 

    final query = Uri.encodeComponent(exerciseName.trim());
    final url = Uri.parse('https://www.bodybuilding.com/exercises/search?query=$query');

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        debugPrint("Could not launch $url");
        _showSnackBar("Could not open exercise info link."); 
      }
    } catch (e) {
      debugPrint("Error launching URL $url: $e");
      _showSnackBar("Could not open exercise info link."); 
    }
  }
} 

// Static placeholder for SetPerformance to be used in orElse of lastWhere.
// This is used to avoid creating a new instance every time orElse is called.
final SetPerformance _nullPlaceholderSetPerformance = SetPerformance( // Removed static
  targetReps: 0,
  targetWeight: 0,
  actualReps: 0,
  actualWeight: 0,
  isCompleted: false
);
