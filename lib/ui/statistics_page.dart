import 'dart:async'; // For Future
// For max() if needed by helpers, used in _getRatio calculation

import 'package:flutter/foundation.dart'; // For kDebugMode
import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart'; // For weekly progress
import 'package:provider/provider.dart'; // To access BLoCs

// Import BLoCs and Providers (Adjust paths if needed)
import 'package:workout_planner/bloc/routines_bloc.dart'; // Your RxDart BLoC
// import 'package:workout_planner/bloc/workout_session_bloc.dart'; // Not directly needed if CalendarPage handles its own data
import 'package:workout_planner/resource/shared_prefs_provider.dart'; // For getFirstRunDate
import 'package:workout_planner/resource/shared_prefs_provider.dart'; // Re-add import statement

// Import Models and UI Components
// Included via routine.dart
// Included via routine.dart
import 'package:workout_planner/models/part.dart'; // Import Part model
import 'package:workout_planner/ui/calender_page.dart'; // Your Calendar Page implementation
import 'package:workout_planner/ui/components/chart.dart'; // Assuming DonutAutoLabelChart is here

// Default text styles for cards (Consider moving to theme)
const TextStyle _kCardTextStyle = TextStyle(color: Colors.white, fontSize: 16, height: 1.2);
const TextStyle _kCardLabelTextStyle = TextStyle(color: Colors.white70, fontSize: 13, height: 1.2);
const TextStyle _kCardLargeNumStyle = TextStyle(color: Colors.white, fontWeight: FontWeight.bold); // Size determined by FittedBox


