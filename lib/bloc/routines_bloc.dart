import 'dart:async';
// import 'dart:convert'; // Keep if models require explicit JSON handling here
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:rxdart/rxdart.dart';
import 'package:workout_planner/models/routine.dart'; // Assuming Routine model is immutable with copyWith

// Import the INTERFACE and the global instance factory file
import 'package:workout_planner/resource/db_provider_interface.dart'; // Import the interface
import 'package:workout_planner/resource/db_provider.dart';      // Import the file with the global 'dbProvider' instance

// Import Firebase Provider (Uncomment if used)
// import 'package:workout_planner/resource/firebase_provider.dart';

// Export Routine model if needed elsewhere
export 'package:workout_planner/models/routine.dart';


/// BLoC responsible for managing the collection of user routines.
/// Provides streams for the list of routines and the currently selected routine.
/// Handles CRUD operations and fetching data from the database.
class RoutinesBloc {
  // --- Dependencies ---
  final DbProviderInterface _dbProvider = dbProvider; // Use global instance from db_provider.dart
  // final FirebaseProvider _firebaseProvider = firebaseProvider; // Uncomment if using Firebase for recommended routines

  // --- Stream Controllers ---
  // Holds the list of user's routines, seeded with empty list.
  final BehaviorSubject<List<Routine>> _allRoutinesFetcher =
  BehaviorSubject<List<Routine>>.seeded([]);
  // Holds the currently selected routine (for detail view etc.), seeded null.
  final BehaviorSubject<Routine?> _currentRoutineFetcher =
  BehaviorSubject<Routine?>.seeded(null);

  // --- Stream Getters (Public API for UI) ---
  /// Stream providing the latest list of all user routines.
  Stream<List<Routine>> get allRoutinesStream => _allRoutinesFetcher.stream;
  /// Stream providing the currently selected routine, or null if none selected.
  Stream<Routine?> get currentRoutineStream => _currentRoutineFetcher.stream;

  // --- Value Getters (for synchronous access if needed, use with caution) ---
  /// Gets the latest emitted list of user routines synchronously.
  List<Routine> get currentRoutinesList => _allRoutinesFetcher.value;
  /// Gets the latest emitted selected routine synchronously.
  Routine? get currentSelectedRoutine => _currentRoutineFetcher.value;

  // Constructor: Fetch initial data when the BLoC is created.
  RoutinesBloc() {
    debugPrint("[RoutinesBloc] Initializing...");
    fetchAllRoutines(); // Fetch routines on startup
    // fetchRecommendedRoutines(); // Uncomment if needed
  }

  // --- Public Methods (API for UI interaction) ---

  /// Fetches all user routines from the database and updates the `allRoutinesStream`.
  /// Call this explicitly from the UI (e.g., initState, RefreshIndicator) to refresh data.
  Future<void> fetchAllRoutines() async {
    debugPrint("[RoutinesBloc] Fetching all routines from DB...");
    try {
      List<Routine> routines = await _dbProvider.getAllRoutines();
      debugPrint("[RoutinesBloc] Fetched ${routines.length} routines from DB.");
      if (!_allRoutinesFetcher.isClosed) {
        _allRoutinesFetcher.sink.add(routines); // Update the stream
        debugPrint("[RoutinesBloc] Routines added to stream.");

        // Ensure the selected routine stream reflects the latest data
        _updateCurrentRoutineSelection(routines);
      } else {
        debugPrint("[RoutinesBloc] Cannot add routines, stream is closed.");
      }
    } catch (e, s) {
      debugPrint("[RoutinesBloc] Error fetching all routines: $e\n$s");
      if (!_allRoutinesFetcher.isClosed) {
        _allRoutinesFetcher.sink.addError("Failed to load routines.", s);
      }
    }
  }

  /// Adds a new routine to the database and updates the stream.
  Future<void> addRoutine(Routine routineToAdd) async {
    debugPrint("[RoutinesBloc] Adding new routine: ${routineToAdd.routineName}");
    try {
      // Let DB assign ID
      int newId = await _dbProvider.newRoutine(routineToAdd);
      // Create the final Routine object with the DB-assigned ID
      final routineWithId = routineToAdd.copyWith(id: newId);

      // Create a new list immutably and add the new routine
      final updatedList = List<Routine>.from(currentRoutinesList)..add(routineWithId);

      if (!_allRoutinesFetcher.isClosed) {
        _allRoutinesFetcher.sink.add(updatedList); // Update the stream
        debugPrint("[RoutinesBloc] Routine added successfully (ID: $newId). Stream updated.");
      }
    } catch (e, s) {
      debugPrint("[RoutinesBloc] Error adding routine: $e\n$s");
      if (!_allRoutinesFetcher.isClosed) {
        _allRoutinesFetcher.sink.addError("Failed to add routine.", s);
      }
    }
  }

