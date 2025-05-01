import 'dart:async';
import 'dart:convert';
// Keep if RepaintBoundary needs it implicitly

import 'package:flutter/cupertino.dart';
// Keep if needed by dependencies
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
// import 'package:flutter/rendering.dart'; // Not directly used here
import 'package:provider/provider.dart'; // Import Provider
// import 'package:permission_handler/permission_handler.dart'; // Keep if used for saving QR
// import 'package:image_gallery_saver/image_gallery_saver.dart'; // Keep if used for saving QR

// Import local providers, bloc, models, components, utils (ADJUST PATHS AS NEEDED)
import 'package:workout_planner/resource/firebase_provider.dart';
import 'package:workout_planner/utils/routine_helpers.dart';
import 'package:workout_planner/ui/components/part_card.dart';
import 'package:workout_planner/ui/part_history_page.dart';
import 'package:workout_planner/ui/routine_edit_page.dart';
import 'package:workout_planner/ui/routine_step_page.dart';
import 'package:workout_planner/ui/components/custom_snack_bars.dart'; // Optional
import 'package:workout_planner/bloc/routines_bloc.dart'; // Your RxDart BLoC

class RoutineDetailPage extends StatefulWidget {
  final bool isRecRoutine;

  const RoutineDetailPage({super.key, this.isRecRoutine = false});

  @override
  State<RoutineDetailPage> createState() => _RoutineDetailPageState();
}

class _RoutineDetailPageState extends State<RoutineDetailPage> {
  // Keys and Controllers
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _globalKeyQrCode = GlobalKey(); // Key for QR RepaintBoundary

  // State
  late String _shareDataString; // Unique ID string ("-r...") for sharing

