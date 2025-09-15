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
import 'package:workout_planner/services/exercise_coaching_service.dart';
import 'package:workout_planner/models/targeted_body_part.dart';
import 'package:workout_planner/services/ai_weight_recommendation_service.dart';
import 'package:workout_planner/resource/shared_prefs_provider.dart';
import 'package:workout_planner/models/user_profile.dart';
import 'package:workout_planner/services/ai_rep_time_recommendation_service.dart';

import 'components/number_ticker.dart';

class RoutineStepPageV2 extends StatefulWidget {
  final Routine originalRoutine;
  final WorkoutSession? resumeSession;
  final VoidCallback? celebrateCallback;
  final VoidCallback? onBackPressed;

  const RoutineStepPageV2({
    required Routine routine,
    this.resumeSession,
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

    // Use resume session's routine if provided
    final baseRoutine = widget.resumeSession?.routine ?? widget.originalRoutine;
    _currentWorkingRoutine = baseRoutine.copyWith(
      parts: widget.originalRoutine.parts.map((originalPart) {
        return originalPart.copyWith(
          exercises: originalPart.exercises.map((originalExercise) {
            return originalExercise.copyWith();
          }).toList(),
        );
      }).toList(),
    );

    _rebuildStateFromRoutine();

    if (widget.resumeSession != null) {
      _activeWorkoutSession = widget.resumeSession;
      // Compute how many sets are already completed to position the cursor
      int completedSets = 0;
      try {
        for (final ex in widget.resumeSession!.exercises) {
          for (final set in ex.sets) {
            if (set.isCompleted) completedSets++;
          }
        }
      } catch (_) {}
      if (_exerciseIndexesInStepOrder.isNotEmpty) {
        _currentStepIndex = completedSets.clamp(0, _exerciseIndexesInStepOrder.length - 1);
      }
      debugPrint("RoutineStepPageV2: Resuming session ${_activeWorkoutSession!.id}, completed sets=$completedSets, stepIndex=$_currentStepIndex");
    } else {
      _activeWorkoutSession = WorkoutSession.startNew(routine: widget.originalRoutine);
      debugPrint("RoutineStepPageV2: Starting new session ${_activeWorkoutSession?.id}");
    }

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
              _buildSafetyBanner(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 8),
                      _buildExerciseInfo(exercise, setNum, totalSets),
                      const SizedBox(height: 8),
                      _buildTypeAndRestChips(exercise, totalSets),
                      const SizedBox(height: 8),
                      _buildInlineCoaching(exercise, setNum, totalSets),
                      const SizedBox(height: 12),
                      _buildInputControls(weightController, repsController, exercise),
                      const SizedBox(height: 12),
                      _buildActionButtons(),
                      const SizedBox(height: 8),
                      _buildNextExerciseInfo(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_isInRestPeriod) _buildRestPeriodOverlay(),
        if (_isTimedExerciseActive) _timedOverlay(),
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

  Widget _buildSafetyBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
        ),
        child: Row(
          children: const [
            Icon(Icons.health_and_safety, color: Colors.redAccent, size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Coaching is educational only — not medical advice.',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeAndRestChips(Exercise exercise, int totalSets) {
    final isTimed = _isTimed(exercise);
    final isBodyweight = _isBodyweight(exercise);
    final typeLabel = isTimed ? 'Timed' : (isBodyweight ? 'Bodyweight' : 'Weighted');
    final tip = ExerciseCoachingService.getCoaching(
      exerciseName: exercise.name,
      setIndex: 0,
      totalSets: totalSets,
      primaryTarget: TargetedBodyPart.FullBody,
      lowEnergy: false,
      sore: false,
    );
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 4,
      children: [
        _pill(typeLabel),
        _pill('Rest ~ ${tip.suggestedRestSeconds}s'),
      ],
    );
  }

  Widget _buildInlineCoaching(Exercise exercise, int setNum, int totalSets) {
    final tip = ExerciseCoachingService.getCoaching(
      exerciseName: exercise.name,
      setIndex: (setNum - 1).clamp(0, totalSets - 1),
      totalSets: totalSets,
      primaryTarget: TargetedBodyPart.FullBody,
      lowEnergy: false,
      sore: false,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          Text(tip.headline, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 4,
            children: tip.tips.map((t) => _bullet(t)).toList(),
          ),
          if (tip.pitfalls.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 4,
              children: tip.pitfalls.map((p) => _chip(p)).toList(),
            ),
          ],
          const SizedBox(height: 6),
          Text('Why this set? ${tip.whyThisSet}', style: const TextStyle(color: Colors.white60, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildInputControls(
      NumberTickerController weightController, NumberTickerController repsController, Exercise exercise) {
    final isTimed = _isTimed(exercise);
    final isBodyweight = _isBodyweight(exercise);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          if (!isTimed && !isBodyweight)
            Expanded(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Flexible(
                        child: Text(
                          'Weight (kg)',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(minWidth: 28, minHeight: 28),
                        onPressed: () => _applyAIRecommendedWeight(exercise, weightController),
                        icon: const Icon(Icons.psychology, color: Colors.tealAccent, size: 18),
                        tooltip: 'AI Suggests Weight',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildTickerRow(weightController),
                ],
              ),
            ),
          if (!isTimed && !isBodyweight) const SizedBox(width: 12),
          Expanded(
            child: Column(
              children: [
                Text(
                  isTimed ? 'Seconds' : 'Reps',
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
                FutureBuilder<int>(
                  future: _getAiRepsOrSecondsSuggestion(exercise, isTimed: isTimed),
                  builder: (context, snap) {
                    if (!snap.hasData) return const SizedBox(height: 0);
                    final v = snap.data!;
                    final label = isTimed ? 'AI: ${v}s' : 'AI: ${v} reps';
                    return Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(label, style: const TextStyle(color: Colors.tealAccent, fontSize: 12)),
                    );
                  },
                ),
                if (isTimed)
                  Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: Wrap(
                      spacing: 8,
                      children: [20, 30, 45, 60].map((s) => _pillButton('$s s', onTap: () { repsController.number = s.toDouble(); })).toList(),
                    ),
                  ),
                const SizedBox(height: 8),
                _buildTickerRow(repsController),
                if (isBodyweight)
                  Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: Text(
                      'Bodyweight set — focus on quality reps',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ),
                if (isTimed || isBodyweight)
                  Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: IconButton(
                      onPressed: () => _applyAIRecommendedRepsOrSeconds(exercise, repsController, isTimed: isTimed),
                      icon: const Icon(Icons.psychology, color: Colors.tealAccent, size: 18),
                      tooltip: isTimed ? 'AI Suggests Seconds' : 'AI Suggests Reps',
                    ),
                  ),
                if (isTimed)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: ElevatedButton.icon(
                      onPressed: () => _startTimed(exercise, repsController.number.toInt()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.tealAccent.shade400,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      ),
                      icon: const Icon(Icons.timer),
                      label: const Text('Start Timer'),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTickerRow(NumberTickerController controller) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: () => controller.decrement(),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          iconSize: 22,
          icon: const Icon(Icons.remove, color: Colors.white),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: GestureDetector(
            onTap: () => _showNumberInputDialog('Edit', controller),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: NumberTicker(
                controller: controller,
                textStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        IconButton(
          onPressed: () => controller.increment(),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          iconSize: 22,
          icon: const Icon(Icons.add, color: Colors.white),
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
    final currentSetNum = _setNumberOfStep[_currentStepIndex];
    final totalSets = _setsTotalInStepOrder[_currentStepIndex];

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
      // Suggest rest based on coaching service
      final tip = ExerciseCoachingService.getCoaching(
        exerciseName: exercise.name,
        setIndex: (currentSetNum - 1).clamp(0, totalSets - 1),
        totalSets: totalSets,
        primaryTarget: TargetedBodyPart.FullBody,
        lowEnergy: false,
        sore: false,
      );
      _startRestPeriod(duration: tip.suggestedRestSeconds);
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

  // --- Timed exercise overlay & flow (instance methods) ---
  Widget _timedOverlay() {
    final nextName = (_currentStepIndex < _exerciseIndexesInStepOrder.length - 1)
        ? _currentExercises[_exerciseIndexesInStepOrder[_currentStepIndex + 1]].name
        : 'Finish';
    return Container(
      color: Colors.black.withOpacity(0.9),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Timed Set',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Up next: $nextName',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 20),
            Text(
              '$_timedExerciseRemainingSeconds',
              style: const TextStyle(color: Colors.white, fontSize: 64, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: _stopTimedEarly,
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white54)),
                  child: const Text('Stop', style: TextStyle(color: Colors.white)),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
                  child: const Text('Counting...'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _startTimed(Exercise exercise, int seconds) {
    if (seconds <= 0) seconds = 30;
    setState(() {
      _isTimedExerciseActive = true;
      _timedExerciseRemainingSeconds = seconds;
    });
    _exerciseTimer?.cancel();
    _exerciseTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_timedExerciseRemainingSeconds > 0) {
        setState(() {
          _timedExerciseRemainingSeconds--;
        });
      } else {
        t.cancel();
        _exerciseTimer = null;
        _completeTimed(exercise, seconds);
      }
    });
  }

  void _stopTimedEarly() {
    _exerciseTimer?.cancel();
    _exerciseTimer = null;
    setState(() {
      _isTimedExerciseActive = false;
    });
  }

  void _completeTimed(Exercise exercise, int secondsSelected) {
    setState(() {
      _isTimedExerciseActive = false;
    });
    final exerciseIdx = _exerciseIndexesInStepOrder[_currentStepIndex];
    final setPerformance = SetPerformance(
      targetReps: secondsSelected,
      targetWeight: 0,
      actualReps: secondsSelected,
      actualWeight: 0,
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
      final tip = ExerciseCoachingService.getCoaching(
        exerciseName: exercise.name,
        setIndex: 0,
        totalSets: 1,
        primaryTarget: TargetedBodyPart.FullBody,
        lowEnergy: false,
        sore: false,
      );
      _startRestPeriod(duration: tip.suggestedRestSeconds);
    } else {
      _finishWorkout();
    }
  }
  }

  // Removed old top-level variant; now using instance method _timedOverlay() above

// --- Small UI helpers ---
Widget _pill(String label) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white10,
      border: Border.all(color: Colors.white24),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(label, style: const TextStyle(color: Colors.white70)),
  );
}

Widget _bullet(String text) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white10,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(text, style: const TextStyle(color: Colors.white70)),
  );
}

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: const TextStyle(color: Colors.redAccent)),
    );
  }

  Widget _pillButton(String text, {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white10,
          border: Border.all(color: Colors.white24),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ),
    );
  }

Future<void> _applyAIRecommendedWeight(Exercise exercise, NumberTickerController controller) async {
  try {
    final UserProfile? profile = await sharedPrefsProvider.getUserProfile();
    final service = AIWeightRecommendationService();
    final rec = await service.getRecommendedWeight(
      exerciseName: exercise.name,
      userProfile: profile,
      targetReps: 10,
    );
    controller.number = rec;
  } catch (e) {
    // No UI here; the controlling page can show a snackbar in future
  }
}

Future<void> _applyAIRecommendedRepsOrSeconds(Exercise exercise, NumberTickerController controller, {required bool isTimed}) async {
  try {
    final UserProfile? profile = await sharedPrefsProvider.getUserProfile();
    final svc = AIRepTimeRecommendationService();
    final int rec = isTimed
        ? await svc.recommendSeconds(exerciseName: exercise.name, userProfile: profile)
        : await svc.recommendReps(exerciseName: exercise.name, userProfile: profile);
    controller.number = rec.toDouble();
  } catch (_) {}
}

Future<int> _getAiRepsOrSecondsSuggestion(Exercise exercise, {required bool isTimed}) async {
  try {
    final UserProfile? profile = await sharedPrefsProvider.getUserProfile();
    final svc = AIRepTimeRecommendationService();
    return isTimed
        ? await svc.recommendSeconds(exerciseName: exercise.name, userProfile: profile)
        : await svc.recommendReps(exerciseName: exercise.name, userProfile: profile);
  } catch (_) {
    return isTimed ? 30 : 12;
  }
}

bool _isBodyweight(Exercise ex) {
  if (ex.workoutType == WorkoutType.Weight && ex.weight <= 0.0) return true;
  final n = ex.name.toLowerCase();
  const bw = [
    'push', 'push-up', 'push up', 'pull-up', 'pull up', 'crunch', 'sit-up', 'sit up', 'plank', 'mountain climber',
    'dips', 'dip', 'burpee', 'jumping jack', 'bodyweight', 'hollow hold', 'leg raise'
  ];
  return bw.any((k) => n.contains(k));
}

bool _isTimed(Exercise ex) {
  if (ex.workoutType == WorkoutType.Timed) return true;
  final n = ex.name.toLowerCase();
  const timed = ['plank', 'hold', 'wall sit', 'hollow hold', 'mountain climber', 'jumping jack'];
  return timed.any((k) => n.contains(k));
}
