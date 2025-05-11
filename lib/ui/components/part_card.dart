import 'package:flutter/material.dart';

import 'package:workout_planner/utils/routine_helpers.dart';

import 'package:workout_planner/models/routine.dart';

typedef PartTapCallback = void Function(Part part);
typedef StringCallback = void Function(String val);

class PartCard extends StatefulWidget {
  final VoidCallback onDelete;
  final VoidCallback? onPartTap;
  final StringCallback? onTextEdited;
  final bool isEmptyMove = true;
  final Part part;

  @override
  PartCardState createState() => PartCardState();

  const PartCard({
    super.key,
    required this.onDelete,
    this.onPartTap,
    this.onTextEdited,
    required this.part
  });
}

class PartCardState extends State<PartCard> {
  // final defaultTextStyle = const TextStyle(fontFamily: 'Roboto'); // Font will come from theme
  final textController = TextEditingController();
  final textSetController = TextEditingController();
  final textRepController = TextEditingController();
  late Part _part;

  @override
  void initState() {
    _part = widget.part;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    _part = widget.part;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0), // Standard padding
      child: Card(
          child: InkWell(
            onTap: widget.onPartTap,
            splashColor: Theme.of(context).splashColor,
            borderRadius: (Theme.of(context).cardTheme.shape is RoundedRectangleBorder)
                ? ((Theme.of(context).cardTheme.shape as RoundedRectangleBorder).borderRadius as BorderRadius?)
                : BorderRadius.circular(12.0), // Default if not RoundedRectangleBorder or borderRadius is not BorderRadius
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min, // Let column size to content
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  ListTile(
                    contentPadding: EdgeInsets.zero, // Remove ListTile's default padding
                    leading: targetedBodyPartToImageConverter(_part.targetedBodyPart ?? TargetedBodyPart.Arm), // Consider theming this icon if it's an Image asset
                    title: Text(
                      _part.setType == null ? 'To be edited' : setTypeToStringConverter(_part.setType),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    subtitle: Text(
                      _part.targetedBodyPart == null ? 'To be edited' : targetedBodyPartToStringConverter(_part.targetedBodyPart),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildExerciseListView(_part, context), // Pass context for theming
                  // const SizedBox(height: 12,) // Removed, let content dictate height or add padding to Column
                ],
              ),
            ),
          )),
    );
  }

  Widget _buildExerciseListView(Part part, BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    var children = <Widget>[];

    // Header Row for "sets" and "reps"
    children.add(Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        // mainAxisAlignment: MainAxisAlignment.end, // Align to end if preferred
        children: <Widget>[
          const Expanded(
            flex: 22, // Exercise name column
            child: SizedBox(), // Placeholder for alignment
          ),
          Expanded(
            flex: 5,
            child: Text('Sets', textAlign: TextAlign.center, style: textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant)),
          ),
          const Expanded(
            flex: 1, // Spacer for 'x'
            child: SizedBox(),
          ),
          Expanded(
            flex: 5,
            child: Text('Reps', textAlign: TextAlign.center, style: textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant)),
          ),
        ],
      ),
    ));
    children.add(Divider(color: theme.dividerColor.withOpacity(0.5), height: 1));


    for (var ex in part.exercises) {
      children.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0), // Add some vertical padding for each exercise row
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Expanded(
              flex: 22,
              child: Text(
                ex.name,
                maxLines: 2, // Allow two lines for exercise name
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyLarge, // Use a more prominent style for exercise name
              ),
            ),
            Expanded(
                flex: 5,
                child: Text(
                  ex.sets.toString(),
                  textAlign: TextAlign.center,
                  style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                )),
            Expanded(
                flex: 1,
                child: Text(
                  'x',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                )),
            Expanded(
                flex: 5,
                child: Text(
                  ex.reps,
                  textAlign: TextAlign.center,
                  style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                )),
          ],
        ),
      ));
      if (part.exercises.indexOf(ex) < part.exercises.length - 1) { // Don't add divider after last item
        children.add(Divider(color: theme.dividerColor.withOpacity(0.3), height: 0.5, indent: 0, endIndent: 0));
      }
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }
}