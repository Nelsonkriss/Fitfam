// bloc/workout_session_bloc.dart
import 'dart:async';
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:bloc/bloc.dart';
import 'package:rxdart/rxdart.dart'; // For BehaviorSubject
import 'package:workout_planner/resource/db_provider_interface.dart';
// Import your correct models (assuming immutable versions with copyWith)
import 'package:workout_planner/models/routine.dart';
import 'package:workout_planner/models/workout_session.dart';
import 'package:workout_planner/models/exercise_performance.dart';
import 'package:workout_planner/models/set_performance.dart';

// --- Events ---

@immutable
abstract class WorkoutSessionEvent {}

/// Event to start a new session based on a Routine template.
class WorkoutSessionStartNew extends WorkoutSessionEvent {
  final Routine routine;
  WorkoutSessionStartNew(this.routine);
}

/// Event to load an existing, possibly ongoing, session.
class WorkoutSessionLoadExisting extends WorkoutSessionEvent {
  final String sessionId;
  WorkoutSessionLoadExisting(this.sessionId);
}

/// Event triggered when actual weight is updated without completing the set
class WorkoutSetActualWeightChanged extends WorkoutSessionEvent {
  final int exerciseIndex;
  final int setIndex;
  final double actualWeight;

  WorkoutSetActualWeightChanged({
    required this.exerciseIndex,
    required this.setIndex,
    required this.actualWeight,
  });
}

/// Event triggered when a set is completed during the workout.
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

class WorkoutSetTargetWeightChanged extends WorkoutSessionEvent {
  final int exerciseIndex;
  final int setIndex;
  final double targetWeight;

  WorkoutSetTargetWeightChanged({
    required this.exerciseIndex,
    required this.setIndex,
    required this.targetWeight,
  });
}

/// Event triggered to finish the current workout session attempt.
class WorkoutSessionFinishAttempt extends WorkoutSessionEvent {}

/// Event to directly save a fully formed, completed WorkoutSession.
class WorkoutSessionSaveCompleted extends WorkoutSessionEvent {
  final WorkoutSession session;
  WorkoutSessionSaveCompleted(this.session);
}

// --- Internal Events for Timer Management ---
class _SessionTimerTicked extends WorkoutSessionEvent {} // No payload needed
class _RestTimerTicked extends WorkoutSessionEvent {
  final Duration remainingDuration;
  _RestTimerTicked(this.remainingDuration);
}
class _RestPeriodEnded extends WorkoutSessionEvent {}
class _ExerciseTimerTicked extends WorkoutSessionEvent {
  final Duration remainingDuration;
  _ExerciseTimerTicked(this.remainingDuration);
}
class _TimedExerciseEnded extends WorkoutSessionEvent {
  final int exerciseIndex;
  final int setIndex;
  _TimedExerciseEnded(this.exerciseIndex, this.setIndex);
}


// --- State ---

@immutable
class WorkoutSessionState {
  final WorkoutSession? session;      // Current active session data
  final Duration displayDuration;   // Duration shown on UI (elapsed time or rest time)
  final bool isLoading;             // Loading session from DB or saving finished session
  final bool isResting;             // Is a rest timer currently active?
  final bool isFinished;            // Has the session been successfully finished and saved?
  final String? errorMessage;       // Any error message to display

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
    // Use Object? to differentiate between setting null and not changing
    Object? session = const _Undefined(),
    Duration? displayDuration,
    bool? isLoading,
    bool? isResting,
    bool? isFinished,
    Object? errorMessage = const _Undefined(),
  }) {
    return WorkoutSessionState(
      session: session is _Undefined ? this.session : session as WorkoutSession?,
      displayDuration: displayDuration ?? this.displayDuration,
      isLoading: isLoading ?? this.isLoading,
      isResting: isResting ?? this.isResting,
      isFinished: isFinished ?? this.isFinished,
      errorMessage: errorMessage is _Undefined ? this.errorMessage : errorMessage as String?,
    );
  }
}
// Helper class for copyWith differentiation
class _Undefined { const _Undefined(); }


// --- BLoC Implementation ---

