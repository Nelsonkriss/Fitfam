// Keep if used by helpers/components
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Import Provider
import 'package:intl/intl.dart'; // For date formatting

// Import Models and BLoC (adjust paths if needed)
// Keep if RoutineCard needs it
import 'package:workout_planner/models/workout_session.dart';
import 'package:workout_planner/bloc/workout_session_bloc.dart'; // Your RxDart Bloc
import 'package:workout_planner/ui/components/routine_card.dart'; // Make sure path is correct

// Removed local DateTimeFormatting extension


/// A widget displaying a yearly calendar heatmap of completed workouts.
class CalenderPage extends StatelessWidget {
  const CalenderPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Access the WorkoutSessionBloc instance via Provider
    final workoutSessionBloc = context.watch<WorkoutSessionBloc>();

    if (kDebugMode) {
      print("Building CalenderPage - start");
      Stopwatch().start(); // No need to store reference as it's not used later
    }

    final stopwatch = Stopwatch();
    return StreamBuilder<List<WorkoutSession>>(
      // ACTION REQUIRED: Verify stream name in WorkoutSessionBloc
      stream: workoutSessionBloc.allSessionsStream, // Listen to session stream
      builder: (context, snapshot) {
        if (kDebugMode) {
          print("Calendar StreamBuilder state: ${snapshot.connectionState}, HasData: ${snapshot.hasData}, Error: ${snapshot.hasError}");
          if (snapshot.hasData) {
            print("Calendar StreamBuilder: Received ${snapshot.data!.length} sessions.");
          }
          if (snapshot.hasError) {
            print("Calendar StreamBuilder Error: ${snapshot.error}");
          }
        }

        // --- Handle Stream States ---
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          // Provide a fixed height during loading to prevent layout jumps
          return const SizedBox( height: 400, child: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return SizedBox( height: 400, child: Center(child: Text('Error loading sessions: ${snapshot.error}')));
        }
        // Use empty list if snapshot has no data or it's empty
        final sessions = snapshot.data ?? [];

        // --- Process Data ---
        // Only build map if needed (avoids processing empty list unnecessarily)
        final Map<String, WorkoutSession> workoutDayMap = sessions.isNotEmpty
            ? _getWorkoutDayMap(sessions)
            : {}; // Empty map if no sessions

        if (kDebugMode && sessions.isNotEmpty) print("Calendar processed ${workoutDayMap.length} workout days");

        // --- Build UI ---
        // Show empty state directly if map is empty after processing
        // Show empty state directly if map is empty after processing
        //if (workoutDayMap.isEmpty && sessions.isNotEmpty) {
        //  // This case means sessions exist but none were completed with an end date
        //  return const SizedBox( height: 400, child: Center(child: Text('No completed workouts found with valid dates.')));
        //}
        //if (sessions.isEmpty) {
        //  return const SizedBox( height: 400, child: Center(child: Text('Complete some workouts to see them here!')));
        //}


        // Build the Calendar Grid UI if there's data
        final calendarGrid = _buildCalendarGrid(context, workoutDayMap);
        if (kDebugMode) {
          print("Building CalenderPage - end");
        }
        return calendarGrid;
      },
    );
  }

  /// Processes the list of sessions to create a map of completed dates.
  /// Key: 'YYYY-MM-DD' string, Value: The WorkoutSession completed on that day.
  Map<String, WorkoutSession> _getWorkoutDayMap(List<WorkoutSession> sessions) {
    Stopwatch? stopwatch;
    if (kDebugMode) {
      print("Building WorkoutDayMap - start");
      stopwatch = Stopwatch()..start();
    }

    final Map<String, WorkoutSession> dates = {};
    for (var session in sessions) {
      // Use only completed sessions with a valid end time
      if (session.isCompleted && session.endTime != null) {
        try {
          // Use the date part only, using the phone's LOCAL time for the key
          final localEndTime = session.endTime!.toLocal();
          final dateStr = "${localEndTime.year}-${localEndTime.month.toString().padLeft(2, '0')}-${localEndTime.day.toString().padLeft(2, '0')}";
          // Store the session (overwrites if multiple on same day - keeps last processed)
          dates[dateStr] = session;
        } catch (e) {
          debugPrint("Error processing session end time for calendar map: ${session.endTime}, Error: $e");
        }
      }
    }

    if (kDebugMode && stopwatch != null) {
      stopwatch.stop();
      print("Building WorkoutDayMap - end: ${stopwatch.elapsedMilliseconds}ms");
    }

    return dates;
  }

  /// Builds the GridView for the calendar heatmap.
  Widget _buildCalendarGrid(BuildContext context, Map<String, WorkoutSession> workoutDayMap) {
    final currentYear = DateTime.now().year; // Display current year
    const int columns = 13; // 1 (Day Label) + 12 (Months)
    final List<Widget> gridChildren = [];
    final TextTheme textTheme = Theme.of(context).textTheme; // Cache theme

    // --- Header Row (Months) ---
    gridChildren.add(const SizedBox.shrink()); // Empty top-left cell
    for (int month = 1; month <= 12; month++) {
      gridChildren.add(Center(
          child: Text(_intToMonth(month), // Use helper
              style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)) // Use theme style
      ));
    }

    // --- Day Rows (1 to 31) ---
    for (int day = 1; day <= 31; day++) {
      // Add Day Label (1st column)
      gridChildren.add(Center(
          child: Text(day.toString(),
              style: textTheme.bodySmall?.copyWith(color: Colors.grey)) // Use theme style
      ));
      // Add Cells for each month (Columns 2-13)
      for (int month = 1; month <= 12; month++) {
        DateTime? currentDate;
        // Validate if the date exists (e.g., handle Feb 30th)
        // Use local DateTime constructor
        if (day <= DateUtils.getDaysInMonth(currentYear, month)) {
          currentDate = DateTime(currentYear, month, day); // Uses local timezone
        }

        if (currentDate == null) {
          // Cell for non-existent dates (e.g., Feb 30/31)
          gridChildren.add(Container(color: Theme.of(context).scaffoldBackgroundColor)); // Match background
        } else {
          // Format the check key using local date components directly
          final dateStr = "${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}-${currentDate.day.toString().padLeft(2, '0')}";
          final bool isWorkoutDay = workoutDayMap.containsKey(dateStr);
          final WorkoutSession? sessionForDay = workoutDayMap[dateStr];

          gridChildren.add(
              Tooltip( // Add tooltip for context
                message: isWorkoutDay
                    ? "Workout on ${DateFormat.yMMMEd().format(currentDate)}"
                    : DateFormat.yMMMEd().format(currentDate),
                child: Material(
                  color: _getColorForWorkoutDay(isWorkoutDay, currentDate), // Use helper for color
                  shape: RoundedRectangleBorder( // Add subtle border
                    side: BorderSide(color: Colors.grey.shade300, width: 0.5),
                  ),
                  child: InkWell(
                    onTap: isWorkoutDay && sessionForDay != null
                        ? () => _showWorkoutDetailsSheet(context, sessionForDay) // Show details
                        : null, // Disable tap if not a workout day
                    // Ensure InkWell has a child (can be empty Container) to show ripple
                    child: const SizedBox(width: double.infinity, height: double.infinity), // Fill cell
                  ),
                ),
              )
          );
        }
      }
    }

    // Build the Grid - assumes used within a vertically scrolling parent like ListView/CustomScrollView
    return GridView.count(
      crossAxisCount: columns,
      shrinkWrap: true, // Essential if nested vertically
      physics: const NeverScrollableScrollPhysics(), // Prevent grid scrolling itself
      mainAxisSpacing: 1.5, // Fine-tune spacing
      crossAxisSpacing: 1.5, // Fine-tune spacing
      children: gridChildren,
    );
  }

  /// Determines the color for a calendar cell based on workout status and date.
  Color _getColorForWorkoutDay(bool isWorkoutDay, DateTime date) { // 'date' is now local
    // Get today's date using local time
    final nowLocal = DateTime.now();
    final todayLocal = DateTime(nowLocal.year, nowLocal.month, nowLocal.day); // Local date part only
    final cellDate = date; // 'date' parameter is already the local date of the cell

    // Log the comparison specifically for today's cell
    if (kDebugMode && cellDate.year == todayLocal.year && cellDate.month == todayLocal.month && cellDate.day == todayLocal.day) {
      debugPrint("[CalendarColor] Comparing for today: cellDate=$cellDate (Local), todayLocal=$todayLocal, isWorkoutDay=$isWorkoutDay");
    }

    // Using Theme colors for consistency
    final Color workoutColor = Colors.green.shade400; // Or Theme.of(context).colorScheme.primaryContainer
    final Color todayWorkoutColor = Colors.deepOrangeAccent.shade100; // Or Theme.of(context).colorScheme.tertiaryContainer
    final Color todayColor = Colors.grey.shade300; // Or Theme.of(context).colorScheme.outlineVariant
    final Color defaultColor = Colors.grey.shade100; // Or Theme.of(context).colorScheme.surfaceVariant

    if (isWorkoutDay) {
      // Compare year, month, and day for "is today" check using local dates
      bool isToday = cellDate.year == todayLocal.year &&
                     cellDate.month == todayLocal.month &&
                     cellDate.day == todayLocal.day;
      return isToday ? todayWorkoutColor : workoutColor;
    } else {
      bool isToday = cellDate.year == todayLocal.year &&
                     cellDate.month == todayLocal.month &&
                     cellDate.day == todayLocal.day;
      return isToday ? todayColor : defaultColor;
    }
  }


  /// Shows a modal bottom sheet with details of the selected workout session.
  void _showWorkoutDetailsSheet(BuildContext context, WorkoutSession session) {
    showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder( // Rounded top corners
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        isScrollControlled: true, // Allow sheet to take more height if needed
        builder: (BuildContext sheetContext) {
          // Use SafeArea to avoid system intrusions (notch, navigation bar)
          return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20), // Consistent padding
                child: Wrap( // Use Wrap to allow content height to adapt
                  children: [
                    // Header with Date
                    Text(
                      "Workout on ${DateFormat.yMMMMEEEEd().format(session.endTime!.toLocal())}", // More detailed date format
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Divider(height: 24, thickness: 0.5),
                    // Display RoutineCard (ensure it's reasonably sized)
                    // Consider creating a SessionSummaryCard if RoutineCard is too complex/large here
                    RoutineCard(routine: session.routine),
                    // Add more session details if needed (e.g., Duration)
                    if (session.endTime != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: Center(child: Text("Duration: ${_formatDuration(session.duration)}")),
                      ),
                    const SizedBox(height: 20),
                    // Close Button
                    Center(
                      child: TextButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          child: const Text("Close")
                      ),
                    )
                  ],
                ),
              )
          );
        });
  }

  /// Formats Duration to HH:MM:SS or MM:SS format.
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    } else {
      return "$twoDigitMinutes:$twoDigitSeconds";
    }
  }

  /// Converts month integer (1-12) to short string ('Jan'-'Dec') using intl.
  String _intToMonth(int month) {
    try {
      // Use DateFormat for locale-aware month abbreviations
      return DateFormat('MMM').format(DateTime(DateTime.now().year, month));
    } catch (_) {
      // Fallback for invalid month number
      const months = ['?', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return (month >= 1 && month <= 12) ? months[month] : '?';
    }
  }
}
