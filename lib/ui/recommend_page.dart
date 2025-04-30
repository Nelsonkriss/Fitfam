import 'package:flutter/material.dart';
// Keep if Cupertino widgets are used indirectly
import 'package:provider/provider.dart'; // Import Provider
import 'package:workout_planner/bloc/routines_bloc.dart'; // Import RxDart Bloc
import 'package:workout_planner/models/main_targeted_body_part.dart';
// Import Routine model
import 'package:workout_planner/utils/routine_helpers.dart'; // For converter

import 'components/routine_card.dart'; // Import RoutineCard widget

class RecommendPage extends StatefulWidget {
  const RecommendPage({super.key});

  @override
  _RecommendPageState createState() => _RecommendPageState();
}

class _RecommendPageState extends State<RecommendPage> {
  final ScrollController _scrollController = ScrollController();
  bool _showAppBarShadow = false; // Use clearer variable name

  @override
  void initState() {
    super.initState();
    // Listen to scroll position to toggle AppBar shadow
    _scrollController.addListener(_handleScroll);

    // Fetch recommended routines when the page loads
    // Access BLoC via context (ensure it's available after build)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Use read() as we only need to trigger the fetch once
      context.read<RoutinesBloc>().fetchRecommendedRoutines();
    });
  }

  void _handleScroll() {
    if (!mounted) return; // Check if widget is still mounted
    final bool shouldShowShadow = _scrollController.offset > 0;
    if (shouldShowShadow != _showAppBarShadow) {
      setState(() {
        _showAppBarShadow = shouldShowShadow;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll); // Remove listener
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Access the BLoC instance provided by Provider
    final routinesBlocInstance = context.watch<RoutinesBloc>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Dev's Favorites"), // Title consistency
        elevation: _showAppBarShadow ? 4.0 : 0.0, // Use state variable for elevation
        shadowColor: Colors.black.withOpacity(0.3), // Optional shadow color
      ),
      body: StreamBuilder<List<Routine>>(
        // *** FIX: Access stream via BLoC instance ***
        stream: routinesBlocInstance.allRecommendedRoutinesStream,
        builder: (context, snapshot) {
          // Handle different stream states
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            // Initial loading state
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            // Error state
            return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Error loading recommendations: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                )
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            // Empty state
            return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'No recommended routines available at the moment.',
                    textAlign: TextAlign.center,
                  ),
                )
            );
          } else {
            // Data available state
            final routines = snapshot.data!;
            // Use ListView.builder for potentially long lists (better performance)
            return ListView.builder(
              controller: _scrollController,
              itemCount: _calculateListItemCount(routines), // Calculate total items including headers
              itemBuilder: (context, index) {
                return _buildListItem(context, routines, index); // Build header or card
              },
            );
          }
        },
      ),
    );
  }

  // --- Helper Functions for Building List ---

  // Group routines by body part (consider moving to BLoC or a helper if complex)
  Map<MainTargetedBodyPart, List<Routine>> _groupRoutines(List<Routine> routines) {
    // Initialize map with all possible body parts to maintain order if desired
    final map = { for (var v in MainTargetedBodyPart.values) v : <Routine>[] };
    // final map = <MainTargetedBodyPart, List<Routine>>{}; // Alternative: only include parts present

    for (final routine in routines) {
      // Ensure routine's body part exists in the enum before adding
      if (map.containsKey(routine.mainTargetedBodyPart)) {
        map[routine.mainTargetedBodyPart]!.add(routine);
      } else {
        debugPrint("Warning: Routine '${routine.routineName}' has unknown MainTargetedBodyPart: ${routine.mainTargetedBodyPart}");
      }
    }
    // Remove empty categories after grouping if map wasn't pre-initialized with all keys
    // map.removeWhere((key, value) => value.isEmpty);
    return map;
  }

  // Calculate the total number of items (headers + routine cards)
  int _calculateListItemCount(List<Routine> routines) {
    final grouped = _groupRoutines(routines);
    int count = 0;
    grouped.forEach((key, value) {
      if (value.isNotEmpty) {
        count++; // Add 1 for the header
        count += value.length; // Add count for routine cards
      }
    });
    return count;
  }

  // Build either a header or a routine card based on the index
  Widget _buildListItem(BuildContext context, List<Routine> routines, int index) {
    final grouped = _groupRoutines(routines);
    // Filter out empty categories before indexing
    final categoriesWithRoutines = grouped.entries.where((entry) => entry.value.isNotEmpty).toList();

    int currentIndex = 0;
    for (var entry in categoriesWithRoutines) {
      final bodyPart = entry.key;
      final categoryRoutines = entry.value;

      // Check if current index is the header for this category
      if (index == currentIndex) {
        return _buildCategoryHeader(context, bodyPart);
      }
      currentIndex++; // Increment past the header

      // Check if current index falls within the routines for this category
      if (index < currentIndex + categoryRoutines.length) {
        final routineIndexInCategory = index - currentIndex;
        final routine = categoryRoutines[routineIndexInCategory];
        // Build the RoutineCard for this routine
        return RoutineCard(routine: routine, isRecRoutine: true);
      }
      // Increment past the routines in this category
      currentIndex += categoryRoutines.length;
    }

    // Should not be reached if itemCount is calculated correctly
    return const SizedBox.shrink();
  }

  // Build the header widget for a body part category
  Widget _buildCategoryHeader(BuildContext context, MainTargetedBodyPart bodyPart) {
    // Use theme text styles for consistency
    final style = Theme.of(context).textTheme.headlineSmall?.copyWith(
      fontWeight: FontWeight.bold,
      // color: Theme.of(context).colorScheme.secondary // Optional: use accent color
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8), // Adjust padding
      child: Text(
        mainTargetedBodyPartToStringConverter(bodyPart), // Use helper function
        style: style,
      ),
    );
  }

// --- buildChildren (Alternative if NOT using ListView.builder) ---
/*
  List<Widget> buildChildren(List<Routine> routines) {
    final grouped = _groupRoutines(routines);
    final children = <Widget>[];

    grouped.forEach((bodyPart, categoryRoutines) {
      if (categoryRoutines.isNotEmpty) {
        children.add(_buildCategoryHeader(context, bodyPart)); // Pass context
        children.addAll(
          categoryRoutines.map((r) => RoutineCard(routine: r, isRecRoutine: true))
        );
         children.add(const SizedBox(height: 8)); // Add space between categories
      }
    });
    return children;
  }
  */
}