class WorkoutSessionBloc extends Bloc<WorkoutSessionEvent, WorkoutSessionState> {
  Timer? _sessionTimer;
  Timer? _restTimer;
  Timer? _exerciseTimer;
  final DbProviderInterface dbProvider;

  // Controller for ALL historical sessions (used by CalendarPage, potentially history lists)
  final BehaviorSubject<List<WorkoutSession>> _allSessionsController =
  BehaviorSubject<List<WorkoutSession>>.seeded([]);

  // Public stream getter for UI (e.g., CalendarPage)
  Stream<List<WorkoutSession>> get allSessionsStream =>
      _allSessionsController.stream;

  // Constructor: Initialize BLoC, load initial session list, register handlers.
  WorkoutSessionBloc({required this.dbProvider})
      : super(const WorkoutSessionState()) {
    _loadAllSessions(); // Load initial historical data into the stream on startup
    // Register event handlers
    on<WorkoutSessionStartNew>(_onWorkoutSessionStartNew);
    on<WorkoutSessionLoadExisting>(_onWorkoutSessionLoadExisting);
    on<WorkoutSetMarkedComplete>(_onWorkoutSetMarkedComplete);
    on<WorkoutSessionFinishAttempt>(_onWorkoutSessionFinishAttempt);
    on<WorkoutSessionSaveCompleted>(_onWorkoutSessionSaveCompleted); // Add handler
    on<_SessionTimerTicked>(_onSessionTimerTicked);
    on<_RestTimerTicked>(_onRestTimerTicked);
    on<_RestPeriodEnded>(_onRestPeriodEnded);
    on<_ExerciseTimerTicked>(_onExerciseTimerTicked);
    on<_TimedExerciseEnded>(_onTimedExerciseEnded);
    on<WorkoutSetTargetWeightChanged>(_onWorkoutSetTargetWeightChanged);
    on<WorkoutSetActualWeightChanged>(_onWorkoutSetActualWeightChanged);
  }

  /// Allows UI to explicitly trigger a refresh of the historical session list.
  void refreshAllSessions() {
    _loadAllSessions();
  }

  // --- Event Handlers Implementation ---

  void _onWorkoutSessionStartNew(WorkoutSessionStartNew event, Emitter<WorkoutSessionState> emit) {
    debugPrint("[WorkoutSessionBloc] Event: WorkoutSessionStartNew - Routine: ${event.routine.routineName}");
    _cancelTimers();
    try {
      final newSession = WorkoutSession.startNew(
        routine: event.routine,
        startTime: DateTime.now(),
      );
      emit(const WorkoutSessionState().copyWith( // Reset state
        session: newSession,
        displayDuration: Duration.zero,
        isLoading: false, isResting: false, isFinished: false, errorMessage: null,
      ));
      _startSessionTimer();
      debugPrint("[WorkoutSessionBloc] New session started. State emitted. Timer started.");
    } catch (e, s) {
      debugPrint("[WorkoutSessionBloc] Error creating new session: $e\n$s");
      emit(state.copyWith(isLoading: false, errorMessage: "Failed to create new session."));
    }
  }

  Future<void> _onWorkoutSessionLoadExisting(WorkoutSessionLoadExisting event, Emitter<WorkoutSessionState> emit) async {
    debugPrint("[WorkoutSessionBloc] Event: WorkoutSessionLoadExisting - ID: ${event.sessionId}");
    _cancelTimers();
    emit(const WorkoutSessionState().copyWith(isLoading: true, session: null, errorMessage: null));
    try {
      final session = await dbProvider.getWorkoutSessionById(event.sessionId);
      if (session != null) {
        debugPrint("[WorkoutSessionBloc] Session loaded from DB (ID: ${session.id}). Completed: ${session.isCompleted}");
        if (session.isCompleted && session.endTime != null) {
          final finalDuration = session.endTime!.difference(session.startTime);
          emit(state.copyWith(
            isLoading: false, isFinished: true, session: session, displayDuration: finalDuration,
          ));
          debugPrint("[WorkoutSessionBloc] Loaded finished session. State emitted.");
        } else {
          final elapsedDuration = DateTime.now().difference(session.startTime);
          emit(state.copyWith(
            isLoading: false, isFinished: false, session: session, displayDuration: elapsedDuration,
          ));
          debugPrint("[WorkoutSessionBloc] Loaded ongoing session. State emitted. Timer NOT started.");
        }
      } else {
        debugPrint("[WorkoutSessionBloc] Error - Session ID ${event.sessionId} not found in DB.");
        emit(state.copyWith(isLoading: false, errorMessage: "Workout session not found."));
      }
    } catch (e, s) {
      debugPrint("[WorkoutSessionBloc] Error loading session from DB: $e\n$s");
      emit(state.copyWith(isLoading: false, errorMessage: "Failed to load workout session."));
    }
  }

