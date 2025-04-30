// Keep if needed by helpers
import 'package:flutter/material.dart';

// Import Models and Utils (adjust paths)
import 'package:workout_planner/models/routine.dart'; // Contains Routine, Part, Exercise, Enums
import 'package:workout_planner/utils/routine_helpers.dart'; // For converters, AddOrEdit enum
import 'package:workout_planner/ui/part_edit_page.dart';

typedef StringCallback = void Function(String val); // Keep if onTextEdited is used

class PartEditCard extends StatefulWidget {
  final VoidCallback onDelete; // Callback when delete is confirmed
  final VoidCallback onEdit;   // *** FIX #3: Added callback for edit action ***
  final StringCallback? onTextEdited; // Keep if needed elsewhere
  final Part part;           // The current immutable part data
  final Routine curRoutine; // The parent routine context (read-only view)

  const PartEditCard({
    super.key, // Use Key? key and super(key: key)
    required this.onDelete,
    required this.onEdit, // *** FIX #3: Added required onEdit parameter ***
    this.onTextEdited,
    required this.part,
    required this.curRoutine,
  });

  @override
  State<PartEditCard> createState() => _PartEditCardState(); // Use createState
}

class _PartEditCardState extends State<PartEditCard> {
  // No need for local mutable 'part' copy if just displaying widget.part
  // late Part part; // Removed

  // --- FIX #5: Remove unused controllers ---
  // final textController = TextEditingController();
  // final textSetController = TextEditingController();
  // final textRepController = TextEditingController();
  // --- End Fix #5 ---

  // Use defaultTextStyle from theme if possible, otherwise define locally
  static const defaultTextStyle = TextStyle(fontFamily: 'Staa', color: Colors.white); // Made static const

  @override
  void initState() {
    super.initState();
    // part = widget.part; // Removed - use widget.part directly for display
  }

  // --- Helper Methods ---

