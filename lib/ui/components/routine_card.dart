import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // <--- Import Provider package if using it
// OR import 'package:flutter_bloc/flutter_bloc.dart'; // If using BlocProvider

import 'package:workout_planner/bloc/routines_bloc.dart'; // Your RxDart Bloc
import 'package:workout_planner/ui/routine_detail_page.dart';
import 'package:workout_planner/ui/routine_step_page.dart';
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
        onTap: () {
          final int? currentRoutineId = routine.id;
          if (currentRoutineId == null) {
            debugPrint("RoutineCard: Attempted to select routine with null ID.");
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Cannot select this routine (missing ID).")),
            );
            return;
          }

          final routinesBlocInstance = context.read<RoutinesBloc>();
          routinesBlocInstance.selectRoutine(currentRoutineId);

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const RoutineDetailPage(),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                routine.routineName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...routine.parts.map((part) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      Icon(Icons.fitness_center, color: colorScheme.primary),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              part.partName,
                              style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${part.exercises.length} exercises',
                              style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface.withOpacity(0.7)),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                );
              }).toList(),
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