  void _onWorkoutSetMarkedComplete(WorkoutSetMarkedComplete event, Emitter<WorkoutSessionState> emit) {
    if (state.session == null || state.isFinished || state.isLoading) {
      debugPrint("[WorkoutSessionBloc] Ignoring SetMarkedComplete: Invalid state.");
      return;
    }

    // Check if this is a timed exercise
    final exercise = state.session!.exercises[event.exerciseIndex];
    if (exercise.timedDuration != null && exercise.timedDuration!.inSeconds > 0) {
      debugPrint("[WorkoutSessionBloc] Starting timed exercise: ${exercise.timedDuration}");
      _cancelTimers();
      emit(state.copyWith(isResting: false, displayDuration: exercise.timedDuration));
      _startExerciseTimer(exercise.timedDuration!, event.exerciseIndex, event.setIndex);
      return;
    }
    debugPrint("[WorkoutSessionBloc] Event: WorkoutSetMarkedComplete - ExIdx: ${event.exerciseIndex}, SetIdx: ${event.setIndex}");
    try {
      final currentSession = state.session!;
      final updatedExercises = List<ExercisePerformance>.from(
        currentSession.exercises.map((exPerf) => exPerf.copyWith(
          sets: List<SetPerformance>.from(exPerf.sets),
        )),
      );

      if (event.exerciseIndex < 0 || event.exerciseIndex >= updatedExercises.length) throw RangeError("Invalid exercise index: ${event.exerciseIndex}");
      final targetExercise = updatedExercises[event.exerciseIndex];
      if (event.setIndex < 0 || event.setIndex >= targetExercise.sets.length) throw RangeError("Invalid set index: ${event.setIndex}");

      final originalSet = targetExercise.sets[event.setIndex];
      final updatedSet = originalSet.copyWith(
        actualReps: event.actualReps, actualWeight: event.actualWeight, isCompleted: true,
      );
      targetExercise.sets[event.setIndex] = updatedSet;

      final updatedSession = currentSession.copyWith(exercises: updatedExercises);
      emit(state.copyWith(session: updatedSession, isResting: false, errorMessage: null));
      debugPrint("[WorkoutSessionBloc] Session state updated with completed set.");

      Duration? restDuration = targetExercise.restPeriod;
      bool isLastSetOfExercise = event.setIndex == targetExercise.sets.length - 1;
      if (restDuration != null && restDuration.inSeconds > 0 && !isLastSetOfExercise) {
        debugPrint("[WorkoutSessionBloc] Starting rest period: $restDuration");
        _cancelTimers();
        emit(state.copyWith(isResting: true, displayDuration: restDuration));
        _startRestTimer(restDuration);
      } else {
        debugPrint("[WorkoutSessionBloc] No rest period or last set. Ensuring session timer runs.");
        _startSessionTimer();
      }
    } catch (e, s) {
      debugPrint("[WorkoutSessionBloc] Error updating set: $e\n$s");
      emit(state.copyWith(isResting: false, errorMessage: "Failed to update set: $e"));
      _startSessionTimer();
    }
  }