  @override
  void initState() {
    super.initState();
    // Generate a unique ID string prefixed with '-r' for sharing purposes.
    _shareDataString = '-r${FirebaseProvider.generateId()}';
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // --- Helper Methods ---

  /// Shows a simple SnackBar message.
  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.redAccent : null,
          duration: const Duration(seconds: 3)
      ),
    );
  }

  /// Checks internet connectivity and shows a SnackBar if offline.
  Future<bool> _checkConnection() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      if (!mounted) return false;
      // Use custom snackbar if defined, otherwise default
      ScaffoldMessenger.of(context).showSnackBar(
          noNetworkSnackBar ?? // Use custom snackbar if available
              const SnackBar(content: Text('No Internet Connection'), backgroundColor: Colors.red)
      );
      return false;
    }
    return true;
  }

  /// Formats a date to 'YYYY-MM-DD'.
  String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    // Access the BLoC instance provided higher up
    // Use watch() so the page rebuilds when the selected routine changes
    final routinesBlocInstance = context.watch<RoutinesBloc>();

    return StreamBuilder<Routine?>(
      // Listen to the stream for the currently selected routine
      stream: routinesBlocInstance.currentRoutineStream,
      builder: (context, snapshot) {
        final Routine? currentRoutine = snapshot.data; // The routine from the stream

        // Handle loading/no data state
        if (snapshot.connectionState == ConnectionState.waiting && currentRoutine == null) {
          return Scaffold(
            appBar: AppBar(title: const Text("Loading...")),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        // Handle case where routine is null (e.g., selection cleared, initial state)
        if (currentRoutine == null) {
          return Scaffold(
            appBar: AppBar(title: const Text("No Routine Selected")),
            body: const Center(child: Text('Please select or create a routine.')),
          );
        }

        // Routine data is available, build the main UI
        return Scaffold(
          key: _scaffoldKey,
          appBar: AppBar(
            centerTitle: true,
            title: Text(
              mainTargetedBodyPartToStringConverter(currentRoutine.mainTargetedBodyPart),
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            // Build actions dynamically based on routine type and data
            actions: _buildAppBarActions(context, currentRoutine),
          ),
          // Body contains header card and list of part cards
          body: ListView(
              controller: _scrollController,
              children: _buildBodyChildren(context, currentRoutine)
          ),
        );
      },
    );
  }

  // --- AppBar Actions Builder ---
  List<Widget> _buildAppBarActions(BuildContext context, Routine routine) {
    // Access BLoC via read() for triggering actions (doesn't need to rebuild widget)
    final routinesBlocInstance = context.read<RoutinesBloc>();

    return [
      // Actions for User's Routines (not recommended)
      if (!widget.isRecRoutine) ...[
        IconButton(
          icon: const Icon(Icons.calendar_today_outlined),
          tooltip: "Set Weekdays",
          onPressed: () => _showWeekdaySelector(context, routine, routinesBlocInstance), // Pass BLoC
        ),
        IconButton(
          icon: const Icon(Icons.edit_outlined),
          tooltip: "Edit Routine",
          onPressed: () => _navigateToEditPage(context, routine), // Pass routine
        ),
        IconButton(
          icon: const Icon(Icons.share_outlined),
          tooltip: "Share Routine",
          onPressed: () => _handleSharePressed(routine), // Pass routine
        ),
        IconButton(
          icon: const Icon(Icons.play_circle_outline, size: 30),
          tooltip: "Start Workout",
          onPressed: () => _startRoutine(context, routine), // Pass routine
        ),
      ],
      // Action for Recommended Routines
      if (widget.isRecRoutine)
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          tooltip: "Add to My Routines",
          onPressed: () => _handleAddRecPressed(context, routine, routinesBlocInstance), // Pass BLoC
        ),
    ];
  }

  // --- Body Content Builder ---
  List<Widget> _buildBodyChildren(BuildContext context, Routine routine) {
    return [
      _buildHeaderCard(context, routine), // Header with name and stats
      // Generate PartCard for each part
      if (routine.parts.isEmpty) // Show message if no parts
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
          child: Center(
              child: Text(
                "This routine has no exercise parts yet.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).hintColor),
              )
          ),
        )
      else // Map parts to PartCard widgets
        ...routine.parts.map((part) => PartCard(
          // Key helps Flutter identify widgets during rebuilds/reorders
          key: ObjectKey(part), // Assumes Part has stable identity or implements ==
          part: part,
          // Provide an empty function for onDelete if not applicable or implemented
          onDelete: widget.isRecRoutine ? () {} : () {
            _showSnackBar("Delete Part feature not implemented.");
            // To implement:
            // 1. Show confirmation dialog.
            // 2. Create updated routine state with part removed (using copyWith).
            // 3. Call context.read<RoutinesBloc>().updateRoutine(updatedRoutine);
          },
          // Navigate to history only for non-recommended routines
          onPartTap: widget.isRecRoutine ? null : () => _navigateToPartHistory(context, part),
        )),
      const SizedBox(height: 80), // Space at the bottom below the list
    ];
  }

  // --- UI Component Widgets ---

  /// Builds the header card showing routine name and stats.
  Widget _buildHeaderCard(BuildContext context, Routine routine) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4), // Adjust padding
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 4,
        color: Theme.of(context).primaryColorDark,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                routine.routineName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              // Show stats only for user's routines
              if (!widget.isRecRoutine) ...[
              const SizedBox(height: 12),
              Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatColumn("COMPLETED", routine.completionCount.toString()),
                    _buildStatColumn("CREATED", _formatDate(routine.createdDate)),
                    // Show Last Done only if it exists
                    if(routine.lastCompletedDate != null)
                      _buildStatColumn("LAST DONE", _formatDate(routine.lastCompletedDate!)),
                    // Add placeholder if lastCompleted is null to maintain layout?
                    if(routine.lastCompletedDate == null) const Spacer(),
                  ]
              ),
            ],
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  /// Helper for building stat columns in the header card.
  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.7), letterSpacing: 0.5)),
      ],
    );
  }

  // --- Action Methods ---

  /// Shows the bottom sheet for selecting weekdays.
  void _showWeekdaySelector(BuildContext context, Routine routine, RoutinesBloc bloc) {
    // Make a copy of current weekdays to pass as initial state
    final currentWeekdays = List<int>.from(routine.weekdays);

    showCupertinoModalPopup(
      context: context,
      builder: (modalContext) => Material( // Wrap with Material
        child: WeekdayModalBottomSheet(
          // Pass the list positionally as required by constructor
          currentWeekdays,
          checkedCallback: (selectedWeekdays) {
            // Create the updated routine immutably
            final updatedRoutine = routine.copyWith(weekdays: selectedWeekdays);
            // Update the routine via the BLoC
            bloc.updateRoutine(updatedRoutine);
            // Optional feedback (removed snackbar for less noise on every check)
          },
        ),
      ),
    );
  }

  /// Navigates to the Routine Edit Page.
  void _navigateToEditPage(BuildContext context, Routine routine) {
    Navigator.push(
      context,
      MaterialPageRoute(
        // Use the correct factory constructor for editing
        builder: (_) => RoutineEditPage.edit(routine: routine),
      ),
    );
  }

  /// Navigates to the Routine Step Page to start the workout.
  void _startRoutine(BuildContext context, Routine routine) {
    if (routine.parts.isEmpty || routine.parts.every((p) => p.exercises.isEmpty)) {
      _showSnackBar("Cannot start an empty routine.", isError: true);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true, // Present modally
        builder: (_) => RoutineStepPage(routine: routine),
      ),
    );
  }

  /// Handles adding a recommended routine to the user's list.
  void _handleAddRecPressed(BuildContext context, Routine recRoutine, RoutinesBloc bloc) {
    showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add to My Routines?'),
        content: Text('Add "${recRoutine.routineName}" to your personal routines list?'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(dialogContext, false),
          ),
          ElevatedButton(
            child: const Text('Add'),
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        ],
      ),
    ).then((shouldAdd) {
      if (shouldAdd ?? false) {
        try {
          // Create a new routine, clearing ID and personal history/stats
          final routineToAdd = recRoutine.copyWith(
            id: null,
            completionCount: 0,
            lastCompletedDate: null,
            routineHistory: [],
            weekdays: [], // Start with no scheduled days
          );
          bloc.addRoutine(routineToAdd);
          _showSnackBar('"${recRoutine.routineName}" added to your routines!');
          // Optionally pop back after adding
          // if (mounted) Navigator.pop(context);
        } catch (e) {
          _showSnackBar("Failed to add routine: ${e.toString()}", isError: true);
        }
      }
    });
  }

  /// Handles sharing the routine by saving to Firestore and showing QR/Share options.
  Future<void> _handleSharePressed(Routine routine) async {
    if (!await _checkConnection()) return;

    try {
      _showSnackBar("Generating share data...");

      // 1. Prepare the routine data for sharing (immutable copy, clear history)
      final routineToShare = routine.copyWith(
          routineHistory: [], // Clear personal history
          // Deep copy parts and exercises, optionally clear exercise history
          parts: routine.parts.map((p) => p.copyWith(
              exercises: p.exercises.map((e) => e.copyWith(exHistory: {})).toList()
          )).toList()
      );

      // 2. Encode the prepared routine to JSON stri
      final String routineJson = jsonEncode(routineToShare.toMapForDb());

      // 3. Get the unique document ID for this share instance
      final String docId = _shareDataString.replaceFirst("-r", "");
      if (docId.isEmpty) throw Exception("Invalid share ID generated.");

      // 4. Save to Firestore 'userShares' collection
      await FirebaseFirestore.instance
          .collection("userShares") // Ensure this collection name is correct
          .doc(docId)
          .set({
        "id": docId,
        "routineName": routineToShare.routineName, // Store name for context
        "routine": routineJson,
        "createdAt": FieldValue.serverTimestamp(),
      });

      debugPrint("Routine shared successfully with ID: $docId");

      // 5. Show the QR/Share Dialog
      if (mounted) _showQRDialog(routine.routineName);

    } catch (e) {
      debugPrint("Error during share process: $e");
      _showSnackBar("Failed to share routine: ${e.toString()}", isError: true);
    }
  }

  /// Shows the dialog with QR code and share options.
  void _showQRDialog(String routineName) {
    // (Implementation remains the same - builds Dialog with QR and buttons)
    showDialog( context: context, builder: (dialogContext) => Dialog( /* ... */ ), );
  }

  /// Placeholder for saving QR image to gallery.
  Future<void> _saveQrToGallery() async {
    _showSnackBar('Save QR to gallery: Not implemented yet.');
    // Requires image_gallery_saver, permission_handler, RepaintBoundary logic
  }

  /// Navigates to the Part History Page.
  void _navigateToPartHistory(BuildContext context, Part part) {
    Navigator.push(
      context,
      // Pass the part object positionally to the constructor
      MaterialPageRoute(builder: (context) => PartHistoryPage(part)),
    );
  }
} // End of _RoutineDetailPageState


