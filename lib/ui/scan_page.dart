import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:provider/provider.dart'; // Import Provider

// Import local providers, bloc, models, and components
import 'package:workout_planner/resource/db_provider.dart'; // Provides global dbProvider
// Provides global firebaseProvider (though not directly used here after refactor)
import 'package:workout_planner/bloc/routines_bloc.dart'; // Your RxDart Bloc
import 'package:workout_planner/ui/components/routine_overview_card.dart'; // Assuming this widget exists and takes a Routine
import 'components/custom_snack_bars.dart'; // Keep if used, otherwise remove

// --- QR Scanner Placeholder ---
// ACTION REQUIRED: Add a QR Scanner package (e.g., mobile_scanner) to pubspec.yaml
// and implement the actual scanning logic in _scanQRCode()
// import 'package:mobile_scanner/mobile_scanner.dart'; // Example import

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final _textEditingController = TextEditingController();
  final Connectivity _connectivity = Connectivity();

  // State variables
  String? _scannedOrEnteredId; // Stores the raw ID string "-r..."
  Routine? _fetchedRoutine;   // Stores the successfully fetched routine
  bool _isLoading = false;     // Tracks loading state for Firestore fetch
  String? _errorMessage;     // Stores error message if fetch fails

  @override
  void dispose() {
    _textEditingController.dispose();
    super.dispose();
  }

  // --- Helper Methods ---

  /// Shows a simple SnackBar message.
  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar(); // Remove previous
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  /// Checks internet connectivity and shows a SnackBar if offline.
  Future<bool> _checkConnection() async {
    final connectivityResult = await _connectivity.checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      if (!mounted) return false;
      // Use custom SnackBar if available, otherwise default
      ScaffoldMessenger.of(context).showSnackBar(
          noNetworkSnackBar ?? // Use null-aware operator
              const SnackBar(content: Text('No Internet Connection'), backgroundColor: Colors.red)
      );
      return false;
    }
    return true;
  }

  /// Validates if the string looks like a shared routine ID ("-r...").
  bool _isValidRoutineIdFormat(String? id) {
    return id != null && id.startsWith('-r') && id.length > 2;
  }

  /// Fetches the routine from Firestore based on the ID and updates state.
  Future<void> _fetchAndSetRoutine(String? id) async {
    if (!_isValidRoutineIdFormat(id)) {
      setState(() {
        _scannedOrEnteredId = id; // Store invalid ID to potentially show error message
        _isLoading = false;
        _fetchedRoutine = null;
        _errorMessage = "Invalid Routine ID format.";
      });
      return;
    }

    // Only proceed if connected
    if (!await _checkConnection()) return;

    setState(() {
      _scannedOrEnteredId = id; // Store the potentially valid ID
      _isLoading = true;
      _fetchedRoutine = null;
      _errorMessage = null;
    });

    try {
      final routine = await _getRoutineFromFirestore(id!); // Call helper
      if (!mounted) return;
      setState(() {
        _fetchedRoutine = routine;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
        _fetchedRoutine = null; // Clear routine on error
      });
    }
  }

  /// Helper to get Routine data from Firestore.
  Future<Routine> _getRoutineFromFirestore(String firestoreId) async {
    // Note: firestoreId here is expected to be "-r..."
    final docId = firestoreId.replaceFirst("-r", "");
    if (docId.isEmpty) throw Exception('Invalid Routine ID provided.');

    debugPrint("Fetching routine from Firestore: userShares/$docId");

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection("userShares") // Make sure collection name is correct
          .doc(docId)
          .get();

      if (!snapshot.exists || snapshot.data() == null) {
        throw Exception('Shared routine not found.');
      }

      final data = snapshot.data()!;
      // Assuming the routine data is stored under a 'routine' field as JSON string
      final routineJsonStr = data['routine'] as String?;
      if (routineJsonStr == null || routineJsonStr.isEmpty) {
        throw Exception('Invalid or missing routine data in share.');
      }

      // Decode and parse the routine
      try {
        final routineMap = jsonDecode(routineJsonStr) as Map<String, dynamic>;
        // Let Routine.fromMap handle validation of internal structure
        final parsedRoutine = Routine.fromMap(routineMap);
        // Clear the ID from the shared routine before adding locally? Optional.
        // return parsedRoutine.copyWith(id: null);
        return parsedRoutine;
      } on FormatException catch (e) {
        debugPrint("JSON decoding error: $e");
        throw Exception('Shared routine data is corrupted.');
      } catch (e) {
        debugPrint("Routine parsing error: $e");
        throw Exception('Could not understand shared routine data.');
      }

    } on FirebaseException catch (e) {
      debugPrint("Firestore error: ${e.code} - ${e.message}");
      throw Exception('Could not reach shared routines (${e.code}).');
    } catch (e) {
      // Catch other potential errors
      debugPrint("Error fetching routine: $e");
      rethrow; // Rethrow other errors
    }
  }

  /// Adds the fetched routine to the local database.
  Future<void> _addRoutineToLocalDb() async {
    if (_fetchedRoutine == null) {
      _showSnackBar("No routine loaded to add.");
      return;
    }

    // Access the BLoC via context to potentially refresh later
    final routinesBlocInstance = context.read<RoutinesBloc>();

    try {
      // Make a copy without the original ID (if it had one)
      // so the local DB assigns a new one. Or handle ID collisions in newRoutine.
      final routineToAdd = _fetchedRoutine!.copyWith(id: null);

      // Use the global dbProvider instance (implements DbProviderInterface)
      await dbProvider.newRoutine(routineToAdd);

      // Show success feedback
      _showSnackBar('Routine "${_fetchedRoutine!.routineName}" added successfully!');

      // Refresh the main routines list BLoC (optional but good UX)
      await routinesBlocInstance.fetchAllRoutines();

      // Clear the fetched routine from the UI after adding
      setState(() {
        _fetchedRoutine = null;
        _scannedOrEnteredId = null; // Reset barcode display
        _errorMessage = null;
      });

    } catch (e) {
      debugPrint("Error adding routine to local DB: $e");
      _showSnackBar("Failed to add routine locally: ${e.toString()}");
    }
  }


  // --- UI Interaction Methods ---

  /// Opens a dialog for manual ID input.
  Future<void> _input() async {
    if (!await _checkConnection()) return;

    // Clear previous input and results
    _textEditingController.clear();
    setState(() {
      _scannedOrEnteredId = null;
      _fetchedRoutine = null;
      _isLoading = false;
      _errorMessage = null;
    });

    if (!mounted) return;
    await showDialog(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text("Enter Routine ID"),
            content: TextField(
              controller: _textEditingController,
              autofocus: true,
              decoration: const InputDecoration(
                  hintText: 'Paste shared routine ID here',
                  prefixText: "-r" // Show the expected prefix visually
              ),
              // Add input formatters if needed
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text("Cancel")),
              TextButton(
                  onPressed: () {
                    final enteredId = _textEditingController.text.trim();
                    Navigator.pop(dialogContext); // Close dialog first
                    if (enteredId.isNotEmpty) {
                      _fetchAndSetRoutine('-r$enteredId'); // Add prefix and fetch
                    }
                  },
                  child: const Text("Load")),
            ],
          );
        });
  }

  /// Initiates QR code scanning.
  Future<void> _scan() async {
    if (!await _checkConnection()) return;

    // Clear previous results
    setState(() {
      _scannedOrEnteredId = null;
      _fetchedRoutine = null;
      _isLoading = false;
      _errorMessage = null;
    });

    try {
      // --- ACTION REQUIRED: Replace with your QR Scanner implementation ---
      final String? barcodeResult = await _scanQRCodeWithPlaceholder(); // Call placeholder/actual scanner
      // --- End ACTION REQUIRED ---

      if (barcodeResult != null && barcodeResult.isNotEmpty) {
        if (!mounted) return;
        _fetchAndSetRoutine(barcodeResult); // Fetch using the scanned result
      } else {
        _showSnackBar("Scan cancelled or no code found.");
      }
    } catch (e) {
      debugPrint("Scan error: $e");
      if (!mounted) return;
      _showSnackBar('Failed to scan QR code: ${e.toString()}');
    }
  }

  // --- Placeholder for QR Scanning ---
  Future<String?> _scanQRCodeWithPlaceholder() async {
    debugPrint("QR Scan Action Triggered - Replace with actual scanner implementation!");
    _showSnackBar("QR Scanner not implemented yet.");
    // Example of how you might integrate mobile_scanner (add dependency first)
    /*
     if (!mounted) return null;
     final scannedValue = await Navigator.push<String?>(
       context,
       MaterialPageRoute(
         builder: (context) => Scaffold(
           appBar: AppBar(title: const Text('Scan QR Code')),
           body: MobileScanner(
             controller: MobileScannerController(facing: CameraFacing.back),
             onDetect: (capture) {
               final List<Barcode> barcodes = capture.barcodes;
               if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                  final String code = barcodes.first.rawValue!;
                  debugPrint('QR Code Found: $code');
                  // Pop with the result if it seems valid
                  if (_isValidRoutineIdFormat(code)) { // Optional pre-validation
                     Navigator.pop(context, code);
                  } else {
                     // Optionally show feedback about invalid code format
                  }
               }
             },
           ),
         ),
       ),
     );
     return scannedValue;
     */
    // Return null because no scanner is implemented
    return null;
  }

  // --- Build Method ---
  @override
  Widget build(BuildContext context) {
    // Access BLoC needed for adding the routine later
    // final routinesBlocInstance = context.read<RoutinesBloc>(); // Get BLoC instance

    return Scaffold(
      // key: scaffoldKey, // Usually not needed unless accessing Scaffold state
      appBar: AppBar(
        iconTheme: IconThemeData(
            color: Theme.of(context).colorScheme.onPrimary // Use theme color
        ),
        title: const Text('Add Shared Routine'),
        backgroundColor: Theme.of(context).primaryColor, // Theme app bar
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: Center(
        child: Padding( // Add overall padding
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start, // Align content top
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // --- Action Buttons ---
              ElevatedButton.icon(
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Enter Routine ID'),
                onPressed: _input, // Call internal method
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const Text('Scan QR Code'),
                onPressed: _scan, // Call internal method
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 24),

              // --- Result Area ---
              // Show Loading Indicator
              if (_isLoading)
                const Center(child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 32.0),
                  child: CircularProgressIndicator(),
                )),

              // Show Error Message
              if (_errorMessage != null && !_isLoading)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32.0),
                    child: Text(
                      'Error: $_errorMessage',
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

              // Show Invalid ID Format Message (specific case)
              if (!_isLoading && _errorMessage == null && _scannedOrEnteredId != null && !_isValidRoutineIdFormat(_scannedOrEnteredId))
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32.0),
                    child: Text(
                      'Invalid ID format entered/scanned.',
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

              // Show Fetched Routine Overview (if successful)
              if (_fetchedRoutine != null && !_isLoading && _errorMessage == null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text("Found Shared Routine:", style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    // Assuming RoutineOverview takes a Routine
                    RoutineOverview(routine: _fetchedRoutine!, isRecRoutine: true), // Pass fetched routine
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Add to My Routines'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700], // Distinct color
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _addRoutineToLocalDb, // Call internal method
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}