  /// Handles the event to finish the current workout session attempt.
  /// Saves the session to the database, attempts to update routine stats,
  /// and updates the BLoC state and the allSessionsStream.
  Future<void> _onWorkoutSessionFinishAttempt(WorkoutSessionFinishAttempt event, Emitter<WorkoutSessionState> emit) async {
    if (state.session == null || state.isFinished || state.isLoading) {
      debugPrint("[WorkoutSessionBloc] Ignoring FinishAttempt: Invalid state.");
      return;
    }
    debugPrint("[WorkoutSessionBloc] Event: WorkoutSessionFinishAttempt received...");
    _cancelTimers();
    final currentSession = state.session!;
    final startTime = currentSession.startTime;
    bool sessionSaveSucceeded = false;

    emit(state.copyWith(isLoading: true, isResting: false));

    try {
      final endTime = DateTime.now();
      final finalDuration = endTime.difference(startTime);
      final finishedSession = currentSession.copyWith(endTime: endTime, isCompleted: true);

      // --- 1. Attempt to Save Session to DB ---
      debugPrint("[WorkoutSessionBloc] Attempting to save finished session to DB (ID: ${finishedSession.id})...");
      await dbProvider.saveWorkoutSession(finishedSession);
      sessionSaveSucceeded = true;
      debugPrint("[WorkoutSessionBloc] Session saved successfully to DB.");

      // --- 2. Attempt to Update Associated Routine Stats in DB ---
      final routineId = finishedSession.routine.id;
      if (routineId != null) {
        debugPrint("[WorkoutSessionBloc] Attempting to update stats for Routine ID: $routineId...");
        try {
          final routine = await dbProvider.getRoutineById(routineId);
          if (routine != null) {
            final newHistory = List<int>.from(routine.routineHistory)..add(endTime.millisecondsSinceEpoch);
            // *** CORRECTED: Pass DateTime object directly ***
            final updatedRoutine = routine.copyWith(
              completionCount: (routine.completionCount) + 1, // Increment count
              lastCompletedDate: endTime, // Pass DateTime?
              routineHistory: newHistory,
            );
            debugPrint("[WorkoutSessionBloc] Updating routine in DB. New Count: ${updatedRoutine.completionCount}, History Size: ${updatedRoutine.routineHistory.length}");
            await dbProvider.updateRoutine(updatedRoutine);
            debugPrint("[WorkoutSessionBloc] Routine stats update call finished for DB.");
          } else {
            debugPrint("[WorkoutSessionBloc] Warning: Routine ID $routineId not found for stats update. Session *was* saved successfully.");
          }
        } catch (routineError, routineStack) {
          debugPrint("[WorkoutSessionBloc] Error updating routine stats for ID $routineId (Session *was* saved): $routineError\n$routineStack");
        }
      } else {
        debugPrint("[WorkoutSessionBloc] Routine ID is null on the finished session, cannot update stats.");
      }
      // --- End Routine Update ---

      // --- 3. Emit Final Success State ---
      emit(state.copyWith(
        isLoading: false, isFinished: true, session: finishedSession,
        displayDuration: finalDuration, errorMessage: null,
      ));
      debugPrint("[WorkoutSessionBloc] Finish attempt successful. Final State Emitted.");

    } catch (e, s) {
      // Handles errors primarily from dbProvider.saveWorkoutSession
      debugPrint("[WorkoutSessionBloc] CRITICAL Error during session save process: $e\n$s");
      emit(state.copyWith(
        isLoading: false, isFinished: false, session: currentSession,
        errorMessage: "Failed to save workout session data. Please try again.",
      ));
    } finally {
      // --- 4. Reload All Sessions (CRITICAL FOR CALENDAR UPDATE) ---
      debugPrint("[WorkoutSessionBloc] Finally block: Reloading all sessions for stream update...");
      _loadAllSessions();
    }
  } // End _onWorkoutSessionFinishAttempt