/// Page displaying user statistics, workout calendar, and charts.
class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  String _firstRunDate = 'loading...'; // State variable for async data
  Set<int> _selectedWeeklyProgressRoutineIds = {}; // State variable for selected routine IDs for weekly progress
  int? _selectedWeeklyAmount; // State variable for weekly workout amount

  @override
  void initState() {
    super.initState();
    _loadFirstRunDate(); // Load async data once when state initializes
    _loadSelectedWeeklyProgressRoutines(); // Load selected routines for weekly progress
    _loadWeeklyAmount(); // Load weekly workout amount
  }

  /// Asynchronously loads the first run date from SharedPreferences.
  Future<void> _loadFirstRunDate() async {
    final date = await sharedPrefsProvider.getFirstRunDate();
    // Check if widget is still mounted before calling setState
    if (mounted) {
      setState(() {
        _firstRunDate = date ?? 'Unknown'; // Update state with fetched value or default
      });
    }
  }

  /// Asynchronously loads the selected routine IDs for weekly progress from SharedPreferences.
  Future<void> _loadSelectedWeeklyProgressRoutines() async {
    final selectedIds = await sharedPrefsProvider.getWeeklyProgressRoutineIds();
    if (mounted) {
      setState(() {
        _selectedWeeklyProgressRoutineIds = selectedIds.toSet();
      });
    }
  }

  /// Asynchronously loads the weekly workout amount from SharedPreferences.
  Future<void> _loadWeeklyAmount() async {
    final amount = await sharedPrefsProvider.getWeeklyAmount();
    if (mounted) {
      setState(() {
        _selectedWeeklyAmount = amount ?? 0; // Default to 0 if not set
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Access the RoutinesBloc instance provided higher up in the tree
    // Use watch() so the StreamBuilder below reacts if the BLoC instance itself changes (rare)
    final routinesBlocInstance = context.watch<RoutinesBloc>();

    if (kDebugMode) print("[BUILD] StatisticsPage");

    return Scaffold(
      // Use NestedScrollView for seamless scrolling between SliverAppBar, Grid, and other content
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return <Widget>[
            SliverAppBar(
              title: const Text("Statistics & History"), // Changed title slightly
              pinned: true,     // Keeps AppBar visible
              floating: true,   // Reappears on scroll up
              snap: true,       // Snaps fully in/out
              forceElevated: innerBoxIsScrolled, // Shows shadow when content scrolls under
              backgroundColor: Theme.of(context).colorScheme.surface, // Use surface color
              foregroundColor: Theme.of(context).colorScheme.onSurface, // Text/Icon color
              surfaceTintColor: Theme.of(context).colorScheme.surfaceTint, // Material 3 tint
            ),
          ];
        },
        // The main scrollable body content
        body: StreamBuilder<List<Routine>>(
          stream: routinesBlocInstance.allRoutinesStream, // Listen to routine data
          builder: (context, routineSnapshot) {
            if (kDebugMode) {
              print("Statistics Routine StreamBuilder state: ${routineSnapshot.connectionState}");
              if (routineSnapshot.hasData) {
                print("StatisticsPage: Routine data: ${routineSnapshot.data}");
              }
            }

            // --- Handle Routine Stream States ---
            if (routineSnapshot.connectionState == ConnectionState.waiting && !routineSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (routineSnapshot.hasError) {
              return Center(child: Text('Error loading routines: ${routineSnapshot.error}'));
            }
            // Use empty list if data is null (stream active but no data yet) or empty
            final routines = routineSnapshot.data ?? [];

            // --- Build Layout ---
            // Use CustomScrollView to combine slivers and regular widgets easily
            return CustomScrollView(
              slivers: <Widget>[
                // 1. Statistics Grid (uses routine data)
                _buildStatisticsGrid(context, routines), // Pass routines here

                // 2. Calendar Section Header
                SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                      child: Text(
                          "Workout Calendar",
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600)
                      ),
                    )
                ),

                // 3. Calendar Page (Assumes it fetches its own session data)
                // Wrap CalendarPage (if it's not a Sliver itself)
                const SliverToBoxAdapter(
                  child: CalenderPage(), // CalendarPage needs to handle its own data source
                ),

                // Add bottom padding inside the scroll view
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Builds the 2x2 grid of statistics cards as a Sliver.
  Widget _buildStatisticsGrid(BuildContext context, List<Routine> routines) {
    // Calculate stats based on the received routines list
    final totalCompletionCount = _getTotalWorkoutCount(routines);
    final weeklyRatio = _calculateWeeklyRatio(routines); // Renamed for clarity
    final String displayFirstRunDate = _firstRunDate; // Use state variable
    int daysSince = 0;
    if (displayFirstRunDate != 'loading...' && displayFirstRunDate != 'Unknown') {
      final parsedDate = DateTime.tryParse(displayFirstRunDate);
      if (parsedDate != null) {
        daysSince = DateTime.now().difference(parsedDate).inDays.clamp(0, 99999); // Prevent negative days
      }
    }

    return SliverPadding(
      padding: const EdgeInsets.all(16.0), // Padding around the entire grid
      sliver: SliverGrid.count(
        crossAxisCount: 2,      // Two columns
        mainAxisSpacing: 12.0,  // Vertical spacing between cards
        crossAxisSpacing: 12.0, // Horizontal spacing between cards
        childAspectRatio: 1.0,  // Make cells roughly square
        children: <Widget>[
          // --- Card 1: Days Since First Run ---
          _buildInfoCard(
            context: context,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Text('Using since', textAlign: TextAlign.center, style: _kCardLabelTextStyle),
                Text(displayFirstRunDate, textAlign: TextAlign.center, style: _kCardTextStyle.copyWith(fontSize: 16, fontWeight: FontWeight.w500)),
                const Spacer(flex: 2),
                Expanded(
                    flex: 5,
                    child: FittedBox(fit: BoxFit.contain, child: Text('$daysSince', textAlign: TextAlign.center, style: _kCardLargeNumStyle))
                ),
                const Spacer(flex: 1),
                const Text('Days Ago', textAlign: TextAlign.center, style: _kCardLabelTextStyle),
                const SizedBox(height: 8),
              ],
            ),
          ),

          // --- Card 2: Total Completion Count ---
          _buildInfoCard(
            context: context,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Total Workouts\nCompleted', textAlign: TextAlign.center, style: _kCardLabelTextStyle),
                const Spacer(flex: 2),
                Expanded(
                  flex: 5,
                  child: FittedBox(fit: BoxFit.contain, child: Text( totalCompletionCount.toString(), textAlign: TextAlign.center, style: _kCardLargeNumStyle)),
                ),
                const Spacer(flex: 3), // Adjust spacing as needed
              ],
            ),
          ),

          // --- Card 3: Workout Focus (Donut Chart) ---
          _buildInfoCard(
            context: context,
            child: Padding(
              padding: const EdgeInsets.all(8.0), // Inner padding for chart card
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Workout Focus", style: _kCardLabelTextStyle),
                  const SizedBox(height: 12), // Increased space
                  Expanded(
                    child: Builder( // Use Builder to create allParts list within the scope
                      builder: (context) {
                        // Extract all parts from all routines
                        final List<Part> allParts = routines.expand((routine) => routine.parts).toList();

                        return (allParts.isEmpty)
                            ? Center(child: Text("No parts defined in routines", style: _kCardTextStyle.copyWith(color: Colors.white54, fontSize: 12)))
                            : DonutAutoLabelChart(allParts); // Pass List<Part>
                      }
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- Card 4: Weekly Goal Progress ---
          _buildInfoCard(
              context: context,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Weekly Progress", textAlign: TextAlign.center, style: _kCardLabelTextStyle),
                      const Spacer(flex: 2), // Push indicator down slightly
                      CircularPercentIndicator(
                        radius: 48.0, // Adjusted radius to prevent overflow
                        lineWidth: 10.0, // Adjusted line width
                        animation: true,
                        animationDuration: 800,
                        percent: weeklyRatio, // Use the calculated ratio (already clamped)
                        center: Text( "${(weeklyRatio * 100).toStringAsFixed(0)}%",
                          style: _kCardTextStyle.copyWith(fontWeight: FontWeight.bold, fontSize: 20.0),
                        ),
                        circularStrokeCap: CircularStrokeCap.round,
                        backgroundColor: Colors.white.withOpacity(0.2), // Background circle
                        progressColor: Colors.deepOrangeAccent, // Use theme accent?
                      ),
                      const Spacer(flex: 3), // Bottom space
                    ]
                ),
              )
          ),
        ],
      ),
    );
  }

  /// Helper widget to build the standard card appearance.
  Widget _buildInfoCard({required BuildContext context, required Widget child}) {
    return Card(
      shape: RoundedRectangleBorder( borderRadius: BorderRadius.circular(12) ),
      elevation: 4,
      // Use primary color from theme for cards, or a slightly darker variant
      color: Theme.of(context).primaryColorDark ?? Theme.of(context).primaryColor,
      child: Padding( // Apply padding inside the card
        padding: const EdgeInsets.all(8.0),
        child: child,
      ),
    );
  }

  /// Calculates the weekly completion ratio based on the number of completed workouts this week
  /// for the routines selected by the user in settings, compared to the weekly workout target.
  double _calculateWeeklyRatio(List<Routine> routines) {
    // Get the list of routine IDs selected for weekly progress
    // Assumes _selectedWeeklyProgressRoutineIds is populated in initState.

    // Get the weekly workout target from shared preferences
    // Assumes _selectedWeeklyAmount is populated in initState.
    final weeklyTarget = _selectedWeeklyAmount ?? 0; // Use 0 if target is not set

    // If the weekly target is 0, the progress is 0.
    if (weeklyTarget <= 0) return 0.0;

    // Filter routines based on selected IDs
    final filteredRoutines = routines.where((routine) =>
        routine.id != null && _selectedWeeklyProgressRoutineIds.contains(routine.id!)).toList();

    int completedCountThisWeek = 0; // Count total completed workouts this week

    final now = DateTime.now().toLocal();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    // Use DateUtils.dateOnly for accurate date comparison (ignores time)
    final startOfWeekDate = DateUtils.dateOnly(startOfWeek);

    // Iterate through the filtered routines and count completions this week
    for (final routine in filteredRoutines) {
      for (final timestamp in routine.routineHistory) {
        try {
          final dateCompletedLocal = DateTime.fromMillisecondsSinceEpoch(timestamp).toLocal();
          final dateCompletedOnly = DateUtils.dateOnly(dateCompletedLocal); // Ignore time

          // Check if completion is within the current week (Monday or later)
          if (!dateCompletedOnly.isBefore(startOfWeekDate)) {
            completedCountThisWeek++; // Count each completion
          }
        } catch (e) {
          debugPrint("Error parsing routine history timestamp: $timestamp, Error: $e");
        }
      }
    }

    // Calculate ratio based on completed workouts vs weekly target
    final ratio = completedCountThisWeek / weeklyTarget;

    // Calculate ratio, clamp between 0.0 and 1.0
    return ratio.clamp(0.0, 1.0);
  }

  /// Determines font size for the large count display based on string length.
  double _getFontSizeForCount(String displayText) {
    // Adjust thresholds for better visual balance in FittedBox
    final len = displayText.length;
    if (len <= 1) return 64;
    if (len == 2) return 56;
    if (len == 3) return 48;
    return 40; // For 4+ digits
  }

  /// Calculates the total completion count across all routines.
  int _getTotalWorkoutCount(List<Routine> routines) {
    // Use fold for a concise sum, handling potential null for completionCount
    return routines.fold<int>(0, (sum, routine) => sum + (routine.completionCount ?? 0));
  }
} // End of _StatisticsPageState