  /// Updates an existing routine in the database and updates the stream.
  /// Note: This is for general routine property updates, not for completion stats.
  Future<void> updateRoutine(Routine routineToUpdate) async {
    if (routineToUpdate.id == null) {
      debugPrint("[RoutinesBloc] Error: Cannot update routine without an ID.");
      // Optionally add an error to the stream or throw
      return;
    }
    debugPrint("[RoutinesBloc] Updating routine ID: ${routineToUpdate.id}");
    try {
      // Update in the database first
      await _dbProvider.updateRoutine(routineToUpdate);
      debugPrint("[RoutinesBloc] Routine updated in DB.");

      // Create the updated list immutably using map
      final updatedList = currentRoutinesList.map((routine) {
        // If ID matches, use the updated routine object, otherwise keep the old one
        return routine.id == routineToUpdate.id ? routineToUpdate : routine;
      }).toList(); // Collect results into a new list

      if (!_allRoutinesFetcher.isClosed) {
        _allRoutinesFetcher.sink.add(updatedList); // Update the main routines stream
        debugPrint("[RoutinesBloc] Routine stream updated.");

        // If the updated routine was the currently selected one, update that stream too
        if (currentSelectedRoutine?.id == routineToUpdate.id) {
          if(!_currentRoutineFetcher.isClosed) {
            _currentRoutineFetcher.sink.add(routineToUpdate);
            debugPrint("[RoutinesBloc] Selected routine stream updated.");
          }
        }
      }
    } catch (e, s) {
      debugPrint("[RoutinesBloc] Error updating routine ${routineToUpdate.id}: $e\n$s");
      if (!_allRoutinesFetcher.isClosed) {
        _allRoutinesFetcher.sink.addError("Failed to update routine.", s);
      }
    }
  }

  /// Deletes a routine by its ID from the database and updates the stream.
  Future<void> deleteRoutine(int routineId) async {
    debugPrint("[RoutinesBloc] Deleting routine ID: $routineId");
    Routine? routineToDelete;
    try {
      // Find the routine object in the current list to pass to DB if needed by provider interface
      // Although DBProviderIO only needs the ID, this ensures it exists in current state.
      routineToDelete = currentRoutinesList.firstWhere((r) => r.id == routineId);
    } on StateError {
      // Catch specific error if routine ID doesn't exist in the current list
      debugPrint("[RoutinesBloc] Routine ID $routineId not found in list for deletion.");
      if (!_allRoutinesFetcher.isClosed) {
        _allRoutinesFetcher.sink.addError("Routine to delete was not found in the current list.");
      }
      return; // Stop if not found
    } catch (e, s) {
      debugPrint("[RoutinesBloc] Error finding routine $routineId for deletion: $e\n$s");
      if (!_allRoutinesFetcher.isClosed) {
        _allRoutinesFetcher.sink.addError("Failed to find routine for deletion.", s);
      }
      return;
    }

    // Proceed with deletion from the database
    try {
      await _dbProvider.deleteRoutine(routineToDelete); // Pass the Routine object (or just ID if interface allows)
      debugPrint("[RoutinesBloc] Routine deleted from DB (ID: $routineId).");

      // Create the updated list immutably by filtering
      final updatedList = currentRoutinesList
          .where((routine) => routine.id != routineId)
          .toList(); // Collect results into a new list

      if (!_allRoutinesFetcher.isClosed) {
        _allRoutinesFetcher.sink.add(updatedList); // Update the main routines stream
        debugPrint("[RoutinesBloc] Routine stream updated after deletion.");

        // If the deleted routine was the currently selected one, clear selection
        if (currentSelectedRoutine?.id == routineId) {
          if(!_currentRoutineFetcher.isClosed) {
            _currentRoutineFetcher.sink.add(null);
            debugPrint("[RoutinesBloc] Cleared selected routine stream.");
          }
        }
      }
    } catch (e, s) {
      // Catch errors during the actual DB deletion
      debugPrint("[RoutinesBloc] Error deleting routine $routineId from DB: $e\n$s");
      if (!_allRoutinesFetcher.isClosed) {
        _allRoutinesFetcher.sink.addError("Failed to delete routine from storage.", s);
      }
    }
  }