  void _onWorkoutSetActualWeightChanged(WorkoutSetActualWeightChanged event, Emitter<WorkoutSessionState> emit) {
    if (state.session == null || state.isFinished || state.isLoading) {
      debugPrint("[WorkoutSessionBloc] Ignoring SetActualWeightChanged: Invalid state.");
      return;
    }
    debugPrint("[WorkoutSessionBloc] Event: WorkoutSetActualWeightChanged - ExIdx: ${event.exerciseIndex}, SetIdx: ${event.setIndex}, Weight: ${event.actualWeight}");
    try {
      final currentSession = state.session!;
      final updatedExercises = List<ExercisePerformance>.from(
        currentSession.exercises.map((exPerf) => exPerf.copyWith(
          sets: List<SetPerformance>.from(exPerf.sets),
        )),
      );

      if (event.exerciseIndex < 0 || event.exerciseIndex >= updatedExercises.length) throw RangeError("Invalid exercise index: ${event.exerciseIndex}");
      final targetExercise = updatedExercises[event.exerciseIndex];
      if (event.setIndex < 0 || event.setIndex >= targetExercise.sets.length) throw RangeError("Invalid set index: ${event.setIndex}");

      final originalSet = targetExercise.sets[event.setIndex];
      final updatedSet = originalSet.copyWith(
        actualWeight: event.actualWeight,
      );
      targetExercise.sets[event.setIndex] = updatedSet;

      final updatedSession = currentSession.copyWith(exercises: updatedExercises);
      emit(state.copyWith(session: updatedSession, errorMessage: null));
      debugPrint("[WorkoutSessionBloc] Session state updated with changed actual weight.");
    } catch (e, s) {
      debugPrint("[WorkoutSessionBloc] Error updating actual weight: $e\n$s");
      emit(state.copyWith(errorMessage: "Failed to update actual weight: $e"));
    }
  }

  void _onWorkoutSetTargetWeightChanged(WorkoutSetTargetWeightChanged event, Emitter<WorkoutSessionState> emit) {
    if (state.session == null || state.isFinished || state.isLoading) {
      debugPrint("[WorkoutSessionBloc] Ignoring SetTargetWeightChanged: Invalid state.");
      return;
    }
    debugPrint("[WorkoutSessionBloc] Event: WorkoutSetTargetWeightChanged - ExIdx: ${event.exerciseIndex}, SetIdx: ${event.setIndex}, Weight: ${event.targetWeight}");
    try {
      final currentSession = state.session!;
      final updatedExercises = List<ExercisePerformance>.from(
        currentSession.exercises.map((exPerf) => exPerf.copyWith(
          sets: List<SetPerformance>.from(exPerf.sets),
        )),
      );

      if (event.exerciseIndex < 0 || event.exerciseIndex >= updatedExercises.length) throw RangeError("Invalid exercise index: ${event.exerciseIndex}");
      final targetExercise = updatedExercises[event.exerciseIndex];
      if (event.setIndex < 0 || event.setIndex >= targetExercise.sets.length) throw RangeError("Invalid set index: ${event.setIndex}");

      final originalSet = targetExercise.sets[event.setIndex];
      final updatedSet = originalSet.copyWith(
        targetWeight: event.targetWeight,
      );
      targetExercise.sets[event.setIndex] = updatedSet;

      final updatedSession = currentSession.copyWith(exercises: updatedExercises);
      emit(state.copyWith(session: updatedSession, errorMessage: null));
      debugPrint("[WorkoutSessionBloc] Session state updated with changed target weight.");
    } catch (e, s) {
      debugPrint("[WorkoutSessionBloc] Error updating target weight: $e\n$s");
      emit(state.copyWith(errorMessage: "Failed to update target weight: $e"));
    }
  }

