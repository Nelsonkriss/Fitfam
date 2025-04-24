import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'; // Required for @immutable
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dumbbell_new/models/workout_session.dart';
import 'package:dumbbell_new/models/exercise_set.dart';
import 'package:dumbbell_new/models/routine.dart'; // Assuming needed for session creation/display
import 'package:dumbbell_new/models/workout_session.dart'; // Contains ExercisePerformance which replaces WorkoutSessionExercise
import 'package:dumbbell_new/resource/db_provider.dart'; // Assuming dbProvider is available

// --- 1. Define Events ---

abstract class WorkoutSessionEvent {}

// Event to initialize the bloc with a new session (typically from a routine)
class WorkoutSessionStarted extends WorkoutSessionEvent {
  final WorkoutSession session; // Pass the fully formed initial session
  WorkoutSessionStarted(this.session);
}

// Event to load an existing session (e.g., resuming or viewing history)
class WorkoutSessionLoadedById extends WorkoutSessionEvent {
  final String sessionId;
  WorkoutSessionLoadedById(this.sessionId);
}

// Event triggered when a set is completed by the user
class WorkoutSetCompleted extends WorkoutSessionEvent {
  final int exerciseIndex;
  final int setIndex;
  final int actualReps;
  final double actualWeight;

  WorkoutSetCompleted({
    required this.exerciseIndex,
    required this.setIndex,
    required this.actualReps,
    required this.actualWeight,
  });
}

// Event triggered when the user finishes the entire workout
class WorkoutSessionFinished extends WorkoutSessionEvent {
  // Optional: Add any final data if needed
}

// Internal event for timer ticks (main session timer)
class _SessionTimerTicked extends WorkoutSessionEvent {
  final Duration duration;
  _SessionTimerTicked(this.duration);
}

// Internal event for rest timer ticks
class _RestTimerTicked extends WorkoutSessionEvent {
  final Duration duration;
  _RestTimerTicked(this.duration);
}

// Internal event when rest period ends
class _RestPeriodEnded extends WorkoutSessionEvent {}

// --- 2. Define State ---

@immutable // Ensure state is immutable
class WorkoutSessionState {
  final WorkoutSession? session;
  final Duration currentDuration; // Represents overall time OR rest time remaining
  final bool isResting;
  final bool isLoading; // For loading/saving operations
  final bool isFinished; // Indicates if the session is complete (saved, timer stopped)
  final String? error;

  const WorkoutSessionState({
    this.session,
    this.currentDuration = Duration.zero,
    this.isResting = false,
    this.isLoading = false,
    this.isFinished = false,
    this.error,
  });

  // Helper to calculate elapsed time ONLY if session is active and not finished
  Duration get elapsedSessionTime {
    if (session != null && !isFinished) {
      // If resting, elapsed time doesn't change, show overall time from session start
      if (isResting) {
        return DateTime.now().difference(session!.startTime);
      }
      // If actively working out, use the tracked currentDuration
      // This assumes currentDuration reflects total time when not resting
      // Alternatively, calculate based on startTime if _SessionTimerTicked updates based on that
      return currentDuration; // Or calculate: DateTime.now().difference(session!.startTime);
    }
    return currentDuration; // Return stored duration if finished or no session
  }


  WorkoutSessionState copyWith({
    WorkoutSession? session,
    Duration? currentDuration,
    bool? isResting,
    bool? isLoading,
    bool? isFinished,
    String? error,
    bool clearError = false, // Helper to easily clear errors
  }) {
    return WorkoutSessionState(
      // Use ?? operator carefully. If you want to explicitly set session to null, handle that.
      session: session ?? this.session,
      currentDuration: currentDuration ?? this.currentDuration,
      isResting: isResting ?? this.isResting,
      isLoading: isLoading ?? this.isLoading,
      isFinished: isFinished ?? this.isFinished,
      error: clearError ? null : error ?? this.error,
    );
  }
}

// --- 3. Implement the BLoC ---

