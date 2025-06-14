import 'dart:async'; // For Future
// For max() if needed by helpers, used in _getRatio calculation

import 'package:flutter/foundation.dart'; // For kDebugMode
import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart'; // For weekly progress
import 'package:provider/provider.dart'; // To access BLoCs

// Import BLoCs and Providers (Adjust paths if needed)
import 'package:workout_planner/bloc/routines_bloc.dart'; // Your RxDart BLoC
import 'package:workout_planner/bloc/workout_session_bloc.dart'; // Now needed for workout session data
import 'package:workout_planner/resource/shared_prefs_provider.dart'; // For getFirstRunDate
// Re-add import statement

// Import Models and UI Components
import 'package:workout_planner/models/routine.dart';
import 'package:workout_planner/models/workout_session.dart';
import 'package:workout_planner/models/part.dart'; // Import Part model
import 'package:workout_planner/ui/calender_page.dart'; // Your Calendar Page implementation
import 'package:workout_planner/ui/components/chart.dart'; // Assuming DonutAutoLabelChart is here

// Default text styles for cards are now replaced by theme-aware styles below.


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
    final workoutSessionBlocInstance = context.watch<WorkoutSessionBloc>();

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

            // Now also listen to workout sessions for the body part chart
            return StreamBuilder<List<WorkoutSession>>(
              stream: workoutSessionBlocInstance.allSessionsStream,
              builder: (context, sessionSnapshot) {
                if (kDebugMode) {
                  print("Statistics Session StreamBuilder state: ${sessionSnapshot.connectionState}");
                  if (sessionSnapshot.hasData) {
                    print("StatisticsPage: Session data: ${sessionSnapshot.data?.length} sessions");
                  }
                }

                // Handle session stream states - but don't block UI if sessions are loading
                final sessions = sessionSnapshot.data ?? [];

                // --- Build Layout ---
                // Use CustomScrollView to combine slivers and regular widgets easily
                return CustomScrollView(
                  slivers: <Widget>[
                    // 1. Statistics Grid (uses routine data and session data)
                    _buildStatisticsGrid(context, routines, sessions), // Pass both routines and sessions

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
            );
          },
        ),
      ),
    );
  }

  /// Builds the 2x2 grid of statistics cards as a Sliver.
  Widget _buildStatisticsGrid(BuildContext context, List<Routine> routines, List<WorkoutSession> sessions) {
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
                Text('Using since', textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelMedium),
                Text(displayFirstRunDate, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500)),
                const Spacer(flex: 2),
                Expanded(
                    flex: 5,
                    child: FittedBox(fit: BoxFit.contain, child: Text('$daysSince', textAlign: TextAlign.center, style: Theme.of(context).textTheme.displaySmall))
                ),
                const Spacer(flex: 1),
                Text('Days Ago', textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelMedium),
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
                Text('Total Workouts\nCompleted', textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelMedium),
                const Spacer(flex: 2),
                Expanded(
                  flex: 5,
                  child: FittedBox(fit: BoxFit.contain, child: Text( totalCompletionCount.toString(), textAlign: TextAlign.center, style: Theme.of(context).textTheme.displaySmall)),
                ),
                const Spacer(flex: 3),
              ],
            ),
          ),

          // --- Card 3: Body Parts Trained (Donut Chart) ---
          _buildInfoCard(
            context: context,
            child: Padding(
              padding: const EdgeInsets.all(6.0), // Reduced padding
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Body Parts Trained", style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 8), // Reduced spacing
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        // Extract body parts from completed workout sessions instead of routine templates
                        final List<Part> trainedParts = _extractTrainedBodyParts(sessions, routines);
                        return (trainedParts.isEmpty)
                            ? Center(child: Text("No completed\nworkouts", textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall))
                            : Padding(
                                padding: const EdgeInsets.all(4.0), // Small padding around chart
                                child: DonutAutoLabelChart(trainedParts, animate: true),
                              );
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
                      Text("Weekly Progress", textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelMedium),
                      const Spacer(flex: 1), // Reduced flex
                      CircularPercentIndicator(
                        radius: 45.0, // Slightly reduced radius
                        lineWidth: 9.0, // Slightly reduced line width
                        animation: true,
                        animationDuration: 800,
                        percent: weeklyRatio,
                        center: Text( "${(weeklyRatio * 100).toStringAsFixed(0)}%",
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold), // Slightly smaller text
                        ),
                        circularStrokeCap: CircularStrokeCap.round,
                        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                        progressColor: Theme.of(context).colorScheme.secondary,
                      ),
                      const Spacer(flex: 2), // Reduced flex
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
      // Card properties like shape, elevation, and color will be inherited from CardTheme in main.dart
      // color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface, // Example if CardTheme didn't set color
      child: Padding(
        padding: const EdgeInsets.all(12.0), // Increased padding for content within card
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

  /// Extracts body parts from completed workout sessions.
  /// Maps exercise names back to their original body part classifications using routine data.
  List<Part> _extractTrainedBodyParts(List<WorkoutSession> sessions, List<Routine> routines) {
    if (sessions.isEmpty) return [];

    // Create a map of exercise names to their targeted body parts from routine templates
    final Map<String, TargetedBodyPart> exerciseToBodyPartMap = {};
    for (final routine in routines) {
      for (final part in routine.parts) {
        for (final exercise in part.exercises) {
          exerciseToBodyPartMap[exercise.name] = part.targetedBodyPart;
        }
      }
    }

    // Process completed sessions to count trained body parts
    final Map<TargetedBodyPart, int> bodyPartCounts = {};
    
    // Only consider completed sessions
    final completedSessions = sessions.where((session) => session.isCompleted && session.endTime != null);
    
    for (final session in completedSessions) {
      // Track unique body parts per session to avoid counting multiple exercises
      // targeting the same body part within one session
      final Set<TargetedBodyPart> sessionBodyParts = {};
      
      for (final exercisePerf in session.exercises) {
        // Look up the body part for this exercise
        final bodyPart = exerciseToBodyPartMap[exercisePerf.exerciseName];
        if (bodyPart != null) {
          sessionBodyParts.add(bodyPart);
        }
      }
      
      // Count each unique body part trained in this session
      for (final bodyPart in sessionBodyParts) {
        bodyPartCounts[bodyPart] = (bodyPartCounts[bodyPart] ?? 0) + 1;
      }
    }

    // Convert counts back to Part objects for the chart
    final List<Part> trainedParts = [];
    bodyPartCounts.forEach((bodyPart, count) {
      // Create a Part for each body part that was trained
      for (int i = 0; i < count; i++) {
        trainedParts.add(Part(
          targetedBodyPart: bodyPart,
          setType: SetType.Regular, // Default set type as it's not relevant for the chart
          exercises: [], // Empty exercises list as it's not needed for the chart
        ));
      }
    });

    return trainedParts;
  }
} // End of _StatisticsPageState