  /// Handles the event to directly save a completed workout session.
  /// This is typically called from a page that manages its own session lifecycle
  /// and just needs to persist the final result.
  Future<void> _onWorkoutSessionSaveCompleted(WorkoutSessionSaveCompleted event, Emitter<WorkoutSessionState> emit) async {
    debugPrint("[WorkoutSessionBloc] Event: WorkoutSessionSaveCompleted for session ID: ${event.session.id}");
    // No need to emit loading state here as this is a direct save, UI might not be the main session page.
    // However, it's good practice if this BLoC's state is observed for global loading.
    // For simplicity now, directly save and reload.

    try {
      // 1. Ensure the session is marked completed and has an end time (caller should ensure this)
      if (!event.session.isCompleted || event.session.endTime == null) {
        debugPrint("[WorkoutSessionBloc] Warning: WorkoutSessionSaveCompleted called with a session not marked as completed or missing endTime.");
        // Optionally, force completion here, or throw error
      }

      // 2. Attempt to Save Session to DB
      debugPrint("[WorkoutSessionBloc] Attempting to save provided completed session to DB (ID: ${event.session.id})...");
      await dbProvider.saveWorkoutSession(event.session);
      debugPrint("[WorkoutSessionBloc] Provided completed session saved successfully to DB.");

      // Note: We are NOT updating routine stats here. That's assumed to be handled
      // by the calling context (e.g., RoutineStepPage calling RoutinesBloc directly).
      // This event is purely for persisting the WorkoutSession object.

    } catch (e, s) {
      debugPrint("[WorkoutSessionBloc] CRITICAL Error during direct session save: $e\n$s");
      // Optionally emit an error state if this BLoC's state is relevant to the caller
      // emit(state.copyWith(errorMessage: "Failed to save completed session."));
    } finally {
      // 3. Reload All Sessions (CRITICAL FOR CALENDAR UPDATE)
      debugPrint("[WorkoutSessionBloc] Finally block (SaveCompleted): Reloading all sessions for stream update...");
      _loadAllSessions();
    }
  }


  // --- Internal Timer Event Handlers ---
  void _onSessionTimerTicked(_SessionTimerTicked event, Emitter<WorkoutSessionState> emit) {
    if (state.session != null && !state.isResting && !state.isFinished && !state.isLoading) {
      final elapsed = DateTime.now().difference(state.session!.startTime);
      // Only emit if duration actually changed (avoids unnecessary rebuilds if paused/resumed quickly)
      if (elapsed.inSeconds != state.displayDuration.inSeconds) {
        emit(state.copyWith(displayDuration: elapsed));
      }
    } else {
      _sessionTimer?.cancel(); _sessionTimer = null; // Stop timer if state is invalid
    }
  }

  void _onRestTimerTicked(_RestTimerTicked event, Emitter<WorkoutSessionState> emit) {
    if (state.isResting) {
      emit(state.copyWith(displayDuration: event.remainingDuration));
    } else {
      _restTimer?.cancel(); _restTimer = null; // Stop timer if not resting
    }
  }

  void _onRestPeriodEnded(_RestPeriodEnded event, Emitter<WorkoutSessionState> emit) {
    if (state.isResting && state.session != null) {
      debugPrint("[WorkoutSessionBloc] Rest period ended.");
      final elapsed = DateTime.now().difference(state.session!.startTime);
      emit(state.copyWith(isResting: false, displayDuration: elapsed));
      _startSessionTimer(); // Restart the main timer
    }
  }

