// Keep if needed by other imports/logic

import 'package:flutter/material.dart';
// Keep if needed
import 'package:provider/provider.dart'; // Import Provider

// Import BLoC, Models, Utils, UI (adjust paths)
import 'package:workout_planner/bloc/routines_bloc.dart'; // Your RxDart BLoC
// Routine model likely uses Part
import 'package:workout_planner/models/main_targeted_body_part.dart';
import 'package:workout_planner/ui/recommend_page.dart';
import 'package:workout_planner/ui/routine_edit_page.dart';
import 'package:workout_planner/utils/routine_helpers.dart'; // For converters, AddOrEdit enum
import 'package:workout_planner/ui/components/routine_card.dart'; // RoutineCard component

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ScrollController _scrollController = ScrollController(); // Use final
  bool _showAppBarShadow = false; // Use more descriptive name

  @override
  void initState() {
    super.initState();
    // Fetch routines when the page loads for the first time
    // Access BLoC via context safely after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Use context.read here as we only need to trigger fetch once
      context.read<RoutinesBloc>().fetchAllRoutines();
    });

    _scrollController.addListener(_scrollListener);
  }

  void _scrollListener() {
    // Check if mounted before accessing state/setState
    if (!mounted) return;
    // Determine if shadow should be shown based on scroll offset
    final shouldShowShadow = _scrollController.offset > 0;
    // Only call setState if the shadow state actually changes
    if (shouldShowShadow != _showAppBarShadow) {
      setState(() {
        _showAppBarShadow = shouldShowShadow;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener); // Remove listener
    _scrollController.dispose();
    super.dispose();
  }

  // --- Build Methods ---

  @override
  Widget build(BuildContext context) {
    // Access BLoC instance here for use in StreamBuilder and FAB
    final routinesBlocInstance = context.watch<RoutinesBloc>();

    return Scaffold(
      // Use NestedScrollView for AppBar shadow effect on scroll
      body: NestedScrollView(
        controller: _scrollController, // Attach controller
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return <Widget>[
            SliverAppBar(
              title: const Text('Workout Planner'),
              pinned: true, // Keep AppBar visible
              floating: true, // Allow AppBar to reappear on upward scroll
              forceElevated: _showAppBarShadow, // Show shadow based on state
              // Customize AppBar appearance if needed
              // backgroundColor: Theme.of(context).primaryColor,
              // foregroundColor: Colors.white,
            ),
          ];
        },
        body: StreamBuilder<List<Routine>>(
          // *** FIX: Use stream from BLoC instance ***
          stream: routinesBlocInstance.allRoutinesStream,
          builder: (_, AsyncSnapshot<List<Routine>> snapshot) {
            if (snapshot.hasError) {
              // Show error message with retry option?
              return Center(child: Text('Error loading routines: ${snapshot.error}'));
            }

            // Show loading indicator only on initial wait
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            // Handle case where data is null or empty after stream emits
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return _buildEmptyState(context, routinesBlocInstance); // Show empty state UI
            }

            // Data is available, build the list
            final routines = snapshot.data!;
            return ListView(
              // No controller needed here, NestedScrollView handles it
              padding: EdgeInsets.zero, // Remove default padding if using SliverAppBar
              children: _buildRoutineListSections(context, routines),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        // backgroundColor will be picked from theme. Ensure FloatingActionButtonThemeData is set in main.dart if specific color needed.
        // child: const Icon(Icons.add, color: Colors.white), // Color will be picked up by theme (onSecondary or onPrimary)
        child: const Icon(Icons.add), // Let theme handle icon color
        onPressed: () => _showAddRoutineSheet(context, routinesBlocInstance),
      ),
    );
  }

  /// Builds the UI shown when there are no routines.
  Widget _buildEmptyState(BuildContext context, RoutinesBloc bloc) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.fitness_center, size: 60, color: Theme.of(context).hintColor),
            const SizedBox(height: 16),
            const Text(
              'No routines yet!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              "Tap the '+' button to create your first workout routine.",
              style: TextStyle(color: Theme.of(context).hintColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            // Optional: Button to add templates directly?
            // ElevatedButton.icon(
            //   icon: Icon(Icons.list_alt),
            //   label: Text("Add from Template"),
            //   onPressed: () => _navigateToAddFromTemplate(context),
            // )
          ],
        ),
      ),
    );
  }

  /// Builds the list sections for "Today" and categorized routines.
  List<Widget> _buildRoutineListSections(BuildContext context, List<Routine> routines) {
    final Map<MainTargetedBodyPart, List<Routine>> mapByCategory = {};
    final List<Routine> todayRoutines = [];
    final int weekday = DateTime.now().weekday; // 1=Monday, 7=Sunday
    final List<Widget> children = <Widget>[];

    // --- AI Generation Card ---
    children.add(
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0), // Add padding
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const RecommendPage()),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, size: 32, color: Theme.of(context).colorScheme.secondary), // Keep secondary for emphasis
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Create with AI", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                          "Let AI generate a workout routine based on your goals.",
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ),
      )
    );
    children.add(const SizedBox(height: 8)); // Spacer after AI card
    // --- End AI Generation Card ---


    // --- Styles ---
    final theme = Theme.of(context);
    final todayTextStyle = theme.textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: theme.colorScheme.secondary // Use secondary for "Today" emphasis
    );
    final routineTitleTextStyle = theme.textTheme.titleLarge; // Use a more semantic style

    // 1. Separate today's routines and categorize others
    for (var routine in routines) {
      if (routine.weekdays.contains(weekday)) {
        todayRoutines.add(routine);
      }
      // Add to map, initializing list if needed
      (mapByCategory[routine.mainTargetedBodyPart] ??= []).add(routine);
    }

    // 2. Add "Today" Section if applicable
    if (todayRoutines.isNotEmpty) {
      children.add(Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8), // Adjust padding
          child: Row( // Keep title and day together
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text(
                  ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][weekday - 1],
                  style: todayTextStyle
              ),
              const SizedBox(width: 8),
              Text(
                  "Workout${todayRoutines.length > 1 ? 's' : ''}",
                  style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)
              ),
            ],
          )));
      // Add RoutineCards for today's routines
      children.addAll(todayRoutines.map((routine) => RoutineCard(
          key: ValueKey('today_${routine.id}'), // Add key for list updates
          isActive: true, // Mark as active
          routine: routine
      )));
      children.add(const SizedBox(height: 16)); // Spacer after Today section
    }


    // 3. Add Sections for each Body Part Category
    // Iterate through enum values to maintain order, filter out empty categories
    for (final bodyPart in MainTargetedBodyPart.values) {
      final routinesInCategory = mapByCategory[bodyPart] ?? [];
      if (routinesInCategory.isNotEmpty) {
        // Add category header
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              mainTargetedBodyPartToStringConverter(bodyPart), // Use helper
              style: routineTitleTextStyle,
            ),
          ),
        );
        // Add RoutineCards for this category
        children.addAll(
          routinesInCategory.map((routine) => RoutineCard(
              key: ValueKey('cat_${routine.id}'), // Add key
              routine: routine
          )),
        );
      }
    }

    // Add some bottom padding
    children.add(const SizedBox(height: 80));

    return children;
  }

  /// Shows the modal bottom sheet for adding a new routine or template.
  void _showAddRoutineSheet(BuildContext context, RoutinesBloc bloc) {
    showModalBottomSheet(
        context: context,
        // isScrollControlled: true, // Enable if list gets long
        shape: const RoundedRectangleBorder( // Rounded top corners
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (sheetContext) { // Use a different context name
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Wrap( // Use Wrap for vertical list items
              children: [
                // Add a title/header to the sheet
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Text("Create New Routine", style: Theme.of(context).textTheme.titleLarge),
                ),
                const Divider(height: 1),
                // Generate list tiles for each body part
                ...MainTargetedBodyPart.values.map((val) {
                  var title = mainTargetedBodyPartToStringConverter(val);
                  return ListTile(
                    leading: Icon(Icons.fitness_center, color: Theme.of(context).colorScheme.primary), // Use themed primary
                    title: Text("New '$title' Routine"),
                    onTap: () {
                      Navigator.pop(sheetContext); // Close the sheet first
                      // *** FIX: Use correct Factory Constructor ***
                      Navigator.push(
                          context, // Use original context for navigation
                          MaterialPageRoute(
                              builder: (context) => RoutineEditPage.add( // Use .add factory
                                mainTargetedBodyPart: val, // Pass the selected body part
                              )));
                    },
                  );
                }),
                const Divider(height: 1, indent: 16, endIndent: 16), // Separator
                // Template Option
                ListTile(
                    leading: Icon(Icons.list_alt_outlined, color: Theme.of(context).colorScheme.secondary), // Use themed secondary
                    title: Text( 'Add from Template', style: TextStyle(color: Theme.of(context).colorScheme.secondary), ), // Use themed secondary
                    onTap: () {
                      Navigator.pop(sheetContext); // Close sheet
                      _navigateToAddFromTemplate(context); // Call helper
                    }
                )
              ],
            ),
          );
        });
  }

  /// Navigates to the RecommendPage (template page).
  void _navigateToAddFromTemplate(BuildContext context) {
    Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const RecommendPage()) // Assume RecommendPage is const
    );
  }

} // End of _HomePageState