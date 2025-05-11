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

  // static const defaultTextStyle = TextStyle(fontFamily: 'Staa', color: Colors.white); // Will use Theme.of(context).textTheme

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
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this Part?'),
        content: const Text('This will remove this part and all its exercises from the routine. You cannot undo this.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error), // Themed error color
            onPressed: () {
              widget.onDelete();
              Navigator.of(dialogContext).pop(true);
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
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: Card( // Will use CardTheme from main.dart
        // shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), // Use theme's shape
        // elevation: 4, // Use theme's elevation
        // color: Theme.of(context).primaryColorDark ?? Theme.of(context).primaryColor, // Use theme's card color
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: targetedBodyPartToImageConverter(part.targetedBodyPart),
              title: Text(
                setTypeToStringConverter(part.setType),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                targetedBodyPartToStringConverter(part.targetedBodyPart),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              onTap: widget.onEdit,
              dense: true,
            ),
            if (part.exercises.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 8.0), // Adjusted padding
                child: _buildExerciseListView(context, part), // Pass context
              ),
            Padding(
              padding: const EdgeInsets.only(left: 8.0, right: 8.0, bottom: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  TextButton.icon(
                    icon: Icon(Icons.delete_outline, size: 18, color: Theme.of(context).colorScheme.error),
                    label: Text( 'DELETE', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.error), ),
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                    onPressed: _showDeleteConfirmationDialog,
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
  Widget _buildExerciseListView(BuildContext context, Part part) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: <Widget>[
            const Expanded(flex: 22, child: SizedBox()), // For alignment with exercise name
            Expanded(flex: 5, child: Text('Sets', textAlign: TextAlign.center, style: textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant))),
            const Expanded(flex: 1, child: SizedBox()),
            Expanded(flex: 5, child: Text('Reps', textAlign: TextAlign.center, style: textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant))),
          ],
        ),
        Divider(color: theme.dividerColor.withOpacity(0.5), height: 8),

        ...part.exercises.map((ex) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(
                flex: 22,
                child: Text(
                  ex.name.isEmpty ? '(Unnamed Exercise)' : ex.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyLarge,
                ),
              ),
              Expanded(
                  flex: 5,
                  child: Text(
                    ex.sets > 0 ? ex.sets.toString() : '-',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                  )),
              Expanded(
                flex: 1,
                child: Text('x', textAlign: TextAlign.center, style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
              ),
              Expanded(
                  flex: 5,
                  child: Text(
                    ex.reps.isEmpty ? '-' : ex.reps,
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                  )),
            ],
          ),
        )).toList(),
      ],
    );
  }
}