  // --- Timer Control Methods ---
  void _startSessionTimer() {
    if (state.session == null || _sessionTimer?.isActive == true || state.isResting || state.isFinished || state.isLoading) return;
    debugPrint("[WorkoutSessionBloc] Starting session timer.");
    _restTimer?.cancel(); _restTimer = null;
    final initialElapsed = DateTime.now().difference(state.session!.startTime);
    // Ensure correct initial time is emitted if needed
    if (state.displayDuration.inSeconds != initialElapsed.inSeconds) {
      emit(state.copyWith(displayDuration: initialElapsed));
    }
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) { add(_SessionTimerTicked()); });
  }

  void _startRestTimer(Duration restDuration) {
    if (state.session == null || !state.isResting) return;
    debugPrint("[WorkoutSessionBloc] Starting rest timer for $restDuration.");
    _sessionTimer?.cancel(); _sessionTimer = null;
    _restTimer?.cancel();
    
    // Immediately emit initial rest duration
    emit(state.copyWith(displayDuration: restDuration));
    
    Duration remaining = restDuration;
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!state.isResting) { 
        timer.cancel(); 
        _restTimer = null; 
        return; 
      } // Safety check
      
      remaining = remaining - const Duration(seconds: 1);
      if (remaining.isNegative) {
        remaining = Duration.zero;
      }
      
      // Directly emit state change for countdown
      emit(state.copyWith(displayDuration: remaining));
      
      if (remaining.inSeconds <= 0) {
        timer.cancel();
        _restTimer = null;
        add(_RestPeriodEnded());
      }
    });
  }

  void _onExerciseTimerTicked(_ExerciseTimerTicked event, Emitter<WorkoutSessionState> emit) {
    if (!state.isResting && state.session != null) {
      emit(state.copyWith(displayDuration: event.remainingDuration));
    } else {
      _exerciseTimer?.cancel();
      _exerciseTimer = null;
    }
  }

  void _onTimedExerciseEnded(_TimedExerciseEnded event, Emitter<WorkoutSessionState> emit) {
    if (state.session != null) {
      debugPrint("[WorkoutSessionBloc] Timed exercise ended.");
      
      // Mark the set as completed
      final currentSession = state.session!;
      final updatedExercises = List<ExercisePerformance>.from(currentSession.exercises);
      final exercise = updatedExercises[event.exerciseIndex];
      final updatedSet = exercise.sets[event.setIndex].copyWith(
        isCompleted: true,
        actualReps: 1, // For timed exercises, we use 1 rep to mark completion
      );
      exercise.sets[event.setIndex] = updatedSet;

      final updatedSession = currentSession.copyWith(exercises: updatedExercises);
      
      // Start rest period if needed
      Duration? restDuration = exercise.restPeriod;
      bool isLastSetOfExercise = event.setIndex == exercise.sets.length - 1;
      
      if (restDuration != null && restDuration.inSeconds > 0 && !isLastSetOfExercise) {
        debugPrint("[WorkoutSessionBloc] Starting rest period after timed exercise: $restDuration");
        emit(state.copyWith(
          session: updatedSession,
          isResting: true,
          displayDuration: restDuration
        ));
        _startRestTimer(restDuration);
      } else {
        final elapsed = DateTime.now().difference(state.session!.startTime);
        emit(state.copyWith(
          session: updatedSession,
          isResting: false,
          displayDuration: elapsed
        ));
        _startSessionTimer();
      }
    }
  }

  void _startExerciseTimer(Duration duration, int exerciseIndex, int setIndex) {
    _exerciseTimer?.cancel();
    
    Duration remaining = duration;
    _exerciseTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      remaining = remaining - const Duration(seconds: 1);
      if (remaining.isNegative) {
        remaining = Duration.zero;
      }
      
      add(_ExerciseTimerTicked(remaining));
      
      if (remaining.inSeconds <= 0) {
        timer.cancel();
        _exerciseTimer = null;
        add(_TimedExerciseEnded(exerciseIndex, setIndex));
      }
    });
  }

  void _cancelTimers() {
    debugPrint("[WorkoutSessionBloc] Cancelling timers.");
    _sessionTimer?.cancel(); _sessionTimer = null;
    _restTimer?.cancel(); _restTimer = null;
    _exerciseTimer?.cancel(); _exerciseTimer = null;
  }

  // --- Data Loading for Historical Sessions Stream ---
  Future<void> _loadAllSessions() async {
    debugPrint("[WorkoutSessionBloc] _loadAllSessions: Fetching all sessions from DB...");
    try {
      final sessions = await dbProvider.getWorkoutSessions();
      debugPrint("[WorkoutSessionBloc] _loadAllSessions: Retrieved ${sessions.length} sessions from DB.");
      if (!_allSessionsController.isClosed) {
        _allSessionsController.sink.add(sessions);
        debugPrint("[WorkoutSessionBloc] _loadAllSessions: Added ${sessions.length} sessions to stream controller.");
        if (sessions.isNotEmpty) {
          debugPrint("[WorkoutSessionBloc] Last session in loaded list: ID ${sessions.first.id}, EndTime ${sessions.first.endTime}, Completed ${sessions.first.isCompleted}");
        }
      } else {
        debugPrint("[WorkoutSessionBloc] _loadAllSessions: Stream controller is closed.");
      }
    } catch (e, s) {
      debugPrint("[WorkoutSessionBloc] CRITICAL Error loading all sessions: $e\n$s");
      if (!_allSessionsController.isClosed) {
        _allSessionsController.sink.addError(e, s);
      }
    }
  }

  // --- Cleanup ---
  @override
  Future<void> close() {
    debugPrint("[WorkoutSessionBloc] Closing...");
    _cancelTimers();
    _allSessionsController.close();
    return super.close();
  }
}
