import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';
import 'package:workout_planner/models/routine.dart';
import 'package:workout_planner/models/main_targeted_body_part.dart';
import 'package:workout_planner/resource/db_provider.dart';
import 'package:workout_planner/resource/firebase_provider.dart';

export 'package:workout_planner/models/routine.dart';

enum UpdateType { parts }

class RoutinesBloc {
  // Stream controllers
  final BehaviorSubject<List<Routine>> _allRoutinesFetcher = BehaviorSubject<List<Routine>>();
  final BehaviorSubject<List<Routine>> _allRecRoutinesFetcher = BehaviorSubject<List<Routine>>();
  final BehaviorSubject<Routine?> _currentRoutineFetcher = BehaviorSubject<Routine?>();

  // Data stores
  List<Routine> _allRoutines = <Routine>[];
  List<Routine> _allRecRoutines = <Routine>[];
  Routine? _currentRoutine;

  // Stream getters
  Stream<Routine?> get currentRoutine => _currentRoutineFetcher.stream;
  Stream<List<Routine>> get allRoutines => _allRoutinesFetcher.stream;
  Stream<List<Routine>> get allRecRoutines => _allRecRoutinesFetcher.stream;
  List<Routine> get routines => _allRoutines;

  Future<void> fetchAllRoutines() async {
    try {
      if (kIsWeb) {
        _allRoutines = await firebaseProvider.restoreRoutines();
      } else {
        _allRoutines = await dbProvider.getAllRoutines();
      }
      if (!_allRoutinesFetcher.isClosed) {
        _allRoutinesFetcher.sink.add(_allRoutines);
      }
    } catch (exp) {
      if (!_allRoutinesFetcher.isClosed) {
        _allRoutinesFetcher.sink.addError(exp);
      }
      rethrow;
    }
  }

  Future<void> fetchAllRecRoutines() async {
    try {
      if (kIsWeb) {
        // For web, create some default recommended routines
        print('Creating default recommended routines for web');
        _allRecRoutines = [
          Routine(
            routineName: 'Push Day',
            mainTargetedBodyPart: MainTargetedBodyPart.Chest,
            parts: [
              Part(
                setType: SetType.Regular,
                targetedBodyPart: TargetedBodyPart.Chest,
                exercises: [
                  Exercise(name: 'Bench Press', sets: 4, reps: '8-12', weight: 0),
                  Exercise(name: 'Shoulder Press', sets: 3, reps: '10-12', weight: 0),
                  Exercise(name: 'Incline Dumbbell Press', sets: 3, reps: '10-12', weight: 0),
                  Exercise(name: 'Triceps Dips', sets: 3, reps: '12-15', weight: 0)
                ],
              )
              
            ],
            createdDate: DateTime.now(),
            weekdays: [],
            routineHistory: [],
            lastCompletedDate: DateTime.now(),
            completionCount: 0,
          ),
          Routine(
            routineName: 'Pull Day',
            mainTargetedBodyPart: MainTargetedBodyPart.Back,
            parts: [
              Part(
                setType: SetType.Regular,
                targetedBodyPart: TargetedBodyPart.Back,
                exercises: [
                  Exercise(name: 'Pull-ups', sets: 4, reps: '8-12', weight: 0),
                  Exercise(name: 'Bent Over Rows', sets: 3, reps: '10-12', weight: 0),
                  Exercise(name: 'Lat Pulldown', sets: 3, reps: '10-12', weight: 0),
                  Exercise(name: 'Bicep Curls', sets: 3, reps: '12-15', weight: 0)
                ],
              )
            ],
            createdDate: DateTime.now(),
            weekdays: [],
            routineHistory: [],
            lastCompletedDate: DateTime.now(),
            completionCount: 0,
          ),
          Routine(
            routineName: 'Leg Day',
            mainTargetedBodyPart: MainTargetedBodyPart.Leg,
            parts: [
              Part(
                setType: SetType.Regular,
                targetedBodyPart: TargetedBodyPart.Leg,
                exercises: [
                  Exercise(name: 'Squats', sets: 4, reps: '8-12', weight: 0),
                  Exercise(name: 'Romanian Deadlifts', sets: 3, reps: '8-10', weight: 0),
                  Exercise(name: 'Lunges', sets: 3, reps: '10-12', weight: 0),
                  Exercise(name: 'Leg Curls', sets: 3, reps: '12-15', weight: 0)
                ],
              )
            ],
            createdDate: DateTime.now(),
            weekdays: [],
            routineHistory: [],
            lastCompletedDate: DateTime.now(),
            completionCount: 0,
          )
        ];
      } else {
        print('Fetching recommended routines from database');
        _allRecRoutines = await dbProvider.getAllRecRoutines();
      }
      
      print('Loaded ${_allRecRoutines.length} recommended routines');
      if (!_allRecRoutinesFetcher.isClosed) {
        _allRecRoutinesFetcher.sink.add(_allRecRoutines);
      } else {
        print('Error: allRecRoutinesFetcher is closed');
      }
    } catch (exp) {
      if (!_allRecRoutinesFetcher.isClosed) {
        _allRecRoutinesFetcher.sink.addError(exp);
      }
      rethrow;
    }
  }

