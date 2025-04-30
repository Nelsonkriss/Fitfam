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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Material(
        color: Theme.of(context).primaryColor,
        borderRadius: const BorderRadius.all(Radius.circular(6)),
        elevation: 4,
        child: InkWell(
          splashColor: Colors.grey.withOpacity(0.5),
          borderRadius: const BorderRadius.all(Radius.circular(6)),
          onTap: () {
            // --- START: Corrected onTap Logic for RxDart Bloc ---

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
          // --- Widget structure remains the same ---
          child: Container(
            height: 72,
            padding: const EdgeInsets.only(left: 12, right: 12, top: 6, bottom: 2),
            decoration: const BoxDecoration(
                borderRadius: BorderRadius.all(Radius.circular(6))
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Routine Name
                Expanded(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Text(
                        routine.routineName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                ),
                // Weekday Indicators
                if (!isRecRoutine)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: List.generate(7, (index) {
                      final weekday = index + 1;
                      final bool isScheduled = routine.weekdays.contains(weekday);
                      return Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Container(
                          height: 16,
                          width: 16,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isScheduled ? Colors.deepOrangeAccent : Colors.white.withOpacity(0.3),
                          ),
                          child: Center(
                            child: Text(
                              ['M', 'T', 'W', 'T', 'F', 'S', 'S'][index],
                              style: TextStyle(
                                  color: isScheduled ? Colors.white : Colors.white70,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
              ],
            ),
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