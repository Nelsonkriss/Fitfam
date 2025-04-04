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
        _allRecRoutines = [
          Routine(
            routineName: 'Full Body Starter',
            mainTargetedBodyPart: MainTargetedBodyPart.FullBody,
            parts: [
              Part(
                setType: SetType.Regular,
                targetedBodyPart: TargetedBodyPart.FullBody,
                exercises: [
                  Exercise(name: 'Squats', sets: 3, reps: '10', weight: 0),
                  Exercise(name: 'Push-ups', sets: 3, reps: '10', weight: 0),
                  Exercise(name: 'Plank', sets: 3, reps: '0', weight: 0)
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
            routineName: 'Upper Body Focus',
            mainTargetedBodyPart: MainTargetedBodyPart.Chest,
            parts: [
              Part(
                setType: SetType.Regular,
                targetedBodyPart: TargetedBodyPart.Chest,
                exercises: [
                  Exercise(name: 'Push-ups', sets: 4, reps: '12', weight: 0),
                  Exercise(name: 'Dips', sets: 3, reps: '10', weight: 0),
                  Exercise(name: 'Pull-ups', sets: 3, reps: '8', weight: 0)
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
        _allRecRoutines = await dbProvider.getAllRecRoutines();
      }
      
      if (!_allRecRoutinesFetcher.isClosed) {
        _allRecRoutinesFetcher.sink.add(_allRecRoutines);
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
      // Deep copy template routines to avoid sharing references
      final routineToAdd = routine.id == null ?
        Routine.deepCopy(routine) :
        routine;

      print('Adding routine: ${routineToAdd.routineName}');
      final routineId = await dbProvider.newRoutine(routineToAdd);
      routineToAdd.id = routineId;
      print('Routine saved to DB with id: $routineId');
      
      // Update local list first for immediate UI update
      _allRoutines.add(routineToAdd);
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
      final index = _allRoutines.indexWhere((r) => r.id == routine.id);
      if (index != -1) {
        _allRoutines[index] = Routine.deepCopy(routine);
        await dbProvider.updateRoutine(routine);
        await firebaseProvider.uploadRoutines(_allRoutines);
        if (!_allRoutinesFetcher.isClosed) {
          _allRoutinesFetcher.sink.add(_allRoutines);
        }
        if (!_currentRoutineFetcher.isClosed) {
          _currentRoutineFetcher.sink.add(routine);
        }
      }
    } catch (e) {
      print("Error updating routine: $e");
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