import 'dart:async';
import 'package:flutter/foundation.dart'; // Required for kDebugMode or assertions
import 'package:rxdart/rxdart.dart';
import 'package:workout_planner/models/routine.dart';
// Keep if needed

// Import the INTERFACE and the global instance factory file
import 'package:workout_planner/resource/db_provider_interface.dart'; // Import the interface
import 'package:workout_planner/resource/db_provider.dart';      // Import the file with the global 'dbProvider' instance

// Import Firebase Provider (Make sure this path is correct)
import 'package:workout_planner/resource/firebase_provider.dart';

export 'package:workout_planner/models/routine.dart'; // Keep export if used elsewhere

/// BLoC responsible for managing user routines and recommended routines
/// using the RxDart pattern (BehaviorSubject).
class RoutinesBloc {
  // --- Dependencies ---
  // Use the globally created instance typed as the interface
  final DbProviderInterface _dbProvider = dbProvider;

  // Assume FirebaseProvider is correctly instantiated or provided globally
  final FirebaseProvider _firebaseProvider = firebaseProvider;

  // --- Stream controllers ---
  // Holds the list of user's routines, seeded with empty list.
  final BehaviorSubject<List<Routine>> _allRoutinesFetcher = BehaviorSubject<List<Routine>>.seeded([]);
  // Holds the list of recommended routines, seeded with empty list.
  final BehaviorSubject<List<Routine>> _allRecRoutinesFetcher = BehaviorSubject<List<Routine>>.seeded([]);
  // Holds the currently selected routine (for detail view etc.), seeded null.
  final BehaviorSubject<Routine?> _currentRoutineFetcher = BehaviorSubject<Routine?>.seeded(null);

  // --- Stream getters (for UI consumption) ---
  Stream<Routine?> get currentRoutineStream => _currentRoutineFetcher.stream;
  Stream<List<Routine>> get allRoutinesStream => _allRoutinesFetcher.stream;
  Stream<List<Routine>> get allRecommendedRoutinesStream => _allRecRoutinesFetcher.stream;

  // --- Value getters (for internal BLoC logic) ---
  /// Gets the latest emitted list of user routines.
  List<Routine> get currentRoutinesList => _allRoutinesFetcher.value;
  /// Gets the latest emitted selected routine.
  Routine? get currentSelectedRoutine => _currentRoutineFetcher.value;


  // --- Public Methods (API for UI interaction) ---

  /// Fetches all user routines from the database and updates the stream.
  Future<void> fetchAllRoutines() async {
    try {
      List<Routine> routines = await _dbProvider.getAllRoutines();
      _allRoutinesFetcher.sink.add(routines);
    } catch (e) {
      debugPrint("RoutinesBloc: Error fetching all routines: $e");
      _allRoutinesFetcher.sink.addError("Failed to load routines.");
      // Optionally emit empty list on error? Current behavior keeps last good state or initial seed.
    }
  }

  /// Fetches recommended routines from the Firebase provider and updates the stream.
  Future<void> fetchRecommendedRoutines() async {
    try {
      // *** Requires getRecommendedRoutines() to be defined in FirebaseProvider ***
      List<Routine> recRoutines = await _firebaseProvider.getRecommendedRoutines();
      _allRecRoutinesFetcher.sink.add(recRoutines);
    } catch (e) {
      if (e is NoSuchMethodError) {
        // This specific error means the method isn't implemented in FirebaseProvider
        debugPrint("RoutinesBloc: Error - 'getRecommendedRoutines' method not found in FirebaseProvider. Ensure it's defined.");
        _allRecRoutinesFetcher.sink.addError("Recommended routines feature not available.");
      } else {
        // General error during fetch
        debugPrint("RoutinesBloc: Error fetching recommended routines: $e");
        _allRecRoutinesFetcher.sink.addError("Failed to load recommended routines.");
      }
      // Sink empty list on error to clear previous recommendations if desired
      _allRecRoutinesFetcher.sink.add([]);
    }
  }

  /// Adds a new routine to the database and updates the stream.
  Future<void> addRoutine(Routine routineToAdd) async {
    try {
      // Call DB method which returns the new ID
      int newId = await _dbProvider.newRoutine(routineToAdd);
      // Create the final Routine object with the DB-assigned ID
      // Assumes Routine model has a copyWith method.
      final routineWithId = routineToAdd.copyWith(id: newId);

      // Create a new list immutably
      final updatedList = List<Routine>.from(currentRoutinesList)..add(routineWithId);
      // Update the stream
      _allRoutinesFetcher.sink.add(updatedList);
    } catch (e) {
      debugPrint("RoutinesBloc: Error adding routine: $e");
      _allRoutinesFetcher.sink.addError("Failed to add routine.");
    }
  }