// --- WeekdayModalBottomSheet Widget ---

typedef WeekdaysCheckedCallback = void Function(List<int> selectedWeekdays);

class WeekdayModalBottomSheet extends StatefulWidget {
  final List<int> initialWeekdays; // Changed parameter name for clarity
  final WeekdaysCheckedCallback? checkedCallback;

  // Constructor takes initial weekdays as the first positional argument
  const WeekdayModalBottomSheet(this.initialWeekdays, {this.checkedCallback, super.key});

  @override
  State<WeekdayModalBottomSheet> createState() => _WeekdayModalBottomSheetState();
}

class _WeekdayModalBottomSheetState extends State<WeekdayModalBottomSheet> {
  final List<String> weekDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  final List<IconData> weekDayIcons = [ Icons.filter_1, Icons.filter_2, Icons.filter_3, Icons.filter_4, Icons.filter_5, Icons.filter_6, Icons.filter_7 ];
  late List<bool> _isCheckedList;

  @override
  void initState() {
    super.initState();
    // Initialize checkbox state based on the passed initial weekdays
    _isCheckedList = List.generate(7, (index) => widget.initialWeekdays.contains(index + 1));
  }

  @override
  Widget build(BuildContext context) {
    // Using CupertinoActionSheet for iOS look, adjust if needed
    return Material(
      child: CupertinoActionSheet(
        title: const Text('Schedule Routine Days'),
        actions: List.generate(7, (index) => CupertinoActionSheetAction(
          // Toggle selection when the action row is pressed
            onPressed: () => _updateWeekdaySelection(index, !_isCheckedList[index]),
            child: Row(
              children: [
                // Checkbox for visual state (still allows row press)
                Checkbox(
                  value: _isCheckedList[index],
                  onChanged: (value) => _updateWeekdaySelection(index, value),
                  visualDensity: VisualDensity.compact,
                  activeColor: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 10),
                Icon(weekDayIcons[index], size: 20, color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7)),
                const SizedBox(width: 15),
                Text(weekDays[index]),
              ],
            )
        )),
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () {
            // Generate the list of selected integers (1-7)
            final selectedWeekdays = <int>[];
            for (int i = 0; i < _isCheckedList.length; i++) {
              if (_isCheckedList[i]) {
                selectedWeekdays.add(i + 1);
              }
            }
            widget.checkedCallback?.call(selectedWeekdays);
            Navigator.pop(context);
          },
          child: const Text('Done'),
        ),
      ),
    );
  }

  /// Update internal state and notify parent via callback
  void _updateWeekdaySelection(int index, bool? value) {
    if (value == null || _isCheckedList[index] == value) return; // No change needed

    setState(() {
      _isCheckedList[index] = value;
    });
  }
}