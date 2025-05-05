// lib/ui/progress_charts.dart

import 'dart:async';
import 'dart:math'; // For max() function used in chart data processing
import 'package:flutter/foundation.dart'; // For kDebugMode
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart'; // Charting library
import 'package:intl/intl.dart'; // Date formatting
import 'package:provider/provider.dart'; // Import Provider for BLoC access

// Import Models and the WorkoutSessionBloc (using bloc package)
import 'package:workout_planner/models/workout_session.dart';
import 'package:workout_planner/bloc/workout_session_bloc.dart'; // Your BLoC

/// A StatefulWidget that displays workout progress charts.
/// It listens to a stream of WorkoutSession data provided by WorkoutSessionBloc.
class ProgressCharts extends StatefulWidget {
  const ProgressCharts({super.key});

  @override
  State<ProgressCharts> createState() => _ProgressChartsState();
}

class _ProgressChartsState extends State<ProgressCharts> {
  // Class-level variable for performance monitoring (optional)
  final Stopwatch _stopwatch = Stopwatch();

  // NOTE: Stream subscription is handled by StreamBuilder

  @override
  void initState() {
    super.initState();
    // Access the WorkoutSessionBloc instance provided via Provider (don't listen here)
    final sessionBloc = Provider.of<WorkoutSessionBloc>(context, listen: false);

    // Refresh the data once after the first frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) { // Check if widget is still mounted
        if (kDebugMode) {
          print("[ProgressCharts] initState: Refreshing session data in post-frame callback");
        }
        // *** Call the correct method name ***
        sessionBloc.refreshAllSessions();
      }
    });
  }

  @override
  void dispose() {
    // No manual stream subscription to cancel here
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Access the WorkoutSessionBloc instance via Provider
    final sessionBloc = context.watch<WorkoutSessionBloc>();

    if (kDebugMode) {
      print("[ProgressCharts] Build method called");
      _stopwatch.reset(); _stopwatch.start();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress Charts'),
        actions: [
          // Add a refresh button to manually trigger data refresh
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh Data",
            onPressed: () {
              if (kDebugMode) {
                print("[ProgressCharts] AppBar Refresh: Manual refresh triggered");
              }
              // *** Call the correct method name ***
              sessionBloc.refreshAllSessions();
            },
          ),
        ],
      ),
      body: StreamBuilder<List<WorkoutSession>>(
        // Use the allSessionsStream getter from the BLoC instance
        stream: sessionBloc.allSessionsStream,
        builder: (context, snapshot) {
          // Debug logging for stream updates
          if (kDebugMode) {
            debugPrint("[ProgressCharts] StreamBuilder rebuild - ConnectionState: ${snapshot.connectionState}");
            if (snapshot.hasData) {
              debugPrint("[ProgressCharts] Stream has data - Session count: ${snapshot.data!.length}");
            } else if (snapshot.hasError) {
              debugPrint("[ProgressCharts] Stream has error: ${snapshot.error}");
            }
          }

          // --- Handle Different Stream States ---
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading workout data:',
                        style: Theme.of(context).textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${snapshot.error}', // Show the actual error
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.red.shade700),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                        onPressed: () => sessionBloc.refreshAllSessions(), // Call correct method
                      )
                    ],
                  )
              ),
            );
          }

          // Get the sessions data from the stream snapshot
          final List<WorkoutSession> allSessions = snapshot.data ?? [];

          // Filter out incomplete sessions BEFORE processing for charts
          final List<WorkoutSession> completedSessions = allSessions
              .where((s) => s.isCompleted && s.endTime != null)
              .toList();

          // Check if there are any completed sessions to display
          if (completedSessions.isEmpty) {
            return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text(
                    "No completed workout sessions found.\nComplete a workout to see progress charts here!",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
            );
          }

          // --- Build the main content with charts ---
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // --- Volume Chart Section ---
              _buildSectionHeader(context, "Total Workout Volume", "Sum of (Weight x Reps) per day"),
              const SizedBox(height: 12),
              _buildVolumeChart(completedSessions), // Pass only completed sessions

              const SizedBox(height: 32), // Spacing between chart types

              // --- Exercise Progress Section ---
              _buildSectionHeader(context, "Exercise Max Weight", "Maximum weight lifted per day for each exercise"),
              const SizedBox(height: 12),
              _buildExerciseProgressCharts(completedSessions), // Pass only completed sessions

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
    if (kDebugMode) {
      _stopwatch.reset(); _stopwatch.start();
      debugPrint("[ProgressCharts] Building VolumeChart with ${sessions.length} completed sessions");
    }

    // 1. Process data: Aggregate volume per day
    final volumeByDate = <DateTime, double>{};
    for (final session in sessions) {
      double sessionVolume = 0;
      for (final exercise in session.exercises) {
        for (final set in exercise.sets) {
          if (set.isCompleted && set.actualWeight > 0 && set.actualReps > 0) {
            sessionVolume += (set.actualWeight * set.actualReps);
          }
        }
      }
      final dateOnly = DateUtils.dateOnly(session.endTime!);
      volumeByDate.update(dateOnly, (v) => v + sessionVolume, ifAbsent: () => sessionVolume);
    }

    final volumeData = volumeByDate.entries
        .map((e) => FlSpot(e.key.millisecondsSinceEpoch.toDouble(), e.value))
        .toList();
    volumeData.sort((a, b) => a.x.compareTo(b.x));

    if (kDebugMode) {
      debugPrint("[ProgressCharts] Volume data points generated: ${volumeData.length}");
    }

    // 2. Handle insufficient data for display
    if (volumeData.length < 2) {
      return _buildChartPlaceholder("Not enough workout data for volume trends.");
    }

    // 3. Build the chart widget
    final Widget chart = SizedBox(
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
                      maxContentWidth: 100,
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final date = DateTime.fromMillisecondsSinceEpoch(spot.x.toInt());
                          return LineTooltipItem(
                              '${spot.y.toStringAsFixed(0)} kg\n',
                              TextStyle(color: Theme.of(context).colorScheme.onInverseSurface ?? Colors.white, fontWeight: FontWeight.bold),
                              children: [ TextSpan( text: DateFormat.yMd().format(date), style: TextStyle(color: (Theme.of(context).colorScheme.onInverseSurface ?? Colors.white).withOpacity(0.8), fontSize: 12), ), ]
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
              // --- Titles (Axis Labels) ---
              titlesData: FlTitlesData(
                show: true,
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true, // Let fl_chart handle showing/hiding based on interval
                    reservedSize: 30,
                    interval: _calculateDateInterval(volumeData),
                    // *** CORRECTED CALL to helper ***
                    getTitlesWidget: _bottomTitleWidgets,
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 45,
                    // interval: _calculateVolumeInterval(volumeData), // Optional: provide interval
                    // *** CORRECTED CALL to helper ***
                    getTitlesWidget: (value, meta) => _leftTitleWidgets(value, meta, true), // Pass isVolume=true
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
              minY: 0,
            ),
          ),
        ),
      ),
    );

    if (kDebugMode) {
      _stopwatch.stop();
      debugPrint("[ProgressCharts] Building VolumeChart - end: ${_stopwatch.elapsedMilliseconds}ms");
    }
    return chart;
  }

  /// Builds a Column containing charts for each individual exercise's max weight progression.
  Widget _buildExerciseProgressCharts(List<WorkoutSession> sessions) {
    if (kDebugMode) {
      _stopwatch.reset(); _stopwatch.start();
      debugPrint("[ProgressCharts] Building ExerciseProgressCharts with ${sessions.length} completed sessions");
    }

    // 1. Extract unique, non-empty exercise names
    final exerciseNames = sessions
        .expand((s) => s.exercises)
        .map((e) => e.exerciseName.trim())
        .where((name) => name.isNotEmpty)
        .toSet();

    if (kDebugMode) {
      debugPrint("[ProgressCharts] Found ${exerciseNames.length} unique exercises for progress charts.");
    }

    // 2. Handle case with no exercises tracked
    if (exerciseNames.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16.0),
        child: Text("No specific exercises with weight tracked yet in completed sessions."),
      );
    }

    // 3. Create a chart widget for each unique exercise name
    final List<Widget> exerciseCharts = exerciseNames.map((exerciseName) {
      final chartWidget = _buildSingleExerciseChart(sessions, exerciseName);
      return Padding(
        padding: const EdgeInsets.only(top: 24.0), // Spacing between exercise charts
        child: chartWidget,
      );
    }).toList();

    // 4. Return the column
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: exerciseCharts,
    );

    if (kDebugMode) {
      _stopwatch.stop();
      debugPrint("[ProgressCharts] Building ExerciseProgressCharts - end: ${_stopwatch.elapsedMilliseconds}ms");
    }
    return column;
  }

  /// Builds a line chart for a single exercise's max weight lifted over time.
  Widget _buildSingleExerciseChart(List<WorkoutSession> sessions, String exerciseName) {
    if (kDebugMode) {
      debugPrint("[ProgressCharts] Building chart for exercise: '$exerciseName'");
    }

    // 1. Process data: Aggregate MAX actual weight per day for this exercise
    final maxWeightPerDay = <DateTime, double>{};
    for (final session in sessions) {
      double maxWeightInSession = 0;
      bool exerciseFound = false;
      for (final exercise in session.exercises) {
        if (exercise.exerciseName.trim() != exerciseName) continue;
        exerciseFound = true;
        for (final set in exercise.sets) {
          if (set.isCompleted && set.actualReps > 0 && set.actualWeight > 0) {
            maxWeightInSession = max(maxWeightInSession, set.actualWeight);
          }
        }
      }
      if (exerciseFound && maxWeightInSession > 0) {
        final dateOnly = DateUtils.dateOnly(session.endTime!);
        maxWeightPerDay.update( dateOnly, (currentMax) => max(currentMax, maxWeightInSession), ifAbsent: () => maxWeightInSession );
      }
    }

    if (kDebugMode) {
      debugPrint("[ProgressCharts] '$exerciseName' max weights found for ${maxWeightPerDay.length} days.");
    }

    final dataPoints = maxWeightPerDay.entries
        .map((e) => FlSpot(e.key.millisecondsSinceEpoch.toDouble(), e.value))
        .toList();
    dataPoints.sort((a, b) => a.x.compareTo(b.x));

    // 2. Handle insufficient data
    if (dataPoints.length < 2) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(exerciseName, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          _buildChartPlaceholder("Not enough data points for '$exerciseName' progress."),
        ],
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
                          maxContentWidth: 120,
                          getTooltipItems: (touchedSpots) {
                            return touchedSpots.map((spot) {
                              final date = DateTime.fromMillisecondsSinceEpoch(spot.x.toInt());
                              final weightStr = spot.y.toStringAsFixed(spot.y.truncateToDouble() == spot.y ? 0 : 1);
                              return LineTooltipItem(
                                  '$weightStr kg\n',
                                  TextStyle(color: Theme.of(context).colorScheme.onInverseSurface ?? Colors.white, fontWeight: FontWeight.bold),
                                  children: [ TextSpan( text: DateFormat.yMd().format(date), style: TextStyle(color: (Theme.of(context).colorScheme.onInverseSurface ?? Colors.white).withOpacity(0.8), fontSize: 12), ), ]
                              );
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
                      belowBarData: BarAreaData(show: false),
                    ),
                  ],
                  // Titles (Axis Labels)
                  titlesData: FlTitlesData(
                    show: true,
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: _calculateDateInterval(dataPoints),
                        // *** CORRECTED CALL to helper ***
                        getTitlesWidget: _bottomTitleWidgets,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        // interval: _calculateWeightInterval(dataPoints),
                        // *** CORRECTED CALL to helper ***
                        getTitlesWidget: (value, meta) => _leftTitleWidgets(value, meta, false), // Pass isVolume=false
                      ),
                    ),
                  ), // End titlesData
                  // Grid & Border
                  gridData: FlGridData(
                    show: true, drawHorizontalLine: true, drawVerticalLine: true,
                    horizontalInterval: _calculateWeightInterval(dataPoints),
                    verticalInterval: _calculateDateInterval(dataPoints),
                    getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade300, strokeWidth: 0.5),
                    getDrawingVerticalLine: (value) => FlLine(color: Colors.grey.shade300, strokeWidth: 0.5),
                  ),
                  borderData: FlBorderData( show: true, border: Border.all(color: Colors.grey.shade400, width: 1), ),
                  minY: 0,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Helper to build a placeholder widget when chart data is insufficient.
  Widget _buildChartPlaceholder(String message) {
    return SizedBox(
      height: 200,
      child: Card(
        elevation: 1, // Less pronounced than actual charts
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: Colors.grey.shade50, // Slightly different background
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text( message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey), ),
          ),
        ),
      ),
    );
  }

  // --- Chart Title Helper Widgets (Corrected Signatures) ---

  /// Builds the text widget for bottom (date) axis titles.
  Widget _bottomTitleWidgets(double value, TitleMeta meta) {
    const style = TextStyle(fontSize: 10, color: Color(0xff757575)); // Grey 700
    Widget textWidget;
    try {
      // Format the value (millisecondsSinceEpoch) provided by fl_chart
      final DateTime date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
      final formattedDate = DateFormat('MMM d').format(date);
      textWidget = Text(formattedDate, style: style);
    } catch (_) {
      textWidget = const Text('', style: style); // Default to empty on error
    }
    debugPrint("[ProgressCharts] _bottomTitleWidgets called for value: $value");
    // Use SideTitleWidget to apply standard spacing
    return SideTitleWidget(
      sideTitles: meta.sideTitles, // Use meta to get current side
      child: textWidget,
    );
  }

  /// Builds the text widget for left (value) axis titles (Volume or Weight).
  Widget _leftTitleWidgets(double value, TitleMeta meta, bool isVolumeChart) {
    debugPrint("[ProgressCharts] _leftTitleWidgets called for value: $value, isVolumeChart: $isVolumeChart");
    const style = TextStyle(fontSize: 10, color: Color(0xff757575)); // Grey 700
    String text = '';
    // Format the label based on the value provided by fl_chart at its intervals
    if (value > 0 || meta.max == 0) { // Show non-zero values or if max is zero
      if (isVolumeChart) {
        if (value >= 1000) { text = '${(value / 1000).toStringAsFixed(1)}k'; }
        else { text = value.toStringAsFixed(0); }
      } else {
        text = value.toStringAsFixed(0); // Weight as integer
      }
    }
    // Use SideTitleWidget to apply standard spacing and alignment
    return SideTitleWidget(
      sideTitles: meta.sideTitles, // Use meta to get current side
      child: Text(text, style: style, textAlign: TextAlign.right), // Align right
    );
  }

  // --- Chart Interval Helper Methods ---

  /// Calculates a reasonable interval for the date (X) axis.
  double? _calculateDateInterval(List<FlSpot> spots) {
    if (spots.length < 2) return null;
    final double minDateEpoch = spots.first.x;
    final double maxDateEpoch = spots.last.x;
    final double durationMillis = maxDateEpoch - minDateEpoch;
    if (durationMillis <= 0) return null;
    final int durationDays = Duration(milliseconds: durationMillis.toInt()).inDays;
    if (durationDays <= 0) return null;

    final double daysPerLabel = durationDays / 6.0; // Aim for ~6 labels
    if (daysPerLabel <= 1.5) return const Duration(days: 1).inMilliseconds.toDouble();
    if (daysPerLabel <= 4) return const Duration(days: 2).inMilliseconds.toDouble();
    if (daysPerLabel <= 10) return const Duration(days: 7).inMilliseconds.toDouble();
    if (daysPerLabel <= 20) return const Duration(days: 14).inMilliseconds.toDouble();
    if (daysPerLabel <= 45) return const Duration(days: 30).inMilliseconds.toDouble();
    return null; // Let fl_chart decide for longer ranges
  }

  /// Calculates a reasonable interval for the Volume (Y) axis.
  double? _calculateVolumeInterval(List<FlSpot> spots) {
    if (spots.isEmpty) return null;
    final double maxVolume = spots.map((s) => s.y).fold(0.0, max);
    if (maxVolume <= 0) return 100;
    double interval = maxVolume / 5.0; // Aim for ~5 lines
    // Snap to nice round numbers
    if (interval <= 100) return 100; if (interval <= 250) return 250;
    if (interval <= 500) return 500; if (interval <= 1000) return 1000;
    if (interval <= 2500) return 2500; if (interval <= 5000) return 5000;
    final powerOf10 = pow(10, (log(interval) / ln10).floor());
    return (interval / (powerOf10 / 2)).ceil() * (powerOf10 / 2); // Round up
  }

  /// Calculates a reasonable interval for the Weight (Y) axis.
  double? _calculateWeightInterval(List<FlSpot> spots) {
    if (spots.isEmpty) return null;
    final double maxWeight = spots.map((s) => s.y).fold(0.0, max);
    if (maxWeight <= 0) return 10;
    double interval = maxWeight / 5.0; // Aim for ~5 lines
    // Snap to nice round numbers for weights
    if (interval <= 2.5) return 2.5; if (interval <= 5) return 5.0;
    if (interval <= 10) return 10.0; if (interval <= 20) return 20.0;
    if (interval <= 25) return 25.0; if (interval <= 50) return 50.0;
    return (interval / 25).ceil() * 25.0; // Round up to nearest 25
  }
} // End of _ProgressChartsState class