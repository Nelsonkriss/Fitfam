import 'dart:math'; // For max() function used in chart data processing
import 'package:flutter/foundation.dart'; // For kDebugMode
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart'; // Charting library (v0.71.0 or similar)
import 'package:intl/intl.dart'; // Date formatting
import 'package:provider/provider.dart'; // Import Provider for BLoC access

// Import Models and the RxDart WorkoutSessionBloc (Adjust paths if needed)
import 'package:workout_planner/models/workout_session.dart';
// Needed indirectly via WorkoutSession
// Needed indirectly via WorkoutSession
// Needed indirectly via WorkoutSession
import 'package:workout_planner/bloc/workout_session_bloc.dart'; // Your RxDart BLoC

/// A StatefulWidget that displays workout progress charts.
/// It listens to a stream of WorkoutSession data provided by WorkoutSessionBloc.
class ProgressCharts extends StatefulWidget {
  const ProgressCharts({super.key});

  @override
  _ProgressChartsState createState() => _ProgressChartsState();
}

class _ProgressChartsState extends State<ProgressCharts> {

  @override
  void initState() {
    super.initState();
    // Access the WorkoutSessionBloc instance provided via Provider
    final sessionBloc = Provider.of<WorkoutSessionBloc>(context, listen: false);
    // Refresh the data when the widget is initialized
    sessionBloc.refreshData();
  }