class WorkoutSessionBloc extends Bloc<WorkoutSessionEvent, WorkoutSessionState> {
  StreamSubscription? _sessionTimerSubscription;
  StreamSubscription? _restTimerSubscription;
  // Assume dbProvider is injected or globally available
  // final DbProvider dbProvider; // Example if injecting

  WorkoutSessionBloc(/* {required this.dbProvider} */) : super(const WorkoutSessionState()) { // Start with initial empty state
    // Register handlers for each event
    on<WorkoutSessionStarted>(_onWorkoutSessionStarted);
    on<WorkoutSessionLoadedById>(_onWorkoutSessionLoadedById);
    on<WorkoutSetCompleted>(_onWorkoutSetCompleted);
    on<WorkoutSessionFinished>(_onWorkoutSessionFinished);

    // Internal event handlers
    on<_SessionTimerTicked>(_onSessionTimerTicked);
    on<_RestTimerTicked>(_onRestTimerTicked);
    on<_RestPeriodEnded>(_onRestPeriodEnded);
  }

  // --- Event Handlers ---

  void _onWorkoutSessionStarted(WorkoutSessionStarted event, Emitter<WorkoutSessionState> emit) {
    print("BLoC: Starting new session for ${event.session.routine.routineName}");
    // Ensure any previous timers are cancelled if starting fresh
    _cancelTimers();

    emit(state.copyWith(
      session: event.session,
      isLoading: false,
      isFinished: false,
      isResting: false,
      currentDuration: Duration.zero, // Reset duration
      error: null,
      clearError: true,
    ));
    _startSessionTimer();
  }

  Future<void> _onWorkoutSessionLoadedById(WorkoutSessionLoadedById event, Emitter<WorkoutSessionState> emit) async {
    print("BLoC: Loading session ID ${event.sessionId}");
    emit(state.copyWith(isLoading: true, error: null, clearError: true));
    _cancelTimers(); // Cancel any existing timers

    try {
      final session = await dbProvider.getWorkoutSessionById(event.sessionId);
      if (session != null) {
        print("BLoC: Session loaded successfully.");
        bool sessionIsFinished = session.isCompleted; // Assuming isCompleted field exists
        Duration initialDuration = Duration.zero;

        if (sessionIsFinished || session.endTime != null) {
          // Calculate final duration if finished
          initialDuration = session.endTime!.difference(session.startTime);
          print("BLoC: Loaded session is already finished. Duration: $initialDuration");
        } else {
          // Calculate current duration for an ongoing session (if resuming)
          // initialDuration = DateTime.now().difference(session.startTime);
          // Decide if timer should start automatically when loading an *ongoing* session
          // For simplicity here, we'll just load the data. Starting timer might need another event/logic.
          print("BLoC: Loaded session is ongoing. Start time: ${session.startTime}");
          // Let's set the initial duration to 0 and not start the timer automatically on load.
          // The UI might need a "Resume" button that dispatches a new event like 'WorkoutSessionResumed'.
          initialDuration = Duration.zero; // Or calculate from start time if needed immediately
        }

        emit(state.copyWith(
            session: session,
            isLoading: false,
            isFinished: sessionIsFinished,
            currentDuration: initialDuration, // Set duration based on loaded state
            isResting: false // Assume not resting when loading
        ));

        // Optional: Automatically start timer if it was an ongoing session?
        // if (!sessionIsFinished) {
        //   _startSessionTimer(); // Start timer if resuming an active session
        // }

      } else {
        print("BLoC: Error - Session ID ${event.sessionId} not found.");
        emit(state.copyWith(isLoading: false, error: "Workout session not found."));
      }
    } catch (e) {
      print("BLoC: Error loading session: $e");
      emit(state.copyWith(isLoading: false, error: "Failed to load workout session: $e"));
    }
  }