  Future<void> addRoutine(Routine routine) async {
    try {
      // Always create a deep copy to avoid reference sharing
      final routineToAdd = Routine.deepCopy(routine);
      
      print('Adding routine: ${routineToAdd.routineName}');
      final routineId = await dbProvider.newRoutine(routineToAdd);
      routineToAdd.id = routineId;
      print('Routine saved to DB with id: $routineId');
      
      // Create new list to preserve existing routines
      final updatedRoutines = List<Routine>.from(_allRoutines);
      updatedRoutines.add(routineToAdd);
      _allRoutines = updatedRoutines;
      
      print('Local routines list updated, now has ${_allRoutines.length} routines');
      
      if (!_allRoutinesFetcher.isClosed) {
        _allRoutinesFetcher.sink.add(_allRoutines);
        print('Routines stream updated');
      }
      
      // Sync to Firebase in background
      firebaseProvider.uploadRoutines(_allRoutines).then((_) {
        print('Routines synced to Firebase');
      }).catchError((e) {
        print("Firebase upload error: $e");
      });
      
      if (!_currentRoutineFetcher.isClosed) {
        _currentRoutineFetcher.sink.add(routine);
        print('Current routine stream updated');
      }
    } catch (e) {
      print("Error adding routine: $e");
      rethrow;
    }
  }

  Future<void> updateRoutine(Routine routine) async {
    try {
      debugPrint('Updating routine ${routine.routineName} (ID: ${routine.id})');
      
      // First try to find existing routine
      var index = _allRoutines.indexWhere((r) => r.id == routine.id);
      
      // If not found, try to add it
      if (index == -1) {
        debugPrint('Routine not found in local list, attempting to add');
        _allRoutines.add(Routine.deepCopy(routine));
        index = _allRoutines.length - 1;
      }

      // Create new list to ensure state update
      final updatedRoutines = List<Routine>.from(_allRoutines);
      updatedRoutines[index] = Routine.deepCopy(routine);
      _allRoutines = updatedRoutines;

      debugPrint('Local routine updated, now saving to database');
      if (routine.id != null) {
        await dbProvider.updateRoutine(routine);
      } else {
        routine.id = await dbProvider.newRoutine(routine);
      }
      debugPrint('Database update complete');
      
      debugPrint('Syncing to Firebase');
      await firebaseProvider.uploadRoutines(_allRoutines);
      debugPrint('Firebase sync complete');

      if (!_allRoutinesFetcher.isClosed) {
        debugPrint('Updating routines stream');
        _allRoutinesFetcher.sink.add(_allRoutines);
      }
      
      if (!_currentRoutineFetcher.isClosed) {
        debugPrint('Updating current routine stream');
        _currentRoutineFetcher.sink.add(routine);
      }
      
    } catch (e) {
      debugPrint("Error updating routine: $e");
      rethrow;
    }
  }

  Future<void> deleteRoutine({int? routineId, Routine? routine}) async {
    try {
      if (routineId == null && routine != null) {
        _allRoutines.removeWhere((r) => r.id == routine.id);
      } else if (routineId != null) {
        _allRoutines.removeWhere((r) => r.id == routineId);
      }

      if (!_allRoutinesFetcher.isClosed) {
        _allRoutinesFetcher.sink.add(_allRoutines);
      }

      final routineToDelete = routine ?? 
          (routineId != null ? _allRoutines.firstWhere((r) => r.id == routineId) : null);
      
      if (routineToDelete != null) {
        await dbProvider.deleteRoutine(routineToDelete);
      }
      
      await firebaseProvider.uploadRoutines(_allRoutines);
      
      if (!_currentRoutineFetcher.isClosed) {
        _currentRoutineFetcher.sink.add(null);
      }
    } catch (e) {
      print("Error deleting routine: $e");
      rethrow;
    }
  }

  Future<bool> restoreRoutines() async {
    try {
      final routines = await firebaseProvider.restoreRoutines();
      if (!kIsWeb) {
        await dbProvider.deleteAllRoutines();
        await dbProvider.addAllRoutines(routines);
      }
      _allRoutines = routines;
      if (!_allRoutinesFetcher.isClosed) {
        _allRoutinesFetcher.sink.add(_allRoutines);
      }
      return true;
    } catch (e) {
      if (kDebugMode) print('Error restoring routines: $e');
      return false;
    }
  }

  void setCurrentRoutine(Routine routine) {
    _currentRoutine = routine;
    if (!_currentRoutineFetcher.isClosed) {
      _currentRoutineFetcher.sink.add(_currentRoutine);
    }
  }

  void dispose() {
    _allRoutinesFetcher.close();
    _allRecRoutinesFetcher.close();
    _currentRoutineFetcher.close();
  }
}

final routinesBloc = RoutinesBloc();