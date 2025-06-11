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
import 'package:workout_planner/utils/android_animations.dart';
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

  // Enhanced Animation Controllers
  late AnimationController _setTransitionController;
  late AnimationController _exerciseTransitionController;
  late AnimationController _restPeriodController;
  late AnimationController _preparationController;
  late AnimationController _completionController;
  
  // Animation States
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
    
    // Initialize animation controllers
    _setTransitionController = AnimationController(
      duration: AndroidAnimations.m3LongDuration,
      vsync: this,
    );
    _exerciseTransitionController = AnimationController(
      duration: AndroidAnimations.m3MediumDuration,
      vsync: this,
    );
    _restPeriodController = AnimationController(
      duration: AndroidAnimations.m3MediumDuration,
      vsync: this,
    );
    _preparationController = AnimationController(
      duration: AndroidAnimations.m3MediumDuration,
      vsync: this,
    );
    _completionController = AnimationController(
      duration: AndroidAnimations.m3ExtraLongDuration,
      vsync: this,
    );
    
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
    
    // Start with preparation animation for first exercise
    _startSetPreparation();
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
    
    // Dispose animation controllers
    _setTransitionController.dispose();
    _exerciseTransitionController.dispose();
    _restPeriodController.dispose();
    _preparationController.dispose();
    _completionController.dispose();
    
    // Cancel timers
    _restTimer?.cancel();
    _preparationTimer?.cancel();
    _exerciseTimer?.cancel();
    
    super.dispose();
  }

  void _startTimedExercise(Exercise exercise) {
    if (exercise.workoutType != WorkoutType.Timed) return;
    
    final seconds = int.tryParse(exercise.reps) ?? 0;
    if (seconds <= 0) return;

    setState(() {
      _timedExerciseRemainingSeconds = seconds;
      _isTimedExerciseActive = true;
    });

    _exerciseTimer?.cancel();
    _exerciseTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        if (_timedExerciseRemainingSeconds > 0) {
          _timedExerciseRemainingSeconds--;
        }
        
        if (_timedExerciseRemainingSeconds <= 0) {
          _stopTimedExercise();
          _handleStepContinue(); // Auto-continue when timer reaches 0
        }
      });
    });
  }

  void _stopTimedExercise() {
    _exerciseTimer?.cancel();
    setState(() {
      _isTimedExerciseActive = false;
    });
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
    final connectivityResults = await Connectivity().checkConnectivity();
    if (connectivityResults.contains(ConnectivityResult.none)) {
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
                child: const Text( 'DONE'), 
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
    final tickerController = _tickerControllers[exerciseIdx]!;

    return Stack(
      children: [
        // Background 3D Animation Figure - Enhanced with bigger size and moved up
        Positioned(
          top: -50, // Move animation up
          left: 0,
          right: 0,
          bottom: 100,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black, Color(0xFF1a1a1a)],
              ),
            ),
            child: Center(
              child: Opacity(
                opacity: 0.50, // Slightly more transparent for better text readability
                child: ExerciseAnimationWidget(
                  exerciseName: exercise.name,
                  width: 400, // Increased from 300
                  height: 500, // Increased from 400
                  autoPlay: !_isInRestPeriod && !_isInPreparation,
                  showControls: false,
                  showDescription: false,
                ),
              ),
            ),
          ),
        ),

        // Main Content
        SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(),
              
              // Exercise Info
              Expanded(
                flex: 2,
                child: _buildExerciseInfo(exercise, setNum, totalSets),
              ),
              
              // Circular Weight/Reps Interface
              Expanded(
                flex: 3,
                child: _buildCircularInterface(tickerController, exercise),
              ),
              
              // Next Exercise Info
              _buildNextExerciseInfo(),
              
              // Exercise Thumbnails
              _buildExerciseThumbnails(),
              
              const SizedBox(height: 20),
            ],
          ),
        ),

        // Rest Period Overlay
        if (_isInRestPeriod)
          Container(
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
          ),
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
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Workout',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
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
          _getEquipmentName(exercise),
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 8),
        Flexible(
          child: Text(
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

  Widget _buildCircularInterface(NumberTickerController controller, Exercise exercise) {
    final setNum = _setNumberOfStep[_currentStepIndex];
    final totalSets = _setsTotalInStepOrder[_currentStepIndex];
    
    return Center(
      child: Container(
        width: 280,
        height: 280,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Stack(
          children: [
            // Weight adjustment buttons
            Positioned(
              left: 20,
              top: 120,
              child: GestureDetector(
                onTap: () => _adjustWeight(-0.5),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Colors.white24,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.remove, color: Colors.white),
                ),
              ),
            ),
            Positioned(
              right: 20,
              top: 120,
              child: GestureDetector(
                onTap: () => _adjustWeight(0.5),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Colors.white24,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              ),
            ),
            
            // Center content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Clickable Weight
                  GestureDetector(
                    onTap: () => _showWeightEditDialog(controller),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          NumberTicker(
                            controller: controller,
                            textStyle: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            ' kg',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.edit,
                            color: Colors.white.withOpacity(0.7),
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Reps/Seconds
                  exercise.workoutType == WorkoutType.Timed
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$_timedExerciseRemainingSeconds',
                              style: TextStyle(
                                color: _timedExerciseRemainingSeconds <= 5 
                                    ? Colors.red 
                                    : Colors.white,
                                fontSize: 72,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Text(
                              ' sec',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 24,
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          exercise.reps,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 72,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                  
                  const SizedBox(height: 10),
                  
                  // Sets display
                  Text(
                    'Set $setNum of $totalSets',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  
                  const SizedBox(height: 15),
                  
                  // Done button
                  GestureDetector(
                    onTap: _handleStepContinue,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Done',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
    final nextSetNum = _setNumberOfStep[_currentStepIndex + 1];
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          const Text(
            'Next Exercise:',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Set $nextSetNum',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseThumbnails() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: min(7, _currentExercises.length),
        itemBuilder: (context, index) {
          final isActive = index == _currentStepIndex;
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: isActive ? Colors.white : Colors.white24,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.fitness_center,
              color: isActive ? Colors.black : Colors.white,
              size: 24,
            ),
          );
        },
      ),
    );
  }

  String _getEquipmentName(Exercise exercise) {
    // Extract equipment from exercise name or return default
    if (exercise.name.toLowerCase().contains('barbell')) return 'Barbell';
    if (exercise.name.toLowerCase().contains('dumbbell')) return 'Dumbbell';
    if (exercise.name.toLowerCase().contains('cable')) return 'Cable';
    if (exercise.name.toLowerCase().contains('machine')) return 'Machine';
    return 'Bodyweight';
  }

  void _adjustWeight(double delta) {
    final exerciseIdx = _exerciseIndexesInStepOrder[_currentStepIndex];
    final controller = _tickerControllers[exerciseIdx];
    if (controller != null) {
      if (delta > 0) {
        controller.increment();
      } else if (delta < 0) {
        controller.decrement();
      }
    }
  }

  void _showWeightEditDialog(NumberTickerController controller) {
    final TextEditingController textController = TextEditingController(
      text: controller.number.toString(),
    );
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Weight'),
        content: TextField(
          controller: textController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Weight (kg)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
              onPressed: () {
              final newWeight = double.tryParse(textController.text);
              if (newWeight != null && newWeight >= 0) {
                controller.number = newWeight;
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _handleStepContinue() {
    _stopTimedExercise(); // Stop any running exercise timer
    
    if (_exerciseIndexesInStepOrder.isEmpty || _currentStepIndex >= _exerciseIndexesInStepOrder.length) {
      debugPrint("Cannot continue: Invalid step state.");
      return;
    }

    bool isPersonalRecord = false;
    
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

          // Check for personal record (weight higher than previous best)
          final exercise = _currentExercises[exerciseFlatIndex];

          int actualRepsToRecord = actualReps;
          if (exercise.workoutType == WorkoutType.Timed) {
            // For timed exercises, record actualReps as the duration in seconds (using reps field as seconds)
            actualRepsToRecord = int.tryParse(exercise.reps) ?? actualReps;
          }

          if (exercise.lastUsedWeight != null && actualWeight > exercise.lastUsedWeight!) {
            isPersonalRecord = true;
          }

          final updatedSet = setToUpdate.copyWith(
            actualReps: actualRepsToRecord,
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

    // Trigger animations
    _triggerSetTransition();
    
    if (isPersonalRecord) {
      _showPersonalRecordCelebration();
    }

    setState(() {
      if (_currentStepIndex < _exerciseIndexesInStepOrder.length - 1) {
        _currentStepIndex++; 
        debugPrint('Advanced to step index: $_currentStepIndex');
        
        // Check if we're moving to a new exercise
        final currentExerciseIdx = _exerciseIndexesInStepOrder[_currentStepIndex - 1];
        final nextExerciseIdx = _exerciseIndexesInStepOrder[_currentStepIndex];
        
        if (currentExerciseIdx != nextExerciseIdx) {
          _showExerciseTransition();
          // Start rest period between exercises
          _startRestPeriod(duration: 90); // 90 seconds rest between exercises
        } else {
          // Same exercise, shorter rest between sets
          _startRestPeriod(duration: 60); // 60 seconds rest between sets
        }
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

  // Enhanced Animation Methods
  void _startSetPreparation() {
    if (!mounted) return;
    
    setState(() {
      _isInPreparation = true;
      _preparationTimeRemaining = 3;
    });
    
    _preparationController.forward();
    
    _preparationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      setState(() {
        _preparationTimeRemaining--;
      });
      
      if (_preparationTimeRemaining <= 0) {
        timer.cancel();
        _endSetPreparation();
      }
    });
  }
  
  void _endSetPreparation() {
    if (!mounted) return;
    
    setState(() {
      _isInPreparation = false;
    });
    
    _preparationController.reverse();

    // Start timed exercise if applicable
    if (_currentStepIndex < _exerciseIndexesInStepOrder.length) {
      final exerciseIdx = _exerciseIndexesInStepOrder[_currentStepIndex];
      final exercise = _currentExercises[exerciseIdx];
      if (exercise.workoutType == WorkoutType.Timed) {
        _startTimedExercise(exercise);
      }
    }
  }
  
  void _startRestPeriod({int duration = 60}) {
    if (!mounted) return;
    
    // Cancel any existing rest timer
    _restTimer?.cancel();
    debugPrint('Starting rest period: $duration seconds');
    
    setState(() {
      _isInRestPeriod = true;
      _restTimeRemaining = duration;
    });
    
    _restPeriodController.forward();
    
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      setState(() {
        _restTimeRemaining--;
      });
      
      if (_restTimeRemaining <= 0) {
        timer.cancel();
        _endRestPeriod();
      }
    });
  }
  
  void _endRestPeriod() {
    if (!mounted) return;
    
    debugPrint('Ending rest period');
    _restTimer?.cancel(); // Ensure timer is canceled
    _restTimer = null;
    
    setState(() {
      _isInRestPeriod = false;
    });
    
    _restPeriodController.reverse();
    _startSetPreparation();
  }
  
  void _triggerSetTransition() {
    _setTransitionController.forward().then((_) {
      if (mounted) {
        _setTransitionController.reverse();
      }
    });
  }
  
  void _triggerExerciseTransition() {
    _exerciseTransitionController.forward().then((_) {
      if (mounted) {
        _exerciseTransitionController.reverse();
      }
    });
  }
  
  void _showPersonalRecordCelebration() {
    if (!mounted) return;
    
    setState(() {
      _showingPersonalRecord = true;
    });
    
    _completionController.forward();
    
    // Auto-hide after 3 seconds
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showingPersonalRecord = false;
        });
        _completionController.reverse();
      }
    });
  }
  
  void _showExerciseTransition() {
    if (!mounted) return;
    
    setState(() {
      _showingExerciseTransition = true;
    });
    
    _exerciseTransitionController.forward();
    
    // Auto-hide after 2 seconds
    Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showingExerciseTransition = false;
        });
        _exerciseTransitionController.reverse();
      }
    });
  }
} 

// Static placeholder for SetPerformance to be used in orElse of lastWhere.
// This is used to avoid creating a new instance every time orElse is called.
final SetPerformance _nullPlaceholderSetPerformance = SetPerformance(
  targetReps: 0,
  targetWeight: 0,
  actualReps: 0,
  actualWeight: 0,
  isCompleted: false
);
