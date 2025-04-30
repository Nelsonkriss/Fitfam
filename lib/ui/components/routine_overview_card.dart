// For Platform.isAndroid check
// For min function if ExerciseNameListView needs it

import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Import Provider package
import 'package:workout_planner/bloc/routines_bloc.dart'; // Import your RxDart Bloc
import 'package:workout_planner/models/main_targeted_body_part.dart'; // Import enum
// Import Routine model (contains Part, Exercise etc.)
// Import Part if needed separately
import 'package:workout_planner/ui/routine_detail_page.dart';
import 'package:workout_planner/utils/routine_helpers.dart'; // Assuming this has mainTargetedBodyPartToStringConverter


final _rowHeight = 300.0; // Consider making this const if possible

/// A custom widget displaying an overview of a workout routine.
class RoutineOverview extends StatelessWidget {
  final Routine routine;
  final bool isRecRoutine;

  const RoutineOverview({
    super.key,
    required this.routine,
    this.isRecRoutine = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Material(
        shape: RoundedRectangleBorder(
            side: BorderSide.none, // Simpler than transparent color
            borderRadius: BorderRadius.circular(24)
        ),
        color: Colors.orangeAccent, // Consider making this dynamic or themed
        elevation: 3,
        child: InkWell( // Use InkWell directly on Material for correct ripple effect
          borderRadius: BorderRadius.circular(24),
          highlightColor: Colors.orange.withOpacity(0.3), // More subtle highlight
          splashColor: Colors.orange.withOpacity(0.4),   // More subtle splash
          onTap: () {
            // --- FIX: Use context.read to access the BLoC ---
            // Ensure the BLoC is provided higher up using Provider<RoutinesBloc>
            final routinesBlocInstance = context.read<RoutinesBloc>();

            // Call the appropriate method on the RxDart BLoC
            if (routine.id != null) {
              routinesBlocInstance.selectRoutine(routine.id);
            } else {
              debugPrint("RoutineOverview: Cannot select routine with null ID.");
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Cannot select this routine (missing ID).")),
              );
              return; // Don't navigate
            }
            // --- End Fix ---

            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => RoutineDetailPage(
                      isRecRoutine: isRecRoutine,
                      // Detail page should get the routine from the BLoC stream
                    )));
          },
          child: Container( // Container for padding and height constraint
            height: _rowHeight,
            padding: const EdgeInsets.all(16.0), // Consistent padding
            child: Column(
              // mainAxisAlignment: MainAxisAlignment.center, // Let Column manage vertical space
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // Top section: Body part and Routine name
                Text(
                  mainTargetedBodyPartToStringConverter(routine.mainTargetedBodyPart).toUpperCase(), // Example formatting
                  style: TextStyle(
                      color: Colors.black.withOpacity(0.6),
                      fontWeight: FontWeight.w600,
                      fontSize: 14
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  routine.routineName,
                  style: TextStyle(
                    color: Colors.black,
                    // fontFamily: 'Staa', // Uncomment if using custom font
                    fontSize: _getFontSize(routine.routineName),
                    fontWeight: FontWeight.bold,
                    height: 1.2, // Improve line spacing
                  ),
                  maxLines: 2, // Allow wrapping slightly
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16), // Spacer

                // Middle Section: Image and Exercise List
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch, // Stretch children vertically
                    children: <Widget>[
                      // Left side: Image
                      Expanded(
                        flex: 2, // Give image a bit more space
                        child: Container(
                          alignment: Alignment.center, // Center image
                          // Optional background or decoration
                          // decoration: BoxDecoration(
                          //    color: Colors.black.withOpacity(0.05),
                          //    borderRadius: BorderRadius.circular(12),
                          // ),
                          child: Image.asset(
                            _getIconPath(routine.mainTargetedBodyPart),
                            fit: BoxFit.contain, // Use contain to see whole image
                            // height: 100, // Optional fixed height
                            // width: 100,  // Optional fixed width
                          ),
                        ),
                      ),
                      const SizedBox(width: 16), // Spacer between image and list

                      // Right side: Exercise List
                      Expanded(
                        flex: 3, // Give list more space
                        child: ExerciseNameListView(
                            exNames: _getFirstNExerciseNames(routine.parts, 3) // Pass computed names
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper to calculate font size based on string length
  double _getFontSize(String str) {
    final len = str.length;
    if (len > 30) return 22; // Adjust thresholds as needed
    if (len > 17) return 26;
    if (len > 10) return 30;
    return 34;
  }

  // Helper to get asset path based on body part
  String _getIconPath(MainTargetedBodyPart mainTB) {
    switch (mainTB) {
      case MainTargetedBodyPart.Abs:
        return 'assets/icons/abs-96.png'; // Example path structure
      case MainTargetedBodyPart.Arm:
      case MainTargetedBodyPart.Shoulder: // Combine similar icons
        return 'assets/icons/muscle-96.png';
      case MainTargetedBodyPart.Back:
        return 'assets/icons/back-96.png';
      case MainTargetedBodyPart.Chest:
        return 'assets/icons/chest-96.png';
      case MainTargetedBodyPart.Leg:
        return 'assets/icons/leg-96.png';
      case MainTargetedBodyPart.FullBody:
        return 'assets/icons/fullbody-96.png'; // Example different icon
    // Remove default case or handle explicitly if new enums are added
    // default: return 'assets/icons/default-96.png'; // Fallback icon
    }
  }

  // Helper to get first N exercise names (made static)
  static List<String> _getFirstNExerciseNames(List<Part> parts, int count) {
    List<String> exNames = <String>[];
    for (final part in parts) {
      for (final exercise in part.exercises) {
        if(exercise.name.trim().isNotEmpty) {
          exNames.add(exercise.name.trim());
          if (exNames.length >= count) return exNames; // Exit early
        }
      }
      if (exNames.length >= count) return exNames; // Exit early
    }
    return exNames;
  }
}


// --- ExerciseNameListView Widget ---
// Displays a list of exercise names (up to 3 typically)

class ExerciseNameListView extends StatelessWidget { // Changed to StatelessWidget
  final List<String> exNames;

  const ExerciseNameListView({super.key, required this.exNames});

  @override
  Widget build(BuildContext context) {
    if (exNames.isEmpty) {
      // Show placeholder if no exercises
      return const Center(
        child: Text(
          'No exercises listed.',
          style: TextStyle(color: Colors.black54, fontStyle: FontStyle.italic),
        ),
      );
    }

    // Use ListView.separated for automatic dividers
    return ListView.separated(
      shrinkWrap: true, // Important if nested in Row/Column
      physics: const NeverScrollableScrollPhysics(), // Disable scrolling within card
      itemCount: exNames.length,
      itemBuilder: (context, index) {
        return _buildRow(exNames[index]);
      },
      separatorBuilder: (context, index) => const Divider(
        color: Colors.black26, // Subdued divider color
        height: 8, // Space around divider
        thickness: 0.5,
      ),
    );
  }

  // Helper to build a single text row for an exercise name
  Widget _buildRow(String move) {
    return Text(
      move,
      textAlign: TextAlign.left,
      maxLines: 2, // Allow two lines for longer names
      overflow: TextOverflow.ellipsis, // Use ellipsis if still too long
      style: TextStyle(
        // fontFamily: 'Staa', // Uncomment if using custom font
        color: Colors.black.withOpacity(0.85), // Slightly less intense black
        fontSize: 16,
        height: 1.3, // Line spacing
        // Removed shadows as they might look odd in this context
      ),
    );
  }
}