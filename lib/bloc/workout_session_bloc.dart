import 'dart:async';
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:bloc/bloc.dart';
import 'package:rxdart/rxdart.dart';
import 'package:workout_planner/resource/db_provider_interface.dart'; // <--- ADD THIS IMPORT
import 'package:workout_planner/resource/db_provider_io.dart';
// Import your CORRECT models (assuming immutable versions)
import 'package:workout_planner/models/routine.dart';
import 'package:workout_planner/models/workout_session.dart';

import '../models/exercise_performance.dart';
import '../models/set_performance.dart';
// Needed indirectly

// Import DB Provider
// Make sure path is correct

// --- Define Events (Simplified Set) ---

@immutable
abstract class WorkoutSessionEvent {}

// Event to start a new session from a Routine template
class WorkoutSessionStartNew extends WorkoutSessionEvent {
  final Routine routine;
  WorkoutSessionStartNew(this.routine);
}

// Event to load an existing session
class WorkoutSessionLoadExisting extends WorkoutSessionEvent {
  final String sessionId;
  WorkoutSessionLoadExisting(this.sessionId);
}

// Event triggered when a set is completed
class WorkoutSetMarkedComplete extends WorkoutSessionEvent {
  final int exerciseIndex;
  final int setIndex;
  final int actualReps;
  final double actualWeight;

  WorkoutSetMarkedComplete({
    required this.exerciseIndex,
    required this.setIndex,
    required this.actualReps,
    required this.actualWeight,
  });
}

// Event triggered to finish the workout (starts saving process)
class WorkoutSessionFinishAttempt extends WorkoutSessionEvent {}

// --- Internal Events ---
class _SessionTimerTicked extends WorkoutSessionEvent {
  final Duration elapsedDuration;
  _SessionTimerTicked(this.elapsedDuration);
}

class _RestTimerTicked extends WorkoutSessionEvent {
  final Duration remainingDuration;
  _RestTimerTicked(this.remainingDuration);
}

class _RestPeriodEnded extends WorkoutSessionEvent {
  _RestPeriodEnded();
}


// --- Define State (Simplified Structure) ---

@immutable
class WorkoutSessionState {
  final WorkoutSession? session;      // Current session data
  final Duration displayDuration;   // Duration to show (elapsed time or rest time)
  final bool isLoading;             // Loading session or saving
  final bool isResting;             // Is a rest timer active?
  final bool isFinished;            // Has the session been successfully finished and saved?
  final String? errorMessage;       // Any error message

  const WorkoutSessionState({
    this.session,
    this.displayDuration = Duration.zero,
    this.isLoading = false,
    this.isResting = false,
    this.isFinished = false,
    this.errorMessage,
  });

