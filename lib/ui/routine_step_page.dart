import 'dart:async';
// Needed for potential JSON in history update
import 'dart:math';   // Needed for min() function

import 'package:confetti/confetti.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Import Provider to access BLoC
import 'package:url_launcher/url_launcher.dart';

// Import BLoC, Models, Providers, Utils (adjust paths as necessary)
import 'package:workout_planner/bloc/routines_bloc.dart'; // Your RxDart BLoC
import 'package:workout_planner/bloc/workout_session_bloc.dart'; // Import WorkoutSessionBloc
import 'package:workout_planner/models/workout_session.dart'; // Import WorkoutSession model
import 'package:workout_planner/models/exercise_performance.dart'; // Added import
import 'package:workout_planner/models/set_performance.dart'; // Added import
// Optional custom snackbars
import 'package:workout_planner/utils/routine_helpers.dart'; // For enum ToString converters

import 'components/number_ticker.dart'; // Your NumberTicker component

class RoutineStepPage extends StatefulWidget {
  final Routine originalRoutine; // Pass the original routine
  final VoidCallback? celebrateCallback;
  final VoidCallback? onBackPressed;

  const RoutineStepPage({
    required Routine routine, // Keep constructor name simple
    this.celebrateCallback,
    this.onBackPressed,
    super.key,
  }) : originalRoutine = routine;

  @override
  State<RoutineStepPage> createState() => _RoutineStepPageState();
}

// Define TextStyles (consider moving to a theme file)
final _kLabelTextStyle = TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12);
final _kValueTextStyle = const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold);

