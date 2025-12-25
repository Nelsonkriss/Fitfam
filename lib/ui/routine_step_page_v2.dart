import 'dart:async';
import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:workout_planner/services/progressive_plan_service.dart';

import 'components/number_ticker.dart';
import 'components/value_slider.dart';
import 'components/progress_ring.dart';
import 'design_system.dart';

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
  int _restTimeTotal = 0;
  int _preparationTimeRemaining = 3;
  Timer? _restTimer;
  Timer? _preparationTimer;
  Timer? _exerciseTimer;
  int _timedExerciseRemainingSeconds = 0;
  int _timedExerciseTotalSeconds = 0;
  bool _isTimedExerciseActive = false;
  bool _isPersonalizing = false;
  bool _planSuggestionShown = false;
  String _weightUnit = 'kg';

  @override
  void initState() {
    super.initState();

    _setTransitionController = AnimationController(duration: AndroidAnimations.m3LongDuration, vsync: this);
    _exerciseTransitionController = AnimationController(duration: AndroidAnimations.m3MediumDuration, vsync: this);
    _restPeriodController = AnimationController(duration: AndroidAnimations.m3MediumDuration, vsync: this);
    _preparationController = AnimationController(duration: AndroidAnimations.m3MediumDuration, vsync: this);
    _completionController = AnimationController(duration: AndroidAnimations.m3ExtraLongDuration, vsync: this);
    _loadWeightUnit();

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
    if (widget.resumeSession == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _applyPersonalizationOnStart().then((_) {
          if (mounted) _maybeSuggestProgressivePlan();
        });
      });
    }
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

  Future<void> _loadWeightUnit() async {
    try {
      final unit = await sharedPrefsProvider.getWeightUnit();
      if (!mounted) return;
      setState(() {
        _weightUnit = unit;
      });
    } catch (_) {}
  }

  int _parseTargetRepsHint(String reps) {
    final trimmed = reps.trim().toLowerCase();
    if (trimmed.isEmpty) return 10;
    if (trimmed.contains('-')) {
      final parts = trimmed.split('-');
      final first = int.tryParse(parts.first.trim());
      if (first != null && first > 0) return first;
    }
    final match = RegExp(r'(\d+)').firstMatch(trimmed);
    if (match != null) {
      return int.tryParse(match.group(1) ?? '') ?? 10;
    }
    return int.tryParse(trimmed) ?? 10;
  }

  void _refreshActiveSessionFromRoutine() {
    if (_activeWorkoutSession == null) return;
    final seeded = WorkoutSession.startNew(routine: _currentWorkingRoutine);
    _activeWorkoutSession = _activeWorkoutSession!.copyWith(
      routine: _currentWorkingRoutine,
      exercises: seeded.exercises,
    );
  }

  Future<void> _applyPersonalizationOnStart() async {
    if (widget.resumeSession != null || _activeWorkoutSession == null) return;
    if (!mounted) return;
    setState(() => _isPersonalizing = true);
    try {
      final UserProfile? profile = await sharedPrefsProvider.getUserProfile();
      final weightService = AIWeightRecommendationService();
      final repsService = AIRepTimeRecommendationService();

      final updatedParts = <Part>[];
      bool changed = false;

      for (final part in _currentWorkingRoutine.parts) {
        final updatedExercises = <Exercise>[];
        for (final exercise in part.exercises) {
          Exercise updated = exercise;
          final isTimed = _isTimed(exercise);
          final isBodyweight = _isBodyweight(exercise);

          if (isTimed) {
            final recSeconds = await repsService.recommendSeconds(
              exerciseName: exercise.name,
              userProfile: profile,
            );
            updated = updated.copyWith(reps: recSeconds.toString());
            changed = true;
          } else if (isBodyweight) {
            final recReps = await repsService.recommendReps(
              exerciseName: exercise.name,
              userProfile: profile,
            );
            updated = updated.copyWith(reps: recReps.toString());
            changed = true;
          }

          if (exercise.workoutType == WorkoutType.Weight && !isBodyweight) {
            final targetReps = _parseTargetRepsHint(updated.reps);
            final recWeight = await weightService.getRecommendedWeight(
              exerciseName: exercise.name,
              userProfile: profile,
              targetReps: targetReps,
            );
            updated = updated.copyWith(weight: recWeight, lastUsedWeight: recWeight);
            changed = true;
          }

          updatedExercises.add(updated);
        }
        updatedParts.add(part.copyWith(exercises: updatedExercises));
      }

      if (!mounted) return;
      if (changed) {
        setState(() {
          _currentWorkingRoutine = _currentWorkingRoutine.copyWith(parts: updatedParts);
          _rebuildStateFromRoutine();
        });
        _refreshActiveSessionFromRoutine();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Personalized targets applied.')),
        );
      }
    } catch (e) {
      debugPrint("RoutineStepPageV2: Personalization failed: $e");
    } finally {
      if (mounted) setState(() => _isPersonalizing = false);
    }
  }

  void _maybeSuggestProgressivePlan() {
    if (_planSuggestionShown || widget.resumeSession != null) return;
    _planSuggestionShown = true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Want a progressive plan for this routine?'),
        action: SnackBarAction(
          label: 'Build plan',
          onPressed: () => _promptBuildPlan([_currentWorkingRoutine]),
        ),
      ),
    );
  }

  Future<void> _promptBuildPlan(List<Routine> baseRoutines) async {
    if (!mounted) return;
    int selectedWeeks = 4;
    bool includeDeload = true;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: StatefulBuilder(
            builder: (ctx, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_graph),
                      const SizedBox(width: 8),
                      Text('Build Progressive Plan', style: Theme.of(ctx).textTheme.titleLarge),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create a ${selectedWeeks}-week progression with smart increases and deloads.',
                    style: Theme.of(ctx).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Text('Weeks', style: Theme.of(ctx).textTheme.labelLarge),
                  Wrap(
                    spacing: 8,
                    children: [4, 6, 8].map((w) {
                      return ChoiceChip(
                        label: Text('$w'),
                        selected: selectedWeeks == w,
                        onSelected: (_) => setState(() => selectedWeeks = w),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Include deload every 4th week'),
                    value: includeDeload,
                    onChanged: (v) => setState(() => includeDeload = v),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Not now'),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        icon: const Icon(Icons.add_task),
                        label: const Text('Build Plan'),
                        onPressed: () async {
                          final plan = ProgressivePlanService.buildPlan(
                            baseRoutines,
                            weeks: selectedWeeks,
                            deloadEvery: includeDeload ? 4 : 0,
                          );
                          await context.read<RoutinesBloc>().addRoutines(plan);
                          if (mounted) Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Created ${plan.length} plan routine(s).')),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
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
        // Simplify primary flow: avoid duplicate Prev/Next dock
        bottomNavigationBar: null,
      ),
  );
}

  Widget _buildFinishedScreen() {
    final theme = Theme.of(context);
    // Clean finished screen with corrected copy
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.surface, AppColors.background],
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
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const ProgressRing(size: 220, progress: 1.0, centerText: 'Done', subtitle: 'Great work'),
              const SizedBox(height: 16),
              Text(
                'Workout Complete!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 20),
              const Icon(Icons.emoji_events_outlined, size: 80, color: Colors.white70),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24)),
                child: const Text('Finish'),
              ),
            ],
          ),
        ],
      ),
    );
    /*
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
                'Workout Complete! ðŸŽ‰',
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
              colors: [AppColors.background, AppColors.surface],
            ),
          ),
        ),
        // Exercise animation - faded to avoid competing with text
        Positioned(
          top: 100,
          left: 0,
          right: 0,
          child: Opacity(
            opacity: 0.35,
            child: ExerciseAnimationWidget(
              exerciseName: exercise.name,
              width: double.infinity,
              height: 400,
              autoPlay: !_isInRestPeriod && !_isInPreparation,
              showControls: false,
              showDescription: false,
            ),
          ),
        ),
        SafeArea(
          child: CustomScrollView(
            slivers: [
              _buildSliverAppBar(),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildSafetyBanner(),
                      const SizedBox(height: 8),
                      _buildExerciseInfo(exercise, setNum, totalSets),
                      const SizedBox(height: 8),
                      _buildTypeAndRestChips(exercise, totalSets),
                      const SizedBox(height: 8),
                      _buildInlineCoaching(exercise, setNum, totalSets),
                      const SizedBox(height: 12),
                      _buildInputControlsV3(weightController, repsController, exercise),
                      const SizedBox(height: 12),
                      _buildActionButtons(),
                      const SizedBox(height: 8),
                      _buildNextExerciseInfo(),
                      const SizedBox(height: 8),
                      _buildProgressBar(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_isPersonalizing)
          Positioned(
            top: 12,
            right: 12,
            child: _pill('Personalizing...'),
          ),
        if (_isInRestPeriod) _buildRestPeriodOverlay(),
        if (_isTimedExerciseActive) _timedOverlay(),
      ],
    );
    */
  }

  // Newer, corrected version to avoid encoding glitches and tighten UX
  Widget _buildInputControlsV3(
      NumberTickerController weightController, NumberTickerController repsController, Exercise exercise) {
    final isTimed = _isTimed(exercise);
    final isBodyweight = _isBodyweight(exercise);
    final weightLabel = 'Weight ($_weightUnit)';
    final weightDeltas = _weightUnit == 'lb'
        ? const [-10.0, -5.0, 5.0, 10.0, 20.0]
        : const [-5.0, -2.5, 2.5, 5.0, 10.0];
    final repDeltas = isTimed ? const [-10.0, -5.0, 5.0, 10.0, 20.0] : const [-2.0, -1.0, 1.0, 2.0, 5.0];
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
                      Flexible(
                        child: Text(
                          weightLabel,
                          style: const TextStyle(color: Colors.white70, fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        onPressed: () => _applyAIRecommendedWeight(exercise, weightController),
                        icon: const Icon(Icons.psychology, color: Colors.tealAccent, size: 18),
                        tooltip: 'AI Suggests Weight',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildTickerRow(
                    weightController,
                    semanticsLabel: 'Weight',
                    dialogLabel: weightLabel,
                    suffix: _weightUnit,
                  ),
                  const SizedBox(height: 8),
                  _buildQuickAdjustRow(weightController, weightDeltas, unitSuffix: _weightUnit),
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
                    final label = isTimed ? 'Apply AI: ${v}s' : 'Apply AI: ${v} reps';
                    return Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: _pillButton(label, onTap: () { repsController.number = v.toDouble(); }),
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
                _buildTickerRow(
                  repsController,
                  semanticsLabel: isTimed ? 'Seconds' : 'Reps',
                  dialogLabel: isTimed ? 'Seconds' : 'Reps',
                  suffix: isTimed ? 's' : null,
                ),
                const SizedBox(height: 8),
                _buildQuickAdjustRow(repsController, repDeltas, unitSuffix: isTimed ? 's' : null),
                if (isBodyweight)
                  Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: Text('Bodyweight set — focus on quality reps', style: const TextStyle(color: Colors.white54, fontSize: 12)),
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
  Widget _buildProgressBar() {
    final total = _exerciseIndexesInStepOrder.length;
    final current = (_currentStepIndex + 1).clamp(0, total);
    final value = total == 0 ? 0.0 : current / total;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: value,
              backgroundColor: Colors.white10,
              valueColor: const AlwaysStoppedAnimation(Color(0xFF7c5cff)),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('$current of $total steps', style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  String _elapsedString() {
    final start = _activeWorkoutSession?.startTime;
    final dur = start == null ? Duration.zero : DateTime.now().difference(start);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dur.inMinutes)}:${two(dur.inSeconds % 60)}';
  }

  Widget _buildBottomDock(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xAA000000), Color(0x33000000)],
        ),
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Row(children: [
        OutlinedButton(
          onPressed: () {
            setState(() {
              _currentStepIndex = (_currentStepIndex - 1).clamp(0, _exerciseIndexesInStepOrder.length - 1);
            });
          },
          child: const Text('Prev'),
        ),
        const Spacer(),
        FilledButton(
          onPressed: _handleStepContinue, // Next also marks current set complete
          child: const Text('Next'),
        ),
      ]),
    );
  }

  Widget _buildHeader() {
    final title = _activeWorkoutSession?.routine.routineName ?? widget.originalRoutine.routineName;
    final stepText = 'Step ${(_currentStepIndex + 1).clamp(1, _exerciseIndexesInStepOrder.length)} of ${_exerciseIndexesInStepOrder.length}';
    final total = _exerciseIndexesInStepOrder.length;
    final current = (_currentStepIndex + 1).clamp(0, total);
    final headerProgress = total == 0 ? 0.0 : current / total;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x33000000), Colors.transparent],
        ),
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: Row(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(children: const [
                  Icon(Icons.arrow_back, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  // Removed label next to back icon for a cleaner header
                ]),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(stepText, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 6,
                      value: headerProgress,
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white10),
              ),
              child: Text('Elapsed: ${_elapsedString()}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  SliverAppBar _buildSliverAppBar() {
    final title = _activeWorkoutSession?.routine.routineName ?? widget.originalRoutine.routineName;
    final stepText = 'Step ${(_currentStepIndex + 1).clamp(1, _exerciseIndexesInStepOrder.length)} of ${_exerciseIndexesInStepOrder.length}';
    final total = _exerciseIndexesInStepOrder.length;
    final current = (_currentStepIndex + 1).clamp(0, total);
    final headerProgress = total == 0 ? 0.0 : current / total;

    return SliverAppBar(
      pinned: true,
      floating: false,
      snap: false,
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.onSurface,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => widget.onBackPressed != null ? widget.onBackPressed!() : Navigator.pop(context),
      ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white10),
            ),
            child: Text('Elapsed: ${_elapsedString()}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(32),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(stepText, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 6,
                  value: headerProgress,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildSafetyBanner() {
    // Safety banner removed per request
    return const SizedBox.shrink();
  }

  Widget _buildExerciseInfo(Exercise exercise, int setNum, int totalSets) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          exercise.name,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Set ' + setNum.toString() + ' of ' + totalSets.toString(),
          style: const TextStyle(color: Colors.white70, fontSize: 16),
        ),
      ],
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
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.white10,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            border: Border.all(color: Colors.white10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ExpansionTile(
            initiallyExpanded: false,
            title: const Text('Tips', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            subtitle: Text(tip.headline, style: const TextStyle(color: Colors.white70)),
            iconColor: Colors.white70,
            collapsedIconColor: Colors.white54,
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 4,
                children: tip.tips.map((t) => _bullet(t)).toList(),
              ),
              if (tip.pitfalls.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: tip.pitfalls.map((p) => _chip(p)).toList(),
                ),
              ],
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Why this set? ${tip.whyThisSet}', style: const TextStyle(color: Colors.white60, fontSize: 12)),
              ),
            ],
          ),
        ),
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
                          'Weight',
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
                  _buildTickerRow(weightController, semanticsLabel: 'Weight'),
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
                    final label = isTimed ? 'Apply AI: ${v}s' : 'Apply AI: ${v} reps';
                    return Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: _pillButton(label, onTap: () { repsController.number = v.toDouble(); }),
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
                _buildTickerRow(repsController, semanticsLabel: isTimed ? 'Seconds' : 'Reps'),
                if (isBodyweight)
                  Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: Text(
                      'Bodyweight set â€” focus on quality reps',
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

  Widget _buildTickerRow(
    NumberTickerController controller, {
    String semanticsLabel = '',
    String dialogLabel = 'Edit',
    String? suffix,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Semantics(
          button: true,
          label: semanticsLabel.isEmpty ? 'Decrease' : 'Decrease ' + semanticsLabel,
          child: IconButton(
            onPressed: () {
              controller.decrement();
              HapticFeedback.selectionClick();
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            iconSize: 28,
            icon: const Icon(Icons.remove, color: Colors.white),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: GestureDetector(
            onTap: () => _showNumberInputDialog(dialogLabel, controller, suffix: suffix),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: NumberTicker(
                controller: controller,
                textStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 52,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Semantics(
          button: true,
          label: semanticsLabel.isEmpty ? 'Increase' : 'Increase ' + semanticsLabel,
          child: IconButton(
            onPressed: () {
              controller.increment();
              HapticFeedback.selectionClick();
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            iconSize: 28,
            icon: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ],
    );
  }

  String _formatDeltaLabel(double delta) {
    final absValue = delta.abs();
    if (absValue % 1 == 0) {
      return absValue.toStringAsFixed(0);
    }
    return absValue.toStringAsFixed(1);
  }

  Widget _buildQuickAdjustRow(
    NumberTickerController controller,
    List<double> deltas, {
    String? unitSuffix,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: deltas.map((delta) {
        final sign = delta > 0 ? '+' : '';
        final unit = unitSuffix == null ? '' : unitSuffix;
        final label = '$sign${_formatDeltaLabel(delta)}$unit';
        return _pillButton(label, onTap: () {
          controller.number = controller.number + delta;
          HapticFeedback.selectionClick();
        });
      }).toList(),
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
                backgroundColor: AppColors.accent,
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
      child: Container(
        decoration: AppDecorations.card,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            const Icon(Icons.play_arrow_rounded, color: Colors.white70),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Next: ${nextExercise.name}',
                style: const TextStyle(color: Colors.white70, fontSize: 16),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestPeriodOverlay() {
    final total = _restTimeTotal == 0 ? 1 : _restTimeTotal;
    final progress = 1 - (_restTimeRemaining / total);
    final m = (_restTimeRemaining ~/ 60).toString().padLeft(2, '0');
    final s = (_restTimeRemaining % 60).toString().padLeft(2, '0');
    return Container(
      color: Colors.black.withOpacity(0.86),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ProgressRing(
              size: 220,
              progress: progress,
              centerText: '$m:$s',
              subtitle: 'Rest',
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _pillButton('-15s', onTap: () => _adjustRest(-15)),
                _pillButton('+15s', onTap: () => _adjustRest(15)),
                _pillButton('+30s', onTap: () => _adjustRest(30)),
                _pillButton('+60s', onTap: () => _adjustRest(60)),
              ],
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _endRestPeriod,
              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white54), padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14)),
              child: const Text('Skip Rest', style: TextStyle(color: Colors.white)),
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
      targetReps: reps,
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
      _restTimeTotal = duration;
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

  void _adjustRest(int deltaSeconds) {
    if (!_isInRestPeriod) return;
    final nextRemaining = (_restTimeRemaining + deltaSeconds).clamp(0, 3600);
    if (nextRemaining == 0) {
      _endRestPeriod();
      return;
    }
    setState(() {
      _restTimeRemaining = nextRemaining;
      final nextTotal = _restTimeTotal + deltaSeconds;
      _restTimeTotal = nextTotal < nextRemaining ? nextRemaining : nextTotal;
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

  Routine _mergeLastUsedWeights(Routine base, WorkoutSession session) {
    final Map<String, double> lastWeights = {};
    for (final ex in session.exercises) {
      for (final set in ex.sets) {
        if (!set.isCompleted) continue;
        if (set.actualWeight > 0) {
          lastWeights[ex.exerciseName] = set.actualWeight;
        }
      }
    }
    if (lastWeights.isEmpty) return base;
    final updatedParts = base.parts.map((part) {
      final updatedExercises = part.exercises.map((exercise) {
        final weight = lastWeights[exercise.name];
        if (weight == null || weight <= 0) return exercise;
        return exercise.copyWith(lastUsedWeight: weight);
      }).toList();
      return part.copyWith(exercises: updatedExercises);
    }).toList();
    return base.copyWith(parts: updatedParts);
  }

  void _finishWorkout() {
    final finalSession = _activeWorkoutSession?.copyWith(
      endTime: DateTime.now(),
      isCompleted: true,
    );
    if (finalSession != null) {
      final updatedRoutine = _mergeLastUsedWeights(_currentWorkingRoutine, finalSession).copyWith(
        completionCount: _currentWorkingRoutine.completionCount + 1,
        lastCompletedDate: DateTime.now(),
      );
      Provider.of<WorkoutSessionBloc>(context, listen: false).add(WorkoutSessionSaveCompleted(finalSession));
      Provider.of<RoutinesBloc>(context, listen: false).updateRoutine(updatedRoutine);
    }

    setState(() {
      _finished = true;
    });
    _completionController.forward();
    _confettiController.play();
    widget.celebrateCallback?.call();
  }

  Future<void> _showNumberInputDialog(
    String label,
    NumberTickerController controller, {
    String? suffix,
  }) async {
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
              suffixText: suffix,
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
    final total = _timedExerciseTotalSeconds == 0 ? 1 : _timedExerciseTotalSeconds;
    final progress = 1 - (_timedExerciseRemainingSeconds / total);
    return Container(
      color: Colors.black.withOpacity(0.9),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Timed Set', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Up next: $nextName', style: const TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 20),
            ProgressRing(size: 240, progress: progress, centerText: _timedExerciseRemainingSeconds.toString(), subtitle: 'seconds'),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: _stopTimedEarly,
              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white54), padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14)),
              child: const Text('Stop', style: TextStyle(color: Colors.white)),
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
      _timedExerciseTotalSeconds = seconds;
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