  /// Updates the currently selected routine stream based on ID.
  void selectRoutine(int? routineId) {
    if (_currentRoutineFetcher.isClosed) return;

    if (routineId == null) {
      // Clear selection
      _currentRoutineFetcher.sink.add(null);
      debugPrint("[RoutinesBloc] Selection cleared.");
    } else {
      try {
        // Find the routine in the latest list from the stream.
        Routine selected = currentRoutinesList.firstWhere((r) => r.id == routineId);
        // Update the stream with the found routine
        _currentRoutineFetcher.sink.add(selected);
        debugPrint("[RoutinesBloc] Selected routine ID: $routineId.");
      } on StateError {
        // Handle case where the ID is not found in the current list
        debugPrint("[RoutinesBloc] Warning - Routine ID $routineId not found in current list for selection.");
        _currentRoutineFetcher.sink.add(null); // Sink null if not found
      } catch (e, s) {
        // Catch any other errors during find/selection
        debugPrint("[RoutinesBloc] Error during selectRoutine for ID $routineId: $e\n$s");
        _currentRoutineFetcher.sink.add(null); // Sink null on other errors
      }
    }
  }

  /// Helper to update the selected routine stream after a full fetch.
  void _updateCurrentRoutineSelection(List<Routine> newList) {
    if (currentSelectedRoutine != null && !_currentRoutineFetcher.isClosed) {
      final currentId = currentSelectedRoutine!.id;
      // Find the routine with the same ID in the newly fetched list
      final updatedSelection = newList.firstWhereOrNull((r) => r.id == currentId);

      if (updatedSelection != null) {
        // If found, check if it's actually different object/data than current selection
        if (updatedSelection != currentSelectedRoutine) {
          _currentRoutineFetcher.sink.add(updatedSelection);
          debugPrint("[RoutinesBloc] Refreshed selected routine stream after fetch.");
        }
      } else {
        // If the previously selected routine ID no longer exists, clear selection
        _currentRoutineFetcher.sink.add(null);
        debugPrint("[RoutinesBloc] Cleared selection after fetch - routine no longer exists.");
      }
    }
  }


  // --- Recommended Routines (Placeholder/Example - Uncomment if needed) ---

  final BehaviorSubject<List<Routine>> _allRecRoutinesFetcher = BehaviorSubject<List<Routine>>.seeded([]);
  Stream<List<Routine>> get allRecommendedRoutinesStream => _allRecRoutinesFetcher.stream;

  Future<void> fetchRecommendedRoutines() async {
    debugPrint("[RoutinesBloc] Fetching recommended routines...");
    try {
      // *** Requires getRecommendedRoutines() to be defined in FirebaseProvider ***
      // List<Routine> recRoutines = await _firebaseProvider.getRecommendedRoutines();
      // if (!_allRecRoutinesFetcher.isClosed) {
      //    _allRecRoutinesFetcher.sink.add(recRoutines);
      // }
    } catch (e, s) {
       if (e is NoSuchMethodError) {
          debugPrint("[RoutinesBloc] Error - 'getRecommendedRoutines' method not found in FirebaseProvider.");
          if (!_allRecRoutinesFetcher.isClosed) _allRecRoutinesFetcher.sink.addError("Recommended routines feature not available.");
       } else {
          debugPrint("[RoutinesBloc] Error fetching recommended routines: $e\n$s");
          if (!_allRecRoutinesFetcher.isClosed) _allRecRoutinesFetcher.sink.addError("Failed to load recommended routines.");
       }
       // Optionally sink empty list on error
       // if (!_allRecRoutinesFetcher.isClosed) _allRecRoutinesFetcher.sink.add([]);
    }
  }


  // --- Cleanup ---
  /// Closes all stream controllers. Should be called when the BLoC is no longer needed
  /// (e.g., in the `dispose` method of a StatefulWidget holding the BLoC provider).
  void dispose() {
    debugPrint("[RoutinesBloc] Disposing streams.");
    _allRoutinesFetcher.close();
    _currentRoutineFetcher.close();
    // _allRecRoutinesFetcher.close(); // Uncomment if used
  }
}

// Helper extension used by _updateCurrentRoutineSelection
extension FirstWhereOrNullExtension<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E) test) {
    for (E element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}