import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // <--- Import Provider package if using it
// OR import 'package:flutter_bloc/flutter_bloc.dart'; // If using BlocProvider

import 'package:workout_planner/bloc/routines_bloc.dart'; // Your RxDart Bloc
import 'package:workout_planner/ui/routine_detail_page.dart';
// ... other imports

class RoutineCard extends StatelessWidget {
  final bool isActive;
  final Routine routine;
  final bool isRecRoutine;

  const RoutineCard({
    super.key,
    this.isActive = false,
    required this.routine,
    this.isRecRoutine = false,
  });

  @override
  Widget build(BuildContext context) {
    // Get theme for easier access
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Card(
      child: InkWell(
          borderRadius: (theme.cardTheme.shape is RoundedRectangleBorder)
              ? ((theme.cardTheme.shape as RoundedRectangleBorder).borderRadius as BorderRadius?) // Cast to BorderRadius
              : BorderRadius.circular(12.0), // Default if not RoundedRectangleBorder or borderRadius is not BorderRadius
          onTap: () {

            final int? currentRoutineId = routine.id;
            if (currentRoutineId == null) {
              debugPrint("RoutineCard: Attempted to select routine with null ID.");
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Cannot select this routine (missing ID).")),
              );
              return;
            }

            // Get the BLoC instance using Provider or BlocProvider context extension
            // Adjust context.read<...> based on how you provided it
            final routinesBlocInstance = context.read<RoutinesBloc>();

            // Call the PUBLIC METHOD directly on the RxDart BLoC instance
            routinesBlocInstance.selectRoutine(currentRoutineId);

            debugPrint("RoutineCard: Called selectRoutine for ID $currentRoutineId");

            // --- END: Corrected onTap Logic for RxDart Bloc ---

            // Navigate to the detail page
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RoutineDetailPage(
                  isRecRoutine: isRecRoutine,
                ),
              ),
            );
          },
          child: Padding( // Add padding inside InkWell
            padding: const EdgeInsets.all(16.0), // More modern padding
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, // Allow card to size to content
              children: [
                Text(
                  routine.routineName,
                  maxLines: 2, // Allow a bit more space for longer names
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleLarge?.copyWith(
                    // Use themed text style
                    fontWeight: FontWeight.bold,
                    // Color will be inherited from theme (e.g., onSurface)
                  ),
                ),
                if (!isRecRoutine && routine.parts.isNotEmpty) ...[ // Add some spacing if details are shown
                  const SizedBox(height: 8),
                  Text(
                    "${routine.parts.length} part${routine.parts.length == 1 ? '' : 's'}", // Example subtitle
                    style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface.withOpacity(0.7)),
                  ),
                ],
                if (!isRecRoutine) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start, // Align to start
                    children: List.generate(7, (index) {
                      final weekday = index + 1;
                      final bool isScheduled = routine.weekdays.contains(weekday);
                      return Container(
                        margin: const EdgeInsets.only(right: 6), // Spacing between circles
                        height: 20, // Slightly larger circles
                        width: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isScheduled ? colorScheme.primary : colorScheme.surfaceVariant, // Themed colors
                          border: isScheduled ? null : Border.all(color: colorScheme.outline.withOpacity(0.5))
                        ),
                        child: Center(
                          child: Text(
                            ['M', 'T', 'W', 'T', 'F', 'S', 'S'][index],
                            style: TextStyle(
                                color: isScheduled ? colorScheme.onPrimary : colorScheme.onSurfaceVariant, // Themed text colors
                                fontSize: 10, // Adjusted size
                                fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }),
                  ),
                ]
              ],
            ),
          ),
        ),
    );
  }
}


// --- ExerciseNameListView and _ExerciseNameListViewState ---
// These widgets are included as they were in the original prompt's file context,
// but they are not used *by* RoutineCard in this corrected version.
// Keep them if they are used elsewhere, otherwise they can be removed.

class _ExerciseNameListViewState extends State<ExerciseNameListView> with SingleTickerProviderStateMixin {
  final List<String> exNames;
  final bool isStatic;

  _ExerciseNameListViewState({required this.exNames, required this.isStatic});

  late AnimationController animationController;
  late Animation<double> curvedAnimation;

  @override
  void initState() {
    super.initState();
    animationController = AnimationController(
        vsync: this, lowerBound: 0.2, upperBound: 1, duration: const Duration(seconds: 1, milliseconds: 500));

    if (isStatic) {
      animationController.value = 1;
    } else {
      animationController.repeat(reverse: true);
    }

    curvedAnimation = CurvedAnimation(
      parent: animationController,
      curve: Curves.fastOutSlowIn,
    );
  }

  @override
  void dispose() {
    animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: curvedAnimation,
      builder: (_, __) {
        return Transform.scale(
          alignment: Alignment.centerLeft,
          scale: 0.95 + 0.05 * curvedAnimation.value,
          child: _buildMoves(),
        );
      },
    );
  }

  Widget _buildMoves() {
    List<Widget> children = [];
    if (exNames.isNotEmpty) {
      final namesToShow = exNames.take(3).toList();
      for (var exName in namesToShow) {
        children
          ..add(_buildRow(exName))
          ..add(const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: Divider( color: Colors.white54, height: 1,),
          ));
      }
      if (children.isNotEmpty) children.removeLast();
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _buildRow(String move) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: RichText(
          textAlign: TextAlign.left,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          text: TextSpan(
              style: const TextStyle( color: Colors.white, fontSize: 14, ),
              children: <TextSpan>[ TextSpan(text: move), ])),
    );
  }
}

class ExerciseNameListView extends StatefulWidget {
  final List<Part> parts;
  final bool isStatic;
  final List<String> exNames;

  ExerciseNameListView({super.key, required this.parts, this.isStatic = true})
      : exNames = _getFirstNExerciseNames(parts, 3);

  @override
  State<ExerciseNameListView> createState() => _ExerciseNameListViewState(exNames: exNames, isStatic: isStatic);

  static List<String> _getFirstNExerciseNames(List<Part> parts, int count) {
    List<String> names = [];
    for (final part in parts) {
      for (final exercise in part.exercises) {
        if (exercise.name.trim().isNotEmpty) {
          names.add(exercise.name.trim());
          if (names.length >= count) return names;
        }
      }
      if (names.length >= count) return names;
    }
    if(names.isEmpty && parts.isNotEmpty) return ["Routine Part 1..."];
    return names;
  }
}