  void _onWorkoutSetCompleted(WorkoutSetCompleted event, Emitter<WorkoutSessionState> emit) {
    if (state.session == null || state.isFinished) return; // Ignore if no active session

    print("BLoC: Completing Set: Ex ${event.exerciseIndex}, Set ${event.setIndex}, Reps ${event.actualReps}, Weight ${event.actualWeight}");

    // --- Immutable Update Logic (from reference code) ---
    try {
      // 1. Copy the current session
      var updatedSession = state.session!;

      // 2. Create updated list of exercises
      final updatedExercises = List<WorkoutSessionExercise>.from(updatedSession.exercises);

      if (event.exerciseIndex < updatedExercises.length) {
        final exerciseToUpdate = updatedExercises[event.exerciseIndex];

        // 4. Create updated list of sets
        final updatedSets = List<ExerciseSet>.from(exerciseToUpdate.sets);

        if (event.setIndex < updatedSets.length) {
          final setToUpdate = updatedSets[event.setIndex];

          // 6. Create the updated set
          final updatedSet = setToUpdate.copyWith(
            actualReps: event.actualReps,
            actualWeight: event.actualWeight,
            isCompleted: true,
          );

          // 7. Replace the old set
          updatedSets[event.setIndex] = updatedSet;

          // 8. Create the updated exercise
          final updatedExercise = exerciseToUpdate.copyWith(sets: updatedSets);

          // 9. Replace the old exercise
          updatedExercises[event.exerciseIndex] = updatedExercise;

          // 10. Create the final updated session
          updatedSession = updatedSession.copyWith(exercises: updatedExercises);

          // 11. Emit the new state with the updated session
          emit(state.copyWith(session: updatedSession));

          // --- Handle Rest Period ---
          // Check if there's a rest period defined for this exercise
          Duration? restDuration = exerciseToUpdate.restPeriod; // Assuming 'restPeriod' exists on WorkoutSessionExercise

          // Check if this is the last set of the exercise (no rest needed after last set)
          bool isLastSet = event.setIndex == updatedSets.length - 1;

          if (restDuration != null && restDuration.inSeconds > 0 && !isLastSet) {
            print("BLoC: Starting rest period: $restDuration");
            _cancelTimers(); // Stop main session timer
            emit(state.copyWith(isResting: true, currentDuration: restDuration)); // Set state to resting, duration = rest time
            _startRestTimer(restDuration);
          } else {
            // If no rest or last set, ensure main timer is running (it might have been stopped by a previous rest)
            if (!(_sessionTimerSubscription?.isPaused == false) && !state.isFinished) {
              _startSessionTimer();
            }
          }

        } else {
          print("Error: Invalid set index ${event.setIndex}");
          emit(state.copyWith(error: "Internal error: Invalid set index."));
        }
      } else {
        print("Error: Invalid exercise index ${event.exerciseIndex}");
        emit(state.copyWith(error: "Internal error: Invalid exercise index."));
      }
    } catch (e) {
      print("Error updating set: $e");
      emit(state.copyWith(error: "Failed to update set: $e"));
    }
  }

  Future<void> _onWorkoutSessionFinished(WorkoutSessionFinished event, Emitter<WorkoutSessionState> emit) async {
    if (state.session == null || state.isFinished) return; // Ignore if no active session or already finished

    print("BLoC: Finishing session...");
    _cancelTimers(); // Stop all timers
    emit(state.copyWith(isLoading: true, isResting: false)); // Show loading, ensure not resting

    try {
      // Ensure end time and completion flag are set
      // Calculate final duration before saving
      final finalDuration = DateTime.now().difference(state.session!.startTime);
      final finishedSession = state.session!.copyWith(
        endTime: DateTime.now(),
        isCompleted: true, // Make sure your model supports this field/update
        // Optionally store the final duration if your model has a field for it
      );

      print("BLoC: Saving finished session (ID: ${finishedSession.id}). Final Duration: $finalDuration");
      await dbProvider.saveWorkoutSession(finishedSession);
      print("BLoC: Session saved successfully.");

      // Emit final state - keep session data for summary screen, mark as finished
      emit(state.copyWith(
        session: finishedSession,
        isLoading: false,
        isFinished: true,
        currentDuration: finalDuration, // Store final duration
      ));

    } catch (e) {
      print("BLoC: Error saving session: $e");
      emit(state.copyWith(isLoading: false, error: "Failed to save workout session: $e"));
      // Keep isFinished false if save failed? Or allow user to retry? Depends on desired UX.
      // Maybe restart timer if save fails? For now, we leave it stopped.
    }
  }