class _RoutineStepPageState extends State<RoutineStepPage> with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ConfettiController _confettiController = ConfettiController(duration: const Duration(seconds: 5));
  final Duration _weightChangeTimerDuration = const Duration(milliseconds: 100);

  // --- State Variables ---
  late Routine _currentWorkingRoutine; // Holds the mutable copy for the session state
  late List<Exercise> _currentExercises; // Flattened list from _currentWorkingRoutine for easy access by index
  bool _finished = false; // Tracks if the workout is complete
  // Removed _isModifyingWeight and related timers as weight changes are local to ticker until set completion

  // Stepper logic state - These lists map the linear step index to routine structure
  final List<int> _exerciseIndexesInStepOrder = []; // Index into _currentExercises for each step
  final List<int> _partIndexesInStepOrder = []; // Index into _currentWorkingRoutine.parts for each step
  final List<int> _setsTotalInStepOrder = []; // Total sets for the exercise in this step
  final List<int> _setNumberOfStep = [];      // Which set number this step represents (1-based)
  int _currentStepIndex = 0; // Current position in the step sequence

  WorkoutSession? _activeWorkoutSession; // To store the current session being performed

  // Controllers for weight tickers - manage dynamically based on exercises
  Map<int, NumberTickerController> _tickerControllers = {}; // Map exercise index to its ticker controller

  @override
  void initState() {
    super.initState();
    // --- Create a deep, mutable copy of the routine for this session ---
    _currentWorkingRoutine = widget.originalRoutine.copyWith(
      // Deep copy the parts list
      parts: widget.originalRoutine.parts.map((originalPart) {
        // Deep copy each part, including its exercises list
        return originalPart.copyWith(
          // Deep copy the exercises list within the part
          exercises: originalPart.exercises.map((originalExercise) {
            // Deep copy each exercise (Exercise.copyWith handles history map copy)
            return originalExercise.copyWith();
          }).toList(), // Collect copied exercises into a new list for the part
        );
      }).toList(), // Collect copied parts into a new list for the routine
      // Deep copy other mutable lists if they exist and might change (e.g., history?)
      // routineHistory: List<int>.from(widget.originalRoutine.routineHistory),
    );
    // --- End Deep Copy ---

    // Initialize the step sequence and ticker controllers based on the copied routine
    _rebuildStateFromRoutine();

    // Start a new WorkoutSession instance for this workout attempt
    // _currentWorkingRoutine is the one with potentially modified exercise weights during the session
    // widget.originalRoutine is the pristine template.
    // For WorkoutSession, we link it to the original routine template.
    _activeWorkoutSession = WorkoutSession.startNew(routine: widget.originalRoutine);
    debugPrint("RoutineStepPage: Initialized _activeWorkoutSession with ID: ${_activeWorkoutSession?.id}");
  }

  /// Initializes or resets the internal state lists (_currentExercises, step indexes, tickers)
  /// based on the current state of _currentWorkingRoutine.
  void _rebuildStateFromRoutine() {
    // Clear existing derived state
    _currentExercises = _currentWorkingRoutine.parts.expand((p) => p.exercises).toList();
    _exerciseIndexesInStepOrder.clear();
    _partIndexesInStepOrder.clear();
    _setsTotalInStepOrder.clear();
    _setNumberOfStep.clear();
    _disposeTickerControllers(); // Dispose old controllers before replacing map
    _tickerControllers = {}; // Reset controllers map

    int exerciseCounter = 0; // Tracks index in the flattened _currentExercises list

    // Iterate through parts of the working routine copy
    for (int partIdx = 0; partIdx < _currentWorkingRoutine.parts.length; partIdx++) {
      final part = _currentWorkingRoutine.parts[partIdx];
      if (part.exercises.isEmpty) continue; // Skip parts with no exercises

      // Determine how many exercises form a single "step" based on SetType
      int exercisesInThisSetGroup = 1;
      switch (part.setType) {
        case SetType.Super: exercisesInThisSetGroup = 2; break;
        case SetType.Tri:   exercisesInThisSetGroup = 3; break;
        case SetType.Giant: exercisesInThisSetGroup = 4; break;
        case SetType.Regular:
        case SetType.Drop:
        default: exercisesInThisSetGroup = 1; break;
      }

      // Ensure we don't try to use more exercises than available in the part
      exercisesInThisSetGroup = min(exercisesInThisSetGroup, part.exercises.length);
      if (exercisesInThisSetGroup == 0) continue;

      // Get total sets (assuming all exercises in a composite set have the same count)
      // Use the first exercise in the part for this. Handle potential errors.
      final totalSets = part.exercises.first.sets;
      if (totalSets <= 0) continue; // Skip parts with 0 sets defined

      // Generate the step sequence for this part
      for (int setNum = 1; setNum <= totalSets; setNum++) { // Iterate through sets (1-based)
        for (int i = 0; i < exercisesInThisSetGroup; i++) { // Iterate through exercises within the set group
          final currentExerciseFlatIndex = exerciseCounter + i; // Index in _currentExercises

          // Safety check: ensure index is within bounds of the flattened list
          if (currentExerciseFlatIndex < _currentExercises.length) {
            // Add mapping info for this step
            _exerciseIndexesInStepOrder.add(currentExerciseFlatIndex);
            _partIndexesInStepOrder.add(partIdx);
            _setsTotalInStepOrder.add(totalSets);
            _setNumberOfStep.add(setNum);

            // Initialize a NumberTickerController for this exercise if it doesn't exist yet
            if (!_tickerControllers.containsKey(currentExerciseFlatIndex)) {
              _tickerControllers[currentExerciseFlatIndex] = NumberTickerController(
                  initial: _currentExercises[currentExerciseFlatIndex].weight, // Use initial weight from model
                  step: 0.5, // Default weight step (adjust as needed)
                  minValue: 0  // Default min weight
              );
            }
          } else {
            debugPrint("Warning: Exercise index ($currentExerciseFlatIndex) out of bounds during step generation.");
          }
        }
      }
      // Advance the counter past the exercises used in this part
      exerciseCounter += exercisesInThisSetGroup;
    }
    debugPrint("Generated ${_exerciseIndexesInStepOrder.length} total steps for the workout.");
  }


  @override
  void dispose() {
    // Dispose controllers
    _confettiController.dispose();
    _disposeTickerControllers();
    super.dispose();
  }

  /// Safely disposes all created NumberTickerControllers.
  void _disposeTickerControllers() {
    for (var controller in _tickerControllers.values) {
      try {
        controller.dispose();
      } catch (e) {
        debugPrint("Error disposing NumberTickerController: $e");
      }
    }
  }

  // --- Utilities ---

  /// Formats DateTime to 'YYYY-MM-DD' string. (Defined locally)
  String _dateTimeToString(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  /// Checks internet connectivity. Returns true if connected, false otherwise.
  /// Shows a snackbar on failure using the local _showSnackBar helper.
  Future<bool> _checkConnection() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      if (!mounted) return false;
      _showSnackBar('No Internet Connection', isError: true); // Use local helper
      return false;
    }
    return true;
  }

  /// Shows a simple SnackBar message. Defined locally.
  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return; // Check if the widget is still mounted
    ScaffoldMessenger.of(context).removeCurrentSnackBar(); // Remove previous snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.redAccent : null, // Optional error color
          duration: const Duration(seconds: 3) // Longer duration for errors?
      ),
    );
  }

  // --- Build Methods ---

  @override
  Widget build(BuildContext context) {
    // Determine title based on current step, handle edge cases
    String title = 'Workout'; // Default title
    if (!_finished && _currentStepIndex < _exerciseIndexesInStepOrder.length) {
      final currentPartIdx = _partIndexesInStepOrder[_currentStepIndex];
      // Safety check for part index
      if (currentPartIdx >= 0 && currentPartIdx < _currentWorkingRoutine.parts.length) {
        final currentPart = _currentWorkingRoutine.parts[currentPartIdx];
        // Ensure helper functions are imported/available
        try {
          final bodyPartStr = targetedBodyPartToStringConverter(currentPart.targetedBodyPart);
          final setTypeStr = setTypeToStringConverter(currentPart.setType);
          title = '$bodyPartStr - $setTypeStr';
        } catch (e) {
          debugPrint("Error converting enum to string for title: $e");
          // Keep default title on error
        }
      }
    } else if (_finished) {
      title = 'Finished!';
    }

    final totalSteps = _exerciseIndexesInStepOrder.length;
    // Calculate progress, show 100% when finished
    final progress = totalSteps == 0 ? 0.0 : ((_currentStepIndex + (_finished ? 1: 0)) / totalSteps);

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        key: _scaffoldKey, // Keep key if needed for Scaffold operations
        appBar: AppBar(
          title: Text(title, style: const TextStyle(color: Colors.white70, fontSize: 16)),
          // Progress indicator in AppBar bottom
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4.0),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0), // Ensure value is between 0 and 1
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.deepOrangeAccent),
            ),
          ),
          backgroundColor: Theme.of(context).primaryColor,
          iconTheme: const IconThemeData(color: Colors.white), // Back button color
        ),
        backgroundColor: Theme.of(context).primaryColor, // Background for stepper area
        body: _finished ? _buildFinishedScreen() : _buildStepper(),
      ),
    );
  }

  Widget _buildFinishedScreen() {
    // Finished screen with confetti and DONE button
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF4A00E0), Color(0xFF8E2DE2)], // Example purple gradient
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Confetti Layer
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              maxBlastForce: 10, minBlastForce: 5,
              emissionFrequency: 0.04, numberOfParticles: 15,
              gravity: 0.1,
              colors: const [ // Required 'colors' parameter
                Colors.greenAccent, Colors.blueAccent, Colors.pinkAccent,
                Colors.orangeAccent, Colors.purpleAccent, Colors.yellowAccent
              ],
            ),
          ),
          // Content Layer
          Column(
            mainAxisAlignment: MainAxisAlignment.center, // Center vertically
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text( 'Workout Complete! 🎉',
                textAlign: TextAlign.center,
                style: TextStyle( fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white, ),
              ),
              const SizedBox(height: 20),
              const Icon(Icons.emoji_events_outlined, size: 80, color: Colors.amber), // Trophy icon
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context); // Go back to previous screen
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  shape: RoundedRectangleBorder( borderRadius: BorderRadius.circular(30), ),
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF4A00E0), // Match gradient start
                ),
                child: const Text( 'DONE', style: TextStyle( fontSize: 18, fontWeight: FontWeight.bold, ), ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepper() {
    // Guard clauses for empty/invalid state
    if (_exerciseIndexesInStepOrder.isEmpty) {
      return const Center(child: Text("No steps generated for this routine.", style: TextStyle(color: Colors.white70)));
    }
    if (_currentStepIndex >= _exerciseIndexesInStepOrder.length) {
      return const Center(child: Text("Workout progression error.", style: TextStyle(color: Colors.red)));
    }

    // Use a ListView to allow content scrolling if needed, especially step content
    return ListView(
      physics: const ClampingScrollPhysics(), // Good default for step-like content
      children: [
        Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Colors.deepOrangeAccent, // Active step color
              onSurface: Colors.white,          // Step title color etc.
              surface: Theme.of(context).primaryColor, // Background of step content
            ),
            dividerColor: Colors.white24,
          ),
          child: Stepper(
            physics: const NeverScrollableScrollPhysics(), // Stepper itself shouldn't scroll
            type: StepperType.vertical,
            currentStep: _currentStepIndex,
            onStepTapped: null, // Prevent user from jumping steps
            onStepCancel: null, // No cancel button
            onStepContinue: _handleStepContinue, // Next button action
            controlsBuilder: (BuildContext context, ControlsDetails details) {
              // Custom controls (just the NEXT button centered)
              return Padding(
                padding: const EdgeInsets.only(top: 24.0, bottom: 16.0), // More spacing
                child: Center(
                  child: ElevatedButton(
                    onPressed: details.onStepContinue, // Always enabled, weight changes are local to ticker
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrangeAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 12),
                        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                    ),
                    child: const Text('NEXT SET'),
                  ),
                ),
              );
            },
            steps: List.generate(_exerciseIndexesInStepOrder.length, (stepIdx) {
              // Generate each Step widget
              final exerciseIdx = _exerciseIndexesInStepOrder[stepIdx];
              final partIdx = _partIndexesInStepOrder[stepIdx];
              final setNum = _setNumberOfStep[stepIdx];
              final totalSets = _setsTotalInStepOrder[stepIdx];

              // Safety check for exercise index
              if (exerciseIdx >= _currentExercises.length) {
                return const Step(title: Text("Error: Invalid Exercise Index"), content: SizedBox());
              }
              final exercise = _currentExercises[exerciseIdx];

              final isActive = stepIdx == _currentStepIndex;
              final isCompleted = stepIdx < _currentStepIndex;

              String stepTitle = "${exercise.name} (Set $setNum of $totalSets)";

              return Step(
                title: Text(
                  stepTitle,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    color: isActive ? Colors.white : (isCompleted ? Colors.white54 : Colors.white70),
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                    decorationColor: Colors.white54,
                  ),
                ),
                // Show content ONLY for the active step to avoid building too many tickers
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

  /// Builds the content area for the currently active step.
  Widget _buildStepContent(int exerciseIndex) {
    // ... (Guard clause and controller fetching remain the same) ...
    if (!_tickerControllers.containsKey(exerciseIndex)) { /* ... Error handling ... */ }
    final exercise = _currentExercises[exerciseIndex];
    final tickerController = _tickerControllers[exerciseIndex]!;
    final setNum = _setNumberOfStep[_currentStepIndex];
    final totalSets = _setsTotalInStepOrder[_currentStepIndex];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
      child: Column(
        children: [
          // Weight Controls Row
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
                      // *** FIX: Removed const here ***
                      Text("WEIGHT (kg)", style: _kLabelTextStyle),
                      const SizedBox(height: 4),
                      NumberTicker(
                        controller: tickerController,
                        // ... other NumberTicker params ...
                        textStyle: const TextStyle( // Can be const if values are constant
                            color: Colors.white, fontSize: 56,
                            fontWeight: FontWeight.bold, fontFamily: 'RobotoMono'
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _buildWeightButton(Icons.add, tickerController),
            ],
          ),
          const SizedBox(height: 24), // Spacer

          // Reps and Set Info Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildInfoColumn("SET", "$setNum / $totalSets"),
              _buildInfoColumn(
                  exercise.workoutType == WorkoutType.Cardio ? "TIME (sec)" : "REPS",
                  exercise.reps
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Exercise Info Button
          TextButton.icon(
            icon: const Icon(Icons.info_outline, color: Colors.white70, size: 18),
            label: const Text("Exercise Info", style: TextStyle(color: Colors.white70, fontSize: 14)),
            onPressed: () => _launchURL(exercise.name),
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
          ),
        ],
      ),
    );
  }

// Helper for building info columns (Set, Reps)
// Make style non-const if needed, but here it might be okay if _kLabelTextStyle is fixed
  Widget _buildInfoColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // *** FIX: Removed const here ***
        Text(label, style: _kLabelTextStyle),
        const SizedBox(height: 4),
        // _kValueTextStyle can be const if defined with const values
        Text(value, style: _kValueTextStyle),
      ],
    );
  }

// ... (Rest of the _RoutineStepPageState class remains the same) ...

  /// Builds a weight adjustment button.
  Widget _buildWeightButton(IconData icon, NumberTickerController controller) {
    VoidCallback action;
    if (icon == Icons.add) {
      action = controller.increment; // Directly call controller method
    } else {
      action = controller.decrement; // Directly call controller method
    }

    return ElevatedButton(
      onPressed: action, // Simple tap action
      style: ElevatedButton.styleFrom(
        shape: const CircleBorder(),
        padding: const EdgeInsets.all(16),
        backgroundColor: Colors.white.withOpacity(0.2),
        foregroundColor: Colors.white,
      ),
      child: Icon(icon, size: 28),
    );
  }

  // --- State Update Logic (Removed _updateExerciseWeight, _increaseWeight, _decreaseWeight, _cancelTimers) ---
  // Weight is now managed locally by the NumberTickerController until the set is completed.

  // --- Step Navigation and Completion ---

  /// Handles moving to the next step or finishing the workout.
  void _handleStepContinue() {
    if (_exerciseIndexesInStepOrder.isEmpty || _currentStepIndex >= _exerciseIndexesInStepOrder.length) {
      debugPrint("Cannot continue: Invalid step state.");
      return;
    }

    // --- Update _activeWorkoutSession with completed set data ---
    if (_activeWorkoutSession != null) {
      final int exerciseFlatIndex = _exerciseIndexesInStepOrder[_currentStepIndex];
      final int setNumber = _setNumberOfStep[_currentStepIndex]; // 1-based set number
      final int setIndex = setNumber - 1; // 0-based index for list access

      // Find the corresponding ExercisePerformance in _activeWorkoutSession
      // This assumes the order in _activeWorkoutSession.exercises matches the flattened order used for steps.
      if (exerciseFlatIndex < _activeWorkoutSession!.exercises.length) {
        final ExercisePerformance currentExercisePerf = _activeWorkoutSession!.exercises[exerciseFlatIndex];

        // Ensure the set index is valid
        if (setIndex >= 0 && setIndex < currentExercisePerf.sets.length) {
          final SetPerformance setToUpdate = currentExercisePerf.sets[setIndex];

          // Get actual weight from the ticker controller
          final NumberTickerController? tickerController = _tickerControllers[exerciseFlatIndex];
          final double actualWeight = tickerController?.number ?? setToUpdate.targetWeight; // Fallback to target weight if controller missing

          // Get actual reps (assuming target reps for now, needs input field later)
          // TODO: Replace this with actual reps input from user
          final int actualReps = setToUpdate.targetReps; // Placeholder

          // Create the updated SetPerformance
          final updatedSet = setToUpdate.copyWith(
            actualReps: actualReps,
            actualWeight: actualWeight,
            isCompleted: true,
          );

          // Create updated list of sets for the exercise performance
          final updatedSetsList = List<SetPerformance>.from(currentExercisePerf.sets);
          updatedSetsList[setIndex] = updatedSet;

          // Create updated ExercisePerformance
          final updatedExercisePerf = currentExercisePerf.copyWith(sets: updatedSetsList);

          // Create updated list of exercises for the session
          final updatedSessionExercises = List<ExercisePerformance>.from(_activeWorkoutSession!.exercises);
          updatedSessionExercises[exerciseFlatIndex] = updatedExercisePerf;

          // Update the _activeWorkoutSession state variable
          // No need for setState here if we only use _activeWorkoutSession when finishing
          _activeWorkoutSession = _activeWorkoutSession!.copyWith(exercises: updatedSessionExercises);
          debugPrint("Updated _activeWorkoutSession for Exercise: ${updatedExercisePerf.exerciseName}, Set: ${setNumber}, Weight: $actualWeight, Reps: $actualReps");

        } else {
          debugPrint("Error: Invalid set index ($setIndex) for ExercisePerformance '${currentExercisePerf.exerciseName}'.");
        }
      } else {
        debugPrint("Error: Invalid exercise index ($exerciseFlatIndex) for _activeWorkoutSession.");
      }
    } else {
      debugPrint("Error: _activeWorkoutSession is null in _handleStepContinue.");
    }
    // --- End _activeWorkoutSession update ---


    // Update UI state to move to the next step or finish
    setState(() {
      if (_currentStepIndex < _exerciseIndexesInStepOrder.length - 1) {
        _currentStepIndex++; // Increment step index
        debugPrint('Advanced to step index: $_currentStepIndex');
      } else {
        _finishWorkout(); // Trigger finish logic
      }
    });
  }

  // Removed _updateExHistoryForCurrentStep method as it's no longer used for performance tracking

  /// Finalizes the workout, updates the routine state, and calls the BLoC.
  void _finishWorkout() {
    debugPrint('Routine completed! Preparing final routine state...');
    // Set UI flag first to trigger screen change
    setState(() => _finished = true);
    _confettiController.play(); // Start confetti
    widget.celebrateCallback?.call(); // Call external callback

    // Create the final immutable Routine object with updated completion stats
    // Use widget.originalRoutine as the base, as _currentWorkingRoutine might have temporary weight changes
    final finalRoutine = widget.originalRoutine.copyWith(
      completionCount: widget.originalRoutine.completionCount + 1,
      lastCompletedDate: DateTime.now(),
      // Update routineHistory on the original routine template
      routineHistory: List<int>.from(widget.originalRoutine.routineHistory)..add(DateTime.now().millisecondsSinceEpoch),
    );

    // Update the routine template in the persistent storage via the BLoC
    try {
      context.read<RoutinesBloc>().updateRoutine(finalRoutine);
      debugPrint("Final routine update sent to BLoC.");

      // Now, save the completed WorkoutSession (which should have updated performance data)
      if (_activeWorkoutSession != null) {
        final finishedSessionForDb = _activeWorkoutSession!.copyWith(
          isCompleted: true,
          endTime: finalRoutine.lastCompletedDate, // Use same timestamp for consistency
          // The 'exercises' list in _activeWorkoutSession should now contain the actual performance data
        );
        context.read<WorkoutSessionBloc>().add(WorkoutSessionSaveCompleted(finishedSessionForDb));
        debugPrint("WorkoutSessionSaveCompleted event added to WorkoutSessionBloc for session ID: ${finishedSessionForDb.id}.");
      } else {
        debugPrint("Error: _activeWorkoutSession was null in _finishWorkout. Cannot save WorkoutSession.");
        _showSnackBar("Critical Error: Could not record session details.", isError: true);
      }

    } catch(e) {
      debugPrint("Error updating routine or session in BLoC after finish: $e");
      _showSnackBar("Error saving final workout state.", isError: true);
    }
  }

  // --- Navigation and External Actions ---

  /// Handles the back button press, showing a confirmation dialog.
  Future<bool> _onWillPop() async {
    if (_finished) return true; // Allow back navigation if workout is already finished

    // Show confirmation dialog
    final shouldQuit = await showDialog<bool>(
      context: context, // Provide context
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog( // Use builder
        title: const Text('Quit Workout?'),
        content: const Text('Your progress for this session will not be saved if you quit now.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false), // Stay, return false
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () {
              // _cancelTimers(); // No longer needed
              Navigator.pop(dialogContext, true); // Quit, return true
            },
            child: const Text('Quit Workout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ?? false; // Default to false if dialog is dismissed by tapping outside (if barrierDismissible were true)

    // If user confirmed quit, call the optional onBackPressed callback
    if (shouldQuit) {
      widget.onBackPressed?.call();
    }
    return shouldQuit; // Let WillPopScope know whether to pop the route
  }

  /// Launches a URL to search for exercise information.
  Future<void> _launchURL(String exerciseName) async {
    if (exerciseName.trim().isEmpty) return;
    if (!await _checkConnection()) return; // Use connection check helper

    // Sanitize and encode exercise name for URL query
    final query = Uri.encodeComponent(exerciseName.trim());
    // Example URL using Bodybuilding.com search
    final url = Uri.parse('https://www.bodybuilding.com/exercises/search?query=$query');

    try {
      if (await canLaunchUrl(url)) {
        // Launch in external browser for better user experience usually
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        debugPrint("Could not launch $url");
        _showSnackBar("Could not open exercise info link."); // Use helper
      }
    } catch (e) {
      debugPrint("Error launching URL $url: $e");
      _showSnackBar("Could not open exercise info link."); // Use helper
    }
  }

} // End of _RoutineStepPageState