  @override
  Widget build(BuildContext context) {
    // Access the WorkoutSessionBloc instance provided via Provider
    final sessionBloc = context.watch<WorkoutSessionBloc>();

    if (kDebugMode) print("Building ProgressCharts");

    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress Charts'),
      ),
      body: StreamBuilder<List<WorkoutSession>>(
        // Use the stream getter from your RxDart BLoC instance
        // ACTION REQUIRED: Verify this stream name is correct for your BLoC
        stream: sessionBloc.allSessionsStream,
        builder: (context, snapshot) {
          if (kDebugMode) {
            print("Session StreamBuilder state: ${snapshot.connectionState}");
            if (snapshot.hasData) {
              print("Received ${snapshot.data!.length} sessions");
            } else if (snapshot.hasError) print("Error in session stream: ${snapshot.error}");
          }
          if (snapshot.hasData) {
            print("ProgressCharts: Session data: ${snapshot.data}");
          }

          // --- Handle Different Stream States ---
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center( child: Padding( padding: const EdgeInsets.all(16.0), child: Text('Error loading workout data:\n${snapshot.error}', style: const TextStyle(color: Colors.red), textAlign: TextAlign.center,),),);
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            // Display a basic chart with no data
            return SizedBox(
              height: 300,
              child: Center(
                child: Text('No workout data available yet.\nComplete some sessions to see your progress!', textAlign: TextAlign.center,),
              ),
            );
          }

          // --- Data is Available ---
          final sessions = snapshot.data!;

          // Build the scrollable list view containing the charts
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // --- Volume Chart Section ---
              _buildSectionHeader(context, "Total Workout Volume", "Sum of (Weight x Reps) per day"),
              const SizedBox(height: 12),
              _buildVolumeChart(sessions), // Build the volume chart

              const SizedBox(height: 32), // Spacing between chart types

              // --- Exercise Progress Section ---
              _buildSectionHeader(context, "Exercise Max Weight", "Maximum weight lifted per day"),
              const SizedBox(height: 12),
              _buildExerciseProgressCharts(sessions), // Build the individual exercise charts

              const SizedBox(height: 16), // Bottom padding
            ],
          );
        },
      ),
    );
  }

  /// Helper widget to build consistent section headers.
  Widget _buildSectionHeader(BuildContext context, String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
        if (subtitle.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600)),
          ),
      ],
    );
  }

  /// Builds the chart displaying total workout volume over time.
  Widget _buildVolumeChart(List<WorkoutSession> sessions) {
    // 1. Process data: Aggregate volume per day
    final volumeByDate = <DateTime, double>{};
    for (final session in sessions) {
      if (!session.isCompleted || session.endTime == null) continue;
      double sessionVolume = 0;
      for (final exercise in session.exercises) {
        for (final set in exercise.sets) {
          if (set.isCompleted && set.actualWeight > 0 && set.actualReps > 0) {
            sessionVolume += (set.actualWeight * set.actualReps);
          }
        }
      }
      // Add the session to volumeByDate even if sessionVolume is 0
      final dateOnly = DateUtils.dateOnly(session.endTime!);
      volumeByDate.update(dateOnly, (v) => v + sessionVolume, ifAbsent: () => sessionVolume);
    }
    final volumeData = volumeByDate.entries
        .map((e) => FlSpot(e.key.millisecondsSinceEpoch.toDouble(), e.value))
        .toList();
    volumeData.sort((a, b) => a.x.compareTo(b.x)); // Sort chronologically

    // 2. Handle insufficient data
    if (volumeData.length < 2) {
      return SizedBox(
        height: 300,
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          clipBehavior: Clip.antiAlias,
          child: Center(child: Text("Not enough data for volume chart.")),
        ),
      );
    }

    // 3. Build the chart widget
    return SizedBox(
      height: 300,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 20, 20, 12),
          child: LineChart(
            LineChartData(
              // --- Interaction ---
              lineTouchData: LineTouchData(
                  handleBuiltInTouches: true,
                  touchTooltipData: LineTouchTooltipData(
                    // tooltipBgColor removed for fl_chart >= 0.70.0
                      maxContentWidth: 100,
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final date = DateTime.fromMillisecondsSinceEpoch(spot.x.toInt());
                          final dateStr = DateFormat.yMd().format(date);
                          return LineTooltipItem(
                              '${spot.y.toStringAsFixed(0)} kg\n', // Volume
                              TextStyle(color: Theme.of(context).colorScheme.onInverseSurface ?? Colors.white, fontWeight: FontWeight.bold),
                              children: [ TextSpan( text: dateStr, style: TextStyle(color: (Theme.of(context).colorScheme.onInverseSurface ?? Colors.white).withOpacity(0.8), fontSize: 12), ), ]
                          );
                        }).toList();
                      }
                  )
              ),
              // --- Data Series ---
              lineBarsData: [
                LineChartBarData(
                  spots: volumeData, isCurved: true, curveSmoothness: 0.35,
                  color: Colors.blueAccent.shade400, barWidth: 3, isStrokeCapRound: true,
                  dotData: FlDotData(show: volumeData.length < 40),
                  belowBarData: BarAreaData( show: true,
                      gradient: LinearGradient( colors: [ Colors.blueAccent.shade200.withOpacity(0.4), Colors.blueAccent.shade700.withOpacity(0.0) ], begin: Alignment.topCenter, end: Alignment.bottomCenter)
                  ),
                ),
              ],
              // --- Titles (Using Alternative Text Widget Approach) ---
              titlesData: FlTitlesData(
                show: true,
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: volumeData.length > 1, reservedSize: 30,
                    interval: _calculateDateInterval(volumeData),
                    getTitlesWidget: (double value, TitleMeta meta) { // Correct signature
                      String text = '';
                      if (value == meta.min || value == meta.max) { // Only show min/max labels
                        final DateTime date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                        text = DateFormat('MMM d').format(date);
                      }
                      // Return Text with Padding
                      return Padding( padding: const EdgeInsets.only(top: 6.0), child: Text(text, style: TextStyle(fontSize: 10, color: Colors.grey.shade700)), );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true, reservedSize: 45,
                    // interval: _calculateVolumeInterval(volumeData), // Let fl_chart determine interval
                    getTitlesWidget: (double value, TitleMeta meta) { // Correct signature
                      String text = '';
                      // Show non-zero min and max, format large numbers with 'k'
                      if ((value == meta.min && value > 0) || value == meta.max) {
                        if (value >= 1000) { text = '${(value / 1000).toStringAsFixed(value % 1000 >= 100 ? 1 : 0)}k'; }
                        else { text = value.toStringAsFixed(0); }
                      }
                      // Return Text widget aligned right
                      return Container( alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 4.0), child: Text( text, style: TextStyle(fontSize: 10, color: Colors.grey.shade700), textAlign: TextAlign.right, ), );
                    },
                  ),
                ),
              ), // End titlesData
              // --- Grid & Border ---
              gridData: FlGridData(
                show: true, drawVerticalLine: true, drawHorizontalLine: true,
                horizontalInterval: _calculateVolumeInterval(volumeData),
                verticalInterval: _calculateDateInterval(volumeData),
                getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade300, strokeWidth: 0.5),
                getDrawingVerticalLine: (value) => FlLine(color: Colors.grey.shade300, strokeWidth: 0.5),
              ),
              borderData: FlBorderData( show: true, border: Border.all(color: Colors.grey.shade400, width: 1), ),
              minY: 0, // Volume starts at 0
            ),
          ),
        ),
      ),
    );
  }

  /// Builds a Column containing charts for each individual exercise's max weight progression.
  Widget _buildExerciseProgressCharts(List<WorkoutSession> sessions) {
    // Extract unique, non-empty exercise names
    final exerciseNames = sessions.expand((s) => s.exercises).map((e) => e.exerciseName.trim()).where((name) => name.isNotEmpty).toSet();

    if (exerciseNames.isEmpty) {
      return const Padding( padding: EdgeInsets.symmetric(vertical: 16.0), child: Text("No specific exercises with weight tracked yet."), );
    }

    // Create a chart widget for each unique exercise name
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: exerciseNames.map((exerciseName) => Padding(
        padding: const EdgeInsets.only(top: 24.0),
        child: _buildSingleExerciseChart(sessions, exerciseName),
      )).toList(),
    );
  }

  /// Builds a line chart for a single exercise's max weight lifted over time.
  Widget _buildSingleExerciseChart(List<WorkoutSession> sessions, String exerciseName) {
    // 1. Process data: Aggregate MAX weight per day for this exercise
    final maxWeightPerDay = <DateTime, double>{};
    for (final session in sessions) {
      if (!session.isCompleted || session.endTime == null) continue;
      double maxWeightInSessionForExercise = 0;
      bool exerciseFoundInSession = false;
      for (final exercise in session.exercises) {
        if (exercise.exerciseName.trim() != exerciseName) continue;
        exerciseFoundInSession = true;
        for (final set in exercise.sets) {
          if (set.isCompleted && set.actualReps > 0 && set.actualWeight > 0) {
            maxWeightInSessionForExercise = max(maxWeightInSessionForExercise, set.actualWeight);
          }
        }
      }
      if (exerciseFoundInSession && maxWeightInSessionForExercise > 0) {
        final dateOnly = DateUtils.dateOnly(session.endTime!);
        maxWeightPerDay.update( dateOnly, (currentDailyMax) => max(currentDailyMax, maxWeightInSessionForExercise), ifAbsent: () => maxWeightInSessionForExercise );
      }
    }
    final dataPoints = maxWeightPerDay.entries.map((e) => FlSpot(e.key.millisecondsSinceEpoch.toDouble(), e.value)).toList();
    dataPoints.sort((a, b) => a.x.compareTo(b.x)); // Sort chronologically

    // 2. Handle insufficient data
    if (dataPoints.length < 2) {
      return SizedBox(
        height: 200,
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          clipBehavior: Clip.antiAlias,
          child: Center(child: Text("$exerciseName: Not enough data points for progress chart.", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey.shade600))),
        ),
      );
    }

    // 3. Build the chart widget
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(exerciseName, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        SizedBox(
          height: 200,
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 20, 20, 12),
              child: LineChart(
                LineChartData(
                  // Interaction
                  lineTouchData: LineTouchData(
                      handleBuiltInTouches: true,
                      touchTooltipData: LineTouchTooltipData(
                        // tooltipBgColor removed
                          maxContentWidth: 120,
                          getTooltipItems: (touchedSpots) {
                            return touchedSpots.map((spot) {
                              final date = DateTime.fromMillisecondsSinceEpoch(spot.x.toInt());
                              final dateStr = DateFormat.yMd().format(date);
                              final weightStr = spot.y.toStringAsFixed(spot.y.truncateToDouble() == spot.y ? 0 : 1);
                              return LineTooltipItem( '$weightStr kg\n', TextStyle(color: Theme.of(context).colorScheme.onInverseSurface ?? Colors.white, fontWeight: FontWeight.bold),
                                  children: [ TextSpan( text: dateStr, style: TextStyle(color: (Theme.of(context).colorScheme.onInverseSurface ?? Colors.white).withOpacity(0.8), fontSize: 12), ), ] );
                            }).toList();
                          }
                      )
                  ),
                  // Data Series
                  lineBarsData: [
                    LineChartBarData(
                      spots: dataPoints, isCurved: true, curveSmoothness: 0.35,
                      color: Colors.teal.shade600, barWidth: 3, isStrokeCapRound: true,
                      dotData: FlDotData(show: dataPoints.length < 40),
                      belowBarData: BarAreaData(show: false), // No fill for this one
                    ),
                  ],
                  // --- Titles (Using Alternative Approach - Text Widget) ---
                  titlesData: FlTitlesData(
                    show: true,
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: dataPoints.length > 1, reservedSize: 30,
                        interval: _calculateDateInterval(dataPoints),
                        // Use Text directly
                        getTitlesWidget: (double value, TitleMeta meta) { // Keep meta
                          String text = '';
                          if (value == meta.min || value == meta.max) {
                            final DateTime date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                            text = DateFormat('MMM d').format(date);
                          }
                          return Padding( padding: const EdgeInsets.only(top: 6.0), child: Text(text, style: TextStyle(fontSize: 10, color: Colors.grey.shade700)), );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true, reservedSize: 40,
                        // Use Text directly
                        getTitlesWidget: (double value, TitleMeta meta) { // Keep meta
                          String text = '';
                          if ((value == meta.min && value > 0) || value == meta.max) {
                            text = value.toStringAsFixed(0); // Weight as integer string
                          }
                          return Container( alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 4.0), child: Text( text, style: TextStyle(fontSize: 10, color: Colors.grey.shade700), textAlign: TextAlign.right, ), );
                        },
                      ),
                    ),
                  ), // End titlesData
                  // --- Grid & Border ---
                  gridData: FlGridData(
                    show: true, drawHorizontalLine: true, drawVerticalLine: true,
                    horizontalInterval: _calculateWeightInterval(dataPoints),
                    verticalInterval: _calculateDateInterval(dataPoints),
                    getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade300, strokeWidth: 0.5),
                    getDrawingVerticalLine: (value) => FlLine(color: Colors.grey.shade300, strokeWidth: 0.5),
                  ),
                  borderData: FlBorderData( show: true, border: Border.all(color: Colors.grey.shade400, width: 1), ),
                  minY: 0, // Weight starts at 0
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- Chart Helper Methods ---
  // (Helper methods remain unchanged, but keep them in the class)
  double? _calculateDateInterval(List<FlSpot> spots) {
    if (spots.length < 2) return null;
    final minDateEpoch = spots.first.x; final maxDateEpoch = spots.last.x;
    final durationMillis = (maxDateEpoch - minDateEpoch).toInt();
    if (durationMillis <= 0) return null;
    final durationDays = Duration(milliseconds: durationMillis).inDays;
    final double daysPerLabel = durationDays / 5.0;
    if (daysPerLabel <= 1.5) return const Duration(days: 1).inMilliseconds.toDouble();
    if (daysPerLabel <= 4) return const Duration(days: 2).inMilliseconds.toDouble();
    if (daysPerLabel <= 10) return const Duration(days: 7).inMilliseconds.toDouble();
    if (daysPerLabel <= 20) return const Duration(days: 14).inMilliseconds.toDouble();
    if (daysPerLabel <= 45) return const Duration(days: 30).inMilliseconds.toDouble();
    return null; // Let fl_chart decide for longer ranges
  }
  double? _calculateVolumeInterval(List<FlSpot> spots) {
    if (spots.isEmpty) return null;
    double maxVolume = spots.map((s) => s.y).fold(0.0, max);
    if (maxVolume <= 0) return 100;
    double interval = maxVolume / 5.0;
    if (interval <= 100) return 100; if (interval <= 250) return 250;
    if (interval <= 500) return 500; if (interval <= 1000) return 1000;
    return (interval / 1000).ceilToDouble() * 1000;
  }
  double? _calculateWeightInterval(List<FlSpot> spots) {
    if (spots.isEmpty) return null;
    double maxWeight = spots.map((s) => s.y).fold(0.0, max);
    if (maxWeight <= 0) return 10;
    double interval = maxWeight / 5.0;
    if (interval <= 2.5) return 2.5; if (interval <= 5) return 5.0;
    if (interval <= 10) return 10.0; if (interval <= 20) return 20.0;
    if (interval <= 25) return 25.0; if (interval <= 50) return 50.0;
    return (interval / 50).ceilToDouble() * 50;
  }

} // End of _ProgressChartsState