  // --- Internal Timer Handlers ---

  void _onSessionTimerTicked(_SessionTimerTicked event, Emitter<WorkoutSessionState> emit) {
    // Only update duration if the session is active, not resting, and not finished
    if (state.session != null && !state.isResting && !state.isFinished) {
      // Calculate elapsed time from start
      final elapsed = DateTime.now().difference(state.session!.startTime);
      emit(state.copyWith(currentDuration: elapsed));
    } else {
      // If state changed unexpectedly, stop the timer
      _sessionTimerSubscription?.cancel();
    }
  }

  void _onRestTimerTicked(_RestTimerTicked event, Emitter<WorkoutSessionState> emit) {
    // Only update if actually resting
    if (state.isResting) {
      emit(state.copyWith(currentDuration: event.duration));
    } else {
      // State changed (e.g., workout finished), cancel rest timer
      _restTimerSubscription?.cancel();
    }
  }

  void _onRestPeriodEnded(_RestPeriodEnded event, Emitter<WorkoutSessionState> emit) {
    print("BLoC: Rest period ended.");
    emit(state.copyWith(isResting: false, currentDuration: DateTime.now().difference(state.session!.startTime))); // Reset duration to elapsed time
    _startSessionTimer(); // Restart the main workout timer
  }


  // --- Timer Control ---

  void _startSessionTimer() {
    // Don't start if already running, finished, or session is null
    if (_sessionTimerSubscription != null || state.isFinished || state.session == null) return;

    print("BLoC: Starting session timer.");
    // Cancel rest timer just in case
    _restTimerSubscription?.cancel();
    _restTimerSubscription = null;

    // Calculate initial duration from start time
    final initialElapsed = DateTime.now().difference(state.session!.startTime);
    if(state.currentDuration != initialElapsed && !state.isResting){
      // Emit correct starting duration if needed (e.g., after rest)
      emit(state.copyWith(currentDuration: initialElapsed));
    }


    _sessionTimerSubscription = Stream.periodic(const Duration(seconds: 1))
        .listen((_) {
      // Add internal event instead of directly emitting
      // Calculate duration within the handler to ensure accuracy
      add(_SessionTimerTicked(Duration.zero)); // Duration passed here isn't used, calculated in handler
    });
  }

  void _startRestTimer(Duration restDuration) {
    // Ensure main timer is stopped and we are actually resting
    _sessionTimerSubscription?.cancel();
    _sessionTimerSubscription = null;
    if (!state.isResting) return; // Should be set before calling this

    _restTimerSubscription?.cancel(); // Cancel any previous rest timer

    Duration remaining = restDuration;
    _restTimerSubscription = Stream.periodic(const Duration(seconds: 1))
        .listen((_) {
      remaining = remaining - const Duration(seconds: 1);
      if (remaining.isNegative) remaining = Duration.zero; // Prevent negative duration

      add(_RestTimerTicked(remaining)); // Dispatch tick event

      if (remaining.inSeconds <= 0) {
        _restTimerSubscription?.cancel();
        _restTimerSubscription = null;
        add(_RestPeriodEnded()); // Dispatch rest ended event
      }
    });
  }

  void _cancelTimers() {
    print("BLoC: Cancelling timers.");
    _sessionTimerSubscription?.cancel();
    _sessionTimerSubscription = null;
    _restTimerSubscription?.cancel();
    _restTimerSubscription = null;
  }

  // --- Cleanup ---

  @override
  Future<void> close() {
    print("BLoC: Closing WorkoutSessionBloc.");
    _cancelTimers();
    return super.close();
  }
}