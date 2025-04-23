import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';
import 'package:workout_planner/models/workout_session.dart';
import 'package:workout_planner/resource/db_provider.dart';

class WorkoutSessionBloc {
  final BehaviorSubject<WorkoutSession?> _currentSession = BehaviorSubject();
  final BehaviorSubject<Duration> _timer = BehaviorSubject.seeded(Duration.zero);
  final BehaviorSubject<bool> _isResting = BehaviorSubject.seeded(false);
  final BehaviorSubject<List<WorkoutSession>> _allSessions = BehaviorSubject();
  
  Timer? _timerInstance;
  WorkoutSession? _session;

  // Stream getters
  Stream<WorkoutSession?> get currentSession => _currentSession.stream;
  Stream<Duration> get timer => _timer.stream;
  Stream<bool> get isResting => _isResting.stream;
  Stream<List<WorkoutSession>> get allSessions => _allSessions.stream;

  WorkoutSessionBloc() {
    if (kDebugMode) {
      print("Initializing WorkoutSessionBloc");
    }
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    try {
      if (kDebugMode) {
        print("Loading workout sessions from database");
      }
      final sessions = await dbProvider.getWorkoutSessions();
      if (kDebugMode) {
        print("Loaded ${sessions.length} sessions");
      }
      _allSessions.sink.add(sessions);
    } catch (e) {
      debugPrint('Error loading sessions: $e');
    }
  }

  void startNewSession(WorkoutSession session) {
    if (kDebugMode) {
      print("Starting new session for ${session.routine.routineName}");
      print("Current sessions count: ${_allSessions.valueOrNull?.length ?? 0}");
    }
    
    // Complete any existing session first
    if (_session != null && !_session!.isCompleted) {
      if (kDebugMode) {
        print("Completing previous session before starting new one");
      }
      _session!.endTime = DateTime.now();
      _session!.isCompleted = true;
      dbProvider.saveWorkoutSession(_session!);
    }

    _session = session;
    _currentSession.sink.add(session);
    _startTimer();
    
    // Reload all sessions to ensure we have latest data
    _loadSessions();
  }

  void _startTimer() {
    _timerInstance?.cancel();
    _timerInstance = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_session != null) {
        _timer.sink.add(_session!.duration);
      }
    });
  }

  void completeSet(int exerciseIndex, int setIndex, int reps, double weight) {
    if (_session == null) return;

    final exercise = _session!.exercises[exerciseIndex];
    final set = exercise.sets[setIndex];
    
    set.actualReps = reps;
    set.actualWeight = weight;
    set.isCompleted = true;

    _currentSession.sink.add(_session);
    _startRestPeriod(exercise.restPeriod);
  }

  void _startRestPeriod(Duration? duration) {
    if (duration == null) return;
    
    _isResting.sink.add(true);
    _timer.sink.add(duration);
    
    _timerInstance?.cancel();
    _timerInstance = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = _timer.value - const Duration(seconds: 1);
      _timer.sink.add(remaining);

      if (remaining.inSeconds <= 0) {
        timer.cancel();
        _isResting.sink.add(false);
        _startTimer();
      }
    });
  }

  Future<void> completeSession() async {
    if (_session == null) return;

    _session!.endTime = DateTime.now();
    _session!.isCompleted = true;
    _timerInstance?.cancel();

    try {
      if (kDebugMode) {
        print("Saving session for ${_session!.routine.routineName}");
        print("Session details:");
        print("- ID: ${_session!.id}");
        print("- Start: ${_session!.startTime}");
        print("- End: ${_session!.endTime}");
        print("- Exercises: ${_session!.exercises.length}");
      }
      
      await dbProvider.saveWorkoutSession(_session!);
      
      if (kDebugMode) {
        print("Session saved successfully");
        print("Verifying saved session...");
        final savedSession = await dbProvider.getWorkoutSessionById(_session!.id);
        if (savedSession != null) {
          print("Successfully retrieved saved session");
        } else {
          print("ERROR: Saved session not found!");
        }
      }
      
      await _loadSessions();
      _currentSession.sink.add(null);
    } catch (e) {
      debugPrint('Error saving session: $e');
      rethrow;
    }
  }

  void dispose() {
    _timerInstance?.cancel();
    _currentSession.close();
    _timer.close();
    _isResting.close();
    _allSessions.close();
  }
}

final workoutSessionBloc = WorkoutSessionBloc();