  /// Shows the delete confirmation dialog.
  void _showDeleteConfirmationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // User must explicitly choose
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this Part?'),
        content: const Text('This will remove this part and all its exercises from the routine. You cannot undo this.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false), // Return false - don't delete
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red), // Destructive action color
            onPressed: () {
              widget.onDelete(); // Call the callback passed from parent
              Navigator.of(dialogContext).pop(true); // Return true - deleted
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  /// Navigates to the PartEditPage for modification.
  void _navigateToEditPart() async {
    final Part? result = await Navigator.push<Part?>( // Expect Part or null back
      context,
      MaterialPageRoute(
        builder: (context) => PartEditPage(
          addOrEdit: AddOrEdit.edit,
          part: widget.part, // Pass the current immutable part state
          // curRoutine: widget.curRoutine, // Pass if needed by PartEditPage
        ),
      ),
    );

    // If PartEditPage returned a *new* (edited) Part object,
    // This PartEditCard cannot directly update the parent's list.
    // The parent (RoutineEditPage) needs to handle the result of the push.
    // Therefore, the .then((value){ setState... }) logic is REMOVED from here.
    // The parent RoutineEditPage's _onEditPart method already handles this.
    if (result != null) {
      debugPrint("PartEditCard: Edit page returned updated part (parent should handle update).");
      // Potentially call a different callback if needed, e.g., widget.onPartUpdated(result);
    } else {
      debugPrint("PartEditCard: Edit page returned null (edit cancelled).");
    }
  }


  // --- Build Method ---
  @override
  Widget build(BuildContext context) {
    // Use widget.part directly for displaying data
    final part = widget.part;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0), // Adjust padding
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), // Softer corners
        elevation: 4, // Adjust elevation
        // Use a slightly less intense color, or theme color
        color: Theme.of(context).primaryColorDark ?? Theme.of(context).primaryColor,
        clipBehavior: Clip.antiAlias, // Clip content like ListTile ink effects
        child: Column( // Use Column for better structure
          mainAxisSize: MainAxisSize.min, // Fit content vertically
          children: <Widget>[
            ListTile(
              // --- FIX #1 & #6: Removed unnecessary null checks ---
              leading: targetedBodyPartToImageConverter(part.targetedBodyPart), // Use directly
              title: Text(
                setTypeToStringConverter(part.setType), // Use directly
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500), // Adjusted style
              ),
              subtitle: Text(
                targetedBodyPartToStringConverter(part.targetedBodyPart), // Use directly
                style: const TextStyle(color: Colors.white70), // Adjusted style
              ),
              // Add a trailing edit button? Or make whole tile tappable
              // trailing: IconButton(icon: Icon(Icons.edit_outlined, color: Colors.white70), onPressed: widget.onEdit),
              onTap: widget.onEdit, // Make the tile itself trigger the edit
              dense: true, // Make tile more compact
            ),
            // Conditionally show exercise list if not empty
            if (part.exercises.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0), // Adjust padding
                child: _buildExerciseListView(part),
              ),
            // Action Buttons Row
            Padding(
              // Add padding around the buttons row, except top
              padding: const EdgeInsets.only(left: 8.0, right: 8.0, bottom: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end, // Align buttons to the right
                children: <Widget>[
                  // Edit button now handled by ListTile onTap
                  // TextButton.icon(
                  //   icon: const Icon(Icons.edit, size: 18, color: Colors.white70),
                  //   label: const Text('EDIT', style: TextStyle(color: Colors.white, fontSize: 14)),
                  //   style: TextButton.styleFrom(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                  //   onPressed: widget.onEdit, // *** FIX #3: Call onEdit callback ***
                  // ),
                  TextButton.icon(
                    icon: Icon(Icons.delete_outline, size: 18, color: Colors.red.shade300),
                    label: Text( 'DELETE', style: TextStyle(color: Colors.red.shade300, fontSize: 14), ),
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                    onPressed: _showDeleteConfirmationDialog, // Show confirmation
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the display list of exercises within the card.
  Widget _buildExerciseListView(Part part) {
    // Use ListView.builder for potentially longer lists, though Column is fine for short ones
    return Column(
      mainAxisSize: MainAxisSize.min, // Constrain Column height
      children: [
        // Header Row
        Row(
          // ... (Header structure remains the same) ...
          mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            const Expanded(flex: 22, child: Text("", style: TextStyle(color: Colors.white))),
            Expanded(flex: 5, child: RichText(textAlign: TextAlign.center, text: TextSpan(style: defaultTextStyle.copyWith(color: Colors.white54, fontSize: 12), children: const [ TextSpan(text: 'Sets') ]))), // Smaller header
            const Expanded(flex: 1, child: SizedBox()), // Spacer instead of 'x'
            Expanded(flex: 5, child: RichText(textAlign: TextAlign.center, text: TextSpan(style: defaultTextStyle.copyWith(color: Colors.white54, fontSize: 12), children: const [ TextSpan(text: 'Reps') ]))), // Smaller header
          ],
        ),
        const Divider(color: Colors.white24, height: 8), // Separator line

        // Exercise Rows
        ...part.exercises.map((ex) => Padding( // Add padding to each exercise row
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(
                flex: 22, // Exercise name takes most space
                child: Text(
                  ex.name.isEmpty ? '(Unnamed Exercise)' : ex.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis, // Handle long names
                  style: defaultTextStyle.copyWith(fontSize: 14), // Slightly smaller exercise name
                ),
              ),
              Expanded(
                  flex: 5,
                  child: Text(
                    ex.sets > 0 ? ex.sets.toString() : '-', // Show dash if 0 sets
                    textAlign: TextAlign.center,
                    style: defaultTextStyle.copyWith(fontSize: 16, fontWeight: FontWeight.w500), // Bolder numbers
                  )),
              const Expanded(
                flex: 1,
                child: Text('x', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 14)), // 'x' separator
              ),
              Expanded(
                  flex: 5,
                  child: Text(
                    ex.reps.isEmpty ? '-' : ex.reps, // Show dash if reps empty
                    textAlign: TextAlign.center,
                    style: defaultTextStyle.copyWith(fontSize: 16, fontWeight: FontWeight.w500), // Bolder numbers
                  )),
            ],
          ),
        )), // End of map, convert to List
      ],
    );
  }
}