  // CopyWith helper for immutable state updates
  WorkoutSessionState copyWith({
    WorkoutSession? session,
    Duration? displayDuration,
    bool? isLoading,
    bool? isResting,
    bool? isFinished,
    String? errorMessage,
    bool clearError = false, // Helper flag
    bool clearSession = false, // Helper flag
  }) {
    return WorkoutSessionState(
      session: clearSession ? null : (session ?? this.session),
      displayDuration: displayDuration ?? this.displayDuration,
      isLoading: isLoading ?? this.isLoading,
      isResting: isResting ?? this.isResting,
      isFinished: isFinished ?? this.isFinished,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}


// --- Implement the BLoC (Simplified Events/State, Correct Logic) ---

class WorkoutSessionBloc extends Bloc<WorkoutSessionEvent, WorkoutSessionState> {
  Timer? _sessionTimer;
  Timer? _restTimer;
  final DbProviderInterface dbProvider;
  final BehaviorSubject<List<WorkoutSession>> _allSessionsController = BehaviorSubject<List<WorkoutSession>>.seeded([]);

  // Stream of all workout sessions
  Stream<List<WorkoutSession>> get allSessionsStream => _allSessionsController.stream;

  WorkoutSessionBloc({required this.dbProvider}) : super(const WorkoutSessionState()) {
    // Initialize with current sessions
    _loadAllSessions();
    // Register event handlers
    on<WorkoutSessionStartNew>(_onWorkoutSessionStartNew);
    on<WorkoutSessionLoadExisting>(_onWorkoutSessionLoadExisting);
    on<WorkoutSetMarkedComplete>(_onWorkoutSetMarkedComplete);
    on<WorkoutSessionFinishAttempt>(_onWorkoutSessionFinishAttempt);

    // Internal event handlers
    on<_SessionTimerTicked>(_onSessionTimerTicked);
    on<_RestTimerTicked>(_onRestTimerTicked);
    on<_RestPeriodEnded>(_onRestPeriodEnded);
  }

  // Add this method to refresh the data
  void refreshData() {
    _loadAllSessions();
  }

  void _onWorkoutSessionStartNew(WorkoutSessionStartNew event, Emitter<WorkoutSessionState> emit) {
    debugPrint("BLoC: Starting new session from Routine: ${event.routine.routineName}");
    _cancelTimers();

    // Create the session using the Routine (WorkoutSession constructor handles defaults)
      final newSession = WorkoutSession.startNew(
        routine: event.routine,
        startTime: DateTime.now(),
      );

    emit(const WorkoutSessionState().copyWith( // Reset state completely
      session: newSession,
      displayDuration: Duration.zero,
      isLoading: false,
      isResting: false,
      isFinished: false,
    ));
    _startSessionTimer();
  }

  Future<void> _onWorkoutSessionLoadExisting(WorkoutSessionLoadExisting event, Emitter<WorkoutSessionState> emit) async {
    debugPrint("BLoC: Loading session ID ${event.sessionId}");
    _cancelTimers();
    // Set loading state, clear previous session/error
    emit(const WorkoutSessionState().copyWith(isLoading: true));

    try {
      final session = await dbProvider.getWorkoutSessionById(event.sessionId);
      if (session != null) {
        debugPrint("BLoC: Session loaded successfully (ID: ${session.id}). Completed: ${session.isCompleted}");

        if (session.isCompleted && session.endTime != null) {
          // Session is already finished
          final finalDuration = session.endTime!.difference(session.startTime);
          emit(state.copyWith(
            isLoading: false,
            isFinished: true, // Mark as finished
            session: session,
            displayDuration: finalDuration,
          ));
        } else {
          // Session is ongoing (or was stopped abruptly)
          // Calculate current elapsed time, but don't start timer automatically
          // UI will need a way to trigger resume (e.g., start timer on interaction)
          final elapsedDuration = DateTime.now().difference(session.startTime);
          emit(state.copyWith(
            isLoading: false,
            isFinished: false, // Not finished
            session: session,
            displayDuration: elapsedDuration, // Show current elapsed time
          ));
          // NOTE: Timer is NOT started here. UI should handle resuming.
          // If you want automatic resume on load, call _startSessionTimer() here.
          debugPrint("BLoC: Loaded ongoing session. Current elapsed: $elapsedDuration. Timer not started.");
        }
      } else {
        debugPrint("BLoC: Error - Session ID ${event.sessionId} not found.");
        emit(state.copyWith(isLoading: false, errorMessage: "Workout session not found."));
      }
    } catch (e, s) {
      debugPrint("BLoC: Error loading session: $e\n$s");
      emit(state.copyWith(isLoading: false, errorMessage: "Failed to load workout session."));
    }
  }

  void _onWorkoutSetMarkedComplete(WorkoutSetMarkedComplete event, Emitter<WorkoutSessionState> emit) {
    // Ignore if session doesn't exist or is already finished/saving
    if (state.session == null || state.isFinished || state.isLoading) return;

    debugPrint("BLoC: Completing Set: Ex ${event.exerciseIndex}, Set ${event.setIndex}, Reps ${event.actualReps}, Weight ${event.actualWeight}");

    try {
      // --- Immutable Update Logic ---
      final currentSession = state.session!;
      // Create a new list of ExercisePerformance, deep copying the sets within each
      final updatedExercises = List<ExercisePerformance>.from(currentSession.exercises.map((exPerf) =>
          ExercisePerformance(
            exerciseName: exPerf.exerciseName,
            sets: List<SetPerformance>.from(exPerf.sets), // Deep copy sets
            restPeriod: exPerf.restPeriod,
          )
      ));

      // Validate indices
      if (event.exerciseIndex < 0 || event.exerciseIndex >= updatedExercises.length) {
        throw Exception("Invalid exercise index: ${event.exerciseIndex}");
      }
      final targetExercise = updatedExercises[event.exerciseIndex];

      if (event.setIndex < 0 || event.setIndex >= targetExercise.sets.length) {
        throw Exception("Invalid set index: ${event.setIndex} for exercise ${targetExercise.exerciseName}");
      }
      final originalSet = targetExercise.sets[event.setIndex];

      // Create the *new* updated SetPerformance object
      final updatedSet = SetPerformance(
        targetReps: originalSet.targetReps,
        targetWeight: originalSet.targetWeight,
        actualReps: event.actualReps,
        actualWeight: event.actualWeight,
        isCompleted: true,
      );

      // Replace the set in the *copied* exercise's *copied* sets list
      targetExercise.sets[event.setIndex] = updatedSet;

      // Create the new WorkoutSession instance with the updated exercises list
      final updatedSession = WorkoutSession( // Use constructor like copyWith
        id: currentSession.id,
        routine: currentSession.routine,
        startTime: currentSession.startTime,
        exercises: updatedExercises,
        endTime: currentSession.endTime,
        isCompleted: currentSession.isCompleted,
      );

      // Emit the updated session state *before* handling rest
      // Ensure we are not in resting state yet
      emit(state.copyWith(session: updatedSession, isResting: false, clearError: true));

      // --- Handle Rest Period ---
      Duration? restDuration = targetExercise.restPeriod;
      bool isLastSet = event.setIndex == targetExercise.sets.length - 1;

      if (restDuration != null && restDuration.inSeconds > 0 && !isLastSet) {
        debugPrint("BLoC: Starting rest period: $restDuration");
        _cancelTimers(); // Stop main session timer
        emit(state.copyWith(isResting: true, displayDuration: restDuration)); // Set resting flag and duration
        _startRestTimer(restDuration);
      } else {
        debugPrint("BLoC: No rest period or last set completed.");
        _startSessionTimer(); // Ensure main timer is running (might have been paused)
      }

    } catch (e, s) {
      debugPrint("Error updating set: $e\n$s");
      emit(state.copyWith(isResting: false, errorMessage: "Failed to update set: $e"));
      _startSessionTimer(); // Try to restart main timer if error occurred during rest logic
    }
  }

  Future<void> _onWorkoutSessionFinishAttempt(WorkoutSessionFinishAttempt event, Emitter<WorkoutSessionState> emit) async {
    // Ignore if session doesn't exist or is already finished/saving
    if (state.session == null || state.isFinished || state.isLoading) return;

    debugPrint("BLoC: Finishing session...");
    _cancelTimers();
    final currentSession = state.session!; // Capture session before emitting loading state
    final startTime = currentSession.startTime;

    emit(state.copyWith(isLoading: true, isResting: false)); // Indicate saving, ensure not resting

    try {
      final endTime = DateTime.now();
      final finalDuration = endTime.difference(startTime);

      // Create the final session state using the constructor
      final finishedSession = WorkoutSession(
        id: currentSession.id,
        routine: currentSession.routine,
        startTime: currentSession.startTime,
        exercises: currentSession.exercises, // Keep recorded performance
        endTime: endTime,
        isCompleted: true,
      );

      debugPrint("BLoC: Saving finished session (ID: ${finishedSession.id}). Final Duration: $finalDuration");
      await dbProvider.saveWorkoutSession(finishedSession);
      debugPrint("BLoC: Session saved successfully.");
      
      // --- Update Routine Completion Count ---
      final routineId = finishedSession.routine.id;
      if (routineId != null) {
        // Access the DBProviderIO implementation to call _getRoutineById
        if (dbProvider is DBProviderIO) {
          final routine = await dbProvider.getRoutineById(routineId);
          if (routine != null) {
            final updatedRoutine = routine.copyWith(completionCount: (routine.completionCount ?? 0) + 1);
            await dbProvider.updateRoutine(updatedRoutine);
            debugPrint("BLoC: Updated completion count for routine ${updatedRoutine.routineName} to ${updatedRoutine.completionCount}");
          } else {
            debugPrint("BLoC: Routine with ID $routineId not found.");
          }
        } else {
          debugPrint("BLoC: DBProvider is not DBProviderIO, cannot update completion count.");
        }
      } else {
        debugPrint("BLoC: Routine ID is null, cannot update completion count.");
      }
      // --- End Update Routine Completion Count ---
      
      // Update all sessions stream
      _loadAllSessions();

      emit(state.copyWith(
        isLoading: false,
        isFinished: true, // Mark as successfully finished
        session: finishedSession,
        displayDuration: finalDuration, // Show final duration
      ));

    } catch (e, s) {
      debugPrint("BLoC: Error saving session: $e\n$s");
      // Keep isLoading false, don't mark as finished, show error
      emit(state.copyWith(
        isLoading: false,
        isFinished: false, // Save failed
        session: currentSession, // Revert to session state before save attempt
        errorMessage: "Failed to save workout session.",
        // Recalculate duration based on current time if needed? Or keep stopped time?
        // Let's keep the duration from before the save attempt.
        // displayDuration: DateTime.now().difference(startTime)
      ));
      // Keep timers stopped. User needs to potentially retry or discard.
    }
  }

  // --- Internal Timer Handlers ---

  void _onSessionTimerTicked(_SessionTimerTicked event, Emitter<WorkoutSessionState> emit) {
    // Only tick if session exists, is NOT resting, NOT finished, NOT loading
    if (state.session != null && !state.isResting && !state.isFinished && !state.isLoading) {
      // Calculate precise elapsed time from start time
      final elapsed = DateTime.now().difference(state.session!.startTime);
      emit(state.copyWith(displayDuration: elapsed));
    } else {
      // Status changed, timer should be stopped
      _sessionTimer?.cancel();
      _sessionTimer = null;
    }
  }

  _onRestTimerTicked(_RestTimerTicked event, Emitter<WorkoutSessionState> emit) {
    // Only tick if IS resting
    if (state.isResting) {
      emit(state.copyWith(displayDuration: event.remainingDuration));
    } else {
      _restTimer?.cancel();
      _restTimer = null;
    }
  }

  void _onRestPeriodEnded(_RestPeriodEnded event, Emitter<WorkoutSessionState> emit) {
    // Only process if WAS resting
    if (state.isResting && state.session != null) {
      debugPrint("BLoC: Rest period ended.");
      // Calculate current elapsed time when rest ends
      final elapsed = DateTime.now().difference(state.session!.startTime);
      // Switch back to non-resting state, update duration to elapsed time
      emit(state.copyWith(isResting: false, displayDuration: elapsed));
      _startSessionTimer(); // Restart the main workout timer
    }
  }

  // --- Timer Control ---

  void _startSessionTimer() {
    // Only start if session exists, timer not active, not resting, not finished, not loading
    if (state.session == null || _sessionTimer?.isActive == true || state.isResting || state.isFinished || state.isLoading) {
      return;
    }

    debugPrint("BLoC: Starting session timer.");
    _restTimer?.cancel(); // Ensure rest timer is stopped
    _restTimer = null;

    // Ensure displayDuration reflects current elapsed time when timer starts
    final initialElapsed = DateTime.now().difference(state.session!.startTime);
    if (state.displayDuration.inSeconds != initialElapsed.inSeconds) {
      emit(state.copyWith(displayDuration: initialElapsed));
    }

    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // Add internal event; duration is calculated in the handler
      add(_SessionTimerTicked(Duration.zero));
    });
  }

  void _startRestTimer(Duration restDuration) {
    // Only start if session exists and state is currently resting
    if (state.session == null || !state.isResting) {
      debugPrint("BLoC: Skipping startRestTimer (Not in resting state)");
      return;
    }

    _sessionTimer?.cancel(); // Ensure session timer is stopped
    _sessionTimer = null;
    _restTimer?.cancel(); // Cancel previous rest timer if any

    Duration remaining = restDuration;
    // Emit initial rest time immediately (already done when setting isResting=true)
    // emit(state.copyWith(displayDuration: remaining));

    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      remaining = remaining - const Duration(seconds: 1);
      if (remaining.isNegative) remaining = Duration.zero;

      add(_RestTimerTicked(remaining)); // Send remaining duration

      if (remaining.inSeconds <= 0) {
        _restTimer?.cancel();
        _restTimer = null;
        add(_RestPeriodEnded()); // Signal rest end
      }
    });
  }

  void _cancelTimers() {
    _sessionTimer?.cancel();
    _sessionTimer = null;
    _restTimer?.cancel();
    _restTimer = null;
  }

  // --- Cleanup ---

  // Load all sessions from DB
  Future<void> _loadAllSessions() async {
    try {
      final sessions = await dbProvider.getWorkoutSessions();
      debugPrint("BLoC: Loaded ${sessions.length} sessions from DB");
      _allSessionsController.add(sessions);
      debugPrint("BLoC: Added sessions to _allSessionsController");
    } catch (e) {
      debugPrint("Error loading all sessions: $e");
      _allSessionsController.addError(e);
    }
  }

  @override
  Future<void> close() {
    debugPrint("BLoC: Closing WorkoutSessionBloc.");
    _cancelTimers();
    _allSessionsController.close();
    return super.close();
  }
}