  /// Updates an existing routine in the database and updates the stream.
  Future<void> updateRoutine(Routine routineToUpdate) async {
    // Ensure the routine has an ID for updating
    if (routineToUpdate.id == null) {
      debugPrint("RoutinesBloc: Error - Cannot update routine without an ID.");
      _allRoutinesFetcher.sink.addError("Cannot update routine without an ID.");
      return;
    }
    try {
      // Update in the database
      await _dbProvider.updateRoutine(routineToUpdate);

      // Create the updated list immutably using map
      final updatedList = currentRoutinesList.map((routine) {
        // If ID matches, use the updated routine object, otherwise keep the old one
        return routine.id == routineToUpdate.id ? routineToUpdate : routine;
      }).toList(); // Collect results into a new list

      // Update the main routines stream
      _allRoutinesFetcher.sink.add(updatedList);

      // If the updated routine was the currently selected one, update that stream too
      if (currentSelectedRoutine?.id == routineToUpdate.id) {
        _currentRoutineFetcher.sink.add(routineToUpdate);
      }
    } catch (e) {
      debugPrint("RoutinesBloc: Error updating routine ${routineToUpdate.id}: $e");
      _allRoutinesFetcher.sink.addError("Failed to update routine.");
    }
  }

  /// Deletes a routine by its ID from the database and updates the stream.
  Future<void> deleteRoutine(int routineId) async {
    Routine? routineToDelete;
    try {
      // Find the routine object in the current list. Throws StateError if not found.
      // This is necessary if _dbProvider.deleteRoutine expects the full object.
      routineToDelete = currentRoutinesList.firstWhere((r) => r.id == routineId);
    } on StateError {
      // Catch specific error if routine ID doesn't exist in the current list
      debugPrint("RoutinesBloc: Routine ID $routineId not found in list for deletion.");
      _allRoutinesFetcher.sink.addError("Routine to delete was not found.");
      return; // Stop if not found
    } catch (e) {
      // Catch other potential errors during the find operation
      debugPrint("RoutinesBloc: Error finding routine $routineId for deletion: $e");
      _allRoutinesFetcher.sink.addError("Failed to find routine for deletion.");
      return;
    }

    // Proceed with deletion from the database
    try {
      await _dbProvider.deleteRoutine(routineToDelete); // Pass the Routine object

      // Create the updated list immutably by filtering
      final updatedList = currentRoutinesList
          .where((routine) => routine.id != routineId)
          .toList(); // Collect results into a new list

      // Update the main routines stream
      _allRoutinesFetcher.sink.add(updatedList);

      // If the deleted routine was the currently selected one, clear selection
      if (currentSelectedRoutine?.id == routineId) {
        _currentRoutineFetcher.sink.add(null);
      }
    } catch (e) {
      // Catch errors during the actual DB deletion
      debugPrint("RoutinesBloc: Error deleting routine $routineId from DB: $e");
      _allRoutinesFetcher.sink.addError("Failed to delete routine from storage.");
    }
  }

  /// Updates the currently selected routine stream.
  void selectRoutine(int? routineId) {
    if (routineId == null) {
      // Clear selection
      _currentRoutineFetcher.sink.add(null);
    } else {
      try {
        // Find the routine in the latest list. Throws StateError if not found.
        Routine selected = currentRoutinesList.firstWhere((r) => r.id == routineId);
        // Update the stream with the found routine
        _currentRoutineFetcher.sink.add(selected);
      } on StateError {
        // Handle case where the ID is not found in the current list
        debugPrint("RoutinesBloc: Warning - Routine ID $routineId not found in current list for selection.");
        _currentRoutineFetcher.sink.add(null); // Sink null if not found
      } catch (e) {
        // Catch any other errors during find/selection
        debugPrint("RoutinesBloc: Error during selectRoutine for ID $routineId: $e");
        _currentRoutineFetcher.sink.add(null); // Sink null on other errors
      }
    }
  }


  /// Closes all stream controllers. Should be called when the BLoC is no longer needed.
  void dispose() {
    debugPrint("RoutinesBloc: Disposing streams.");
    _allRoutinesFetcher.close();
    _allRecRoutinesFetcher.close();
    _currentRoutineFetcher.close();
  }
}