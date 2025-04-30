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
  bool _isModifyingWeight = false; // Tracks if +/- button is being held down

  Timer? _incrementTimer; // Timer for continuous weight increase
  Timer? _decrementTimer; // Timer for continuous weight decrease

  // Stepper logic state - These lists map the linear step index to routine structure
  final List<int> _exerciseIndexesInStepOrder = []; // Index into _currentExercises for each step
  final List<int> _partIndexesInStepOrder = []; // Index into _currentWorkingRoutine.parts for each step
  final List<int> _setsTotalInStepOrder = []; // Total sets for the exercise in this step
  final List<int> _setNumberOfStep = [];      // Which set number this step represents (1-based)
  int _currentStepIndex = 0; // Current position in the step sequence

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
    // Cancel any active timers
    _incrementTimer?.cancel();
    _decrementTimer?.cancel();
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
                    onPressed: _isModifyingWeight ? null : details.onStepContinue, // Disable while holding +/-
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
              _buildWeightButton(Icons.remove, tickerController, exerciseIndex),
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
              _buildWeightButton(Icons.add, tickerController, exerciseIndex),
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

  /// Builds a weight adjustment button wrapped in GestureDetector for long press.
  Widget _buildWeightButton(IconData icon, NumberTickerController controller, int exerciseIndex) {
    // Determine actions based on icon
    VoidCallback simpleAction; // Action for single tap
    VoidCallback timerAction;  // Action for long press start
    if (icon == Icons.add) {
      // Increment weight by controller's step value
      simpleAction = () => _updateExerciseWeight(exerciseIndex, controller.number + controller.step);
      timerAction = () => _increaseWeight(controller, exerciseIndex);
    } else {
      // Decrement weight by controller's step value
      simpleAction = () => _updateExerciseWeight(exerciseIndex, controller.number - controller.step);
      timerAction = () => _decreaseWeight(controller, exerciseIndex);
    }

    // Use GestureDetector to capture long presses
    return GestureDetector(
      onLongPressStart: (_) {
        // Prevent starting multiple timers if already modifying
        if (_isModifyingWeight) return;
        setState(() => _isModifyingWeight = true);
        timerAction(); // Start the continuous weight change timer
      },
      onLongPressEnd: (_) => _cancelTimers(), // Stop timers when long press released
      onTapUp: (_) => _cancelTimers(), // Also cancel if tap released quickly
      onTapCancel: () => _cancelTimers(), // Cancel if gesture is interrupted
      child: ElevatedButton(
        // *** ElevatedButton does NOT have long press handlers ***
        onPressed: () { // Handle single tap
          if (!_isModifyingWeight) { // Only trigger if not currently long-pressing
            simpleAction();
          }
        },
        style: ElevatedButton.styleFrom(
          shape: const CircleBorder(),
          padding: const EdgeInsets.all(16),
          backgroundColor: Colors.white.withOpacity(0.2),
          foregroundColor: Colors.white,
        ),
        child: Icon(icon, size: 28),
      ),
    );
  }


  // --- State Update Logic (Using copyWith for Immutability) ---

  /// Updates the weight for a specific exercise in the state immutably.
  void _updateExerciseWeight(int exerciseIndex, double newWeight) {
    if (exerciseIndex < 0 || exerciseIndex >= _currentExercises.length) {
      debugPrint("Error: Invalid exerciseIndex $exerciseIndex in _updateExerciseWeight");
      return;
    }

    // Get the controller to access clamp values
    final NumberTickerController controller = _tickerControllers[exerciseIndex]!;
    final clampedWeight = newWeight.clamp(controller.minValue, controller.maxValue ?? double.infinity);

    // Only proceed if the clamped value is different from the current weight
    if (_currentExercises[exerciseIndex].weight == clampedWeight) return;

    // Update the controller's value first so the ticker reflects the change
    // Use .value setter which should handle notification if implemented correctly
    controller.value = clampedWeight;

    // Create new immutable list of exercises with the updated weight
    final updatedExercisesList = List<Exercise>.from(_currentExercises);
    final originalExercise = updatedExercisesList[exerciseIndex];
    updatedExercisesList[exerciseIndex] = originalExercise.copyWith(weight: clampedWeight);

    // ---- Update the nested _currentWorkingRoutine state ----
    // This is complex because we need to find the exercise within the nested parts structure.
    // We map through parts, then exercises within parts, replacing the specific one.
    int exerciseCounter = 0;
    bool partWasUpdated = false; // Flag to potentially optimize mapping
    final updatedPartsList = _currentWorkingRoutine.parts.map((part) {
      // If we already found and updated the part containing the exercise, return original part
      if (partWasUpdated) return part;

      int startIndex = exerciseCounter;
      int endIndex = exerciseCounter + part.exercises.length;
      exerciseCounter = endIndex; // Update counter for next part

      // Check if the target exercise index falls within this part's range
      if (exerciseIndex >= startIndex && exerciseIndex < endIndex) {
        int indexWithinPart = exerciseIndex - startIndex; // Calculate index *within* this part

        // Create a new list of exercises for this part
        final updatedPartExercises = List<Exercise>.from(part.exercises);
        // Replace the specific exercise with the updated one from updatedExercisesList
        updatedPartExercises[indexWithinPart] = updatedExercisesList[exerciseIndex];
        partWasUpdated = true; // Mark that we found and updated the part

        // Return a new Part object with the updated exercises list
        return part.copyWith(exercises: updatedPartExercises);
      } else {
        // This part does not contain the exercise, return the original part
        return part;
      }
    }).toList();
    // ---- End nested update ----


    // Update the page state with the new routine and flattened exercise list
    setState(() {
      _currentWorkingRoutine = _currentWorkingRoutine.copyWith(parts: updatedPartsList);
      _currentExercises = updatedExercisesList; // Keep flattened list in sync
    });
  }

  /// Starts timer to continuously increase weight.
  void _increaseWeight(NumberTickerController controller, int exerciseIndex) {
    _decrementTimer?.cancel(); _decrementTimer = null; // Stop opposite timer
    // Start timer only if not already running
    if (_incrementTimer == null || !_incrementTimer!.isActive) {
      _incrementTimer = Timer.periodic(_weightChangeTimerDuration, (_) {
        controller.increment(); // Use controller's method (handles step/max)
        _updateExerciseWeight(exerciseIndex, controller.number); // Update state with new value
      });
    }
  }

  /// Starts timer to continuously decrease weight.
  void _decreaseWeight(NumberTickerController controller, int exerciseIndex) {
    _incrementTimer?.cancel(); _incrementTimer = null; // Stop opposite timer
    // Start timer only if not already running
    if (_decrementTimer == null || !_decrementTimer!.isActive) {
      _decrementTimer = Timer.periodic(_weightChangeTimerDuration, (_) {
        controller.decrement(); // Use controller's method (handles step/min)
        _updateExerciseWeight(exerciseIndex, controller.number); // Update state with new value
      });
    }
  }

  /// Cancels both weight change timers and resets the modification flag.
  void _cancelTimers() {
    _incrementTimer?.cancel();
    _incrementTimer = null;
    _decrementTimer?.cancel();
    _decrementTimer = null;
    // Only call setState if the flag actually needs changing
    if (_isModifyingWeight) {
      setState(() => _isModifyingWeight = false);
    }
  }

  // --- Step Navigation and Completion ---

  /// Handles moving to the next step or finishing the workout.
  void _handleStepContinue() {
    if (_exerciseIndexesInStepOrder.isEmpty || _currentStepIndex >= _exerciseIndexesInStepOrder.length) {
      debugPrint("Cannot continue: Invalid step state.");
      return;
    }

    // Record history for the step *just completed*
    _updateExHistoryForCurrentStep();

    // Update state to move to the next step or finish
    setState(() {
      if (_currentStepIndex < _exerciseIndexesInStepOrder.length - 1) {
        _currentStepIndex++; // Increment step index
        debugPrint('Advanced to step index: $_currentStepIndex');
        // Future enhancement: Scroll the stepper/list to show the new active step
      } else {
        _finishWorkout(); // Trigger finish logic
      }
    });
  }

  /// Records the weight used for the current step in the exercise history map
  /// within the immutable `_currentWorkingRoutine`.
  void _updateExHistoryForCurrentStep() {
    if (_currentStepIndex >= _exerciseIndexesInStepOrder.length) return; // Safety check

    final String tempDateStr = _dateTimeToString(DateTime.now());
    final int exerciseIdx = _exerciseIndexesInStepOrder[_currentStepIndex]; // Index in flattened list
    final int partIdx = _partIndexesInStepOrder[_currentStepIndex]; // Index in parts list

    // Safety checks for indices
    if (partIdx >= _currentWorkingRoutine.parts.length || exerciseIdx >= _currentExercises.length) {
      debugPrint("Error updating history: Invalid part or exercise index.");
      return;
    }

    // Need to find the correct exercise *within the nested part structure*
    // to update its history immutably.
    final targetPart = _currentWorkingRoutine.parts[partIdx];
    final exerciseBeingCompleted = _currentExercises[exerciseIdx]; // Get the potentially modified exercise state

    // Find the index of this exercise *within the part's own exercise list*
    // Matching by reference might work if _currentExercises contains exact refs from the nested copy
    // Otherwise, match by a unique property like name (assuming names are unique within a part)
    int indexWithinPart = targetPart.exercises.indexWhere((ex) => ex == exerciseBeingCompleted);
    if (indexWithinPart == -1) {
      // Fallback to name matching if reference matching failed
      indexWithinPart = targetPart.exercises.indexWhere((ex) => ex.name == exerciseBeingCompleted.name);
    }


    if (indexWithinPart == -1) {
      debugPrint("Could not find exercise index $exerciseIdx ('${exerciseBeingCompleted.name}') within part $partIdx for history update.");
      return; // Cannot update history if exercise isn't found correctly
    }

    final originalExerciseInPart = targetPart.exercises[indexWithinPart]; // Get the corresponding exercise in the structure
    final currentWeight = exerciseBeingCompleted.weight; // Use the current weight value

    // Create an updated history map based on the original exercise's history
    final updatedHistory = Map<String, dynamic>.from(originalExerciseInPart.exHistory);
    updatedHistory.update(
      tempDateStr,
          (value) => '$value/${StringHelper.weightToString(currentWeight)}', // Append weight (use helper for formatting)
      ifAbsent: () => StringHelper.weightToString(currentWeight), // Add first weight entry (use helper)
    );

    // Create new Exercise instance with updated history
    final updatedExerciseInPart = originalExerciseInPart.copyWith(exHistory: updatedHistory);

    // Create new list of exercises for the part
    final updatedPartExercises = List<Exercise>.from(targetPart.exercises);
    updatedPartExercises[indexWithinPart] = updatedExerciseInPart;

    // Create new Part instance
    final updatedPart = targetPart.copyWith(exercises: updatedPartExercises);

    // Create new list of parts for the routine
    final updatedPartsList = List<Part>.from(_currentWorkingRoutine.parts);
    updatedPartsList[partIdx] = updatedPart;

    // Update the main working routine state variable.
    // **Crucially, DO NOT call setState here**, as this update happens *before*
    // the setState call in _handleStepContinue moves to the next step.
    // This ensures the history is recorded based on the state *before* moving on.
    _currentWorkingRoutine = _currentWorkingRoutine.copyWith(parts: updatedPartsList);
  }

  /// Finalizes the workout, updates the routine state, and calls the BLoC.
  void _finishWorkout() {
    debugPrint('Routine completed! Preparing final routine state...');
    // Set UI flag first to trigger screen change
    setState(() => _finished = true);
    _confettiController.play(); // Start confetti
    widget.celebrateCallback?.call(); // Call external callback

    // Create the final immutable Routine object with updated completion stats
    final finalRoutine = _currentWorkingRoutine.copyWith(
      completionCount: _currentWorkingRoutine.completionCount + 1,
      lastCompletedDate: DateTime.now(),
      // Assuming routineHistory (list of timestamps) is updated elsewhere or not needed here
      // routineHistory: List<int>.from(_currentWorkingRoutine.routineHistory)..add(getTimestampNow()),
    );

    // Update the routine in the persistent storage via the BLoC
    try {
      // Access BLoC using Provider context extension
      context.read<RoutinesBloc>().updateRoutine(finalRoutine);
      debugPrint("Final routine update sent to BLoC.");
    } catch(e) {
      debugPrint("Error updating routine in BLoC after finish: $e");
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
              _cancelTimers(); // Ensure timers are stopped if quitting
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