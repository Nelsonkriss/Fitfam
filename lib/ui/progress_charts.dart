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

class ProgressCharts extends StatefulWidget {
  const ProgressCharts({super.key});

  @override
  State<ProgressCharts> createState() => _ProgressChartsState();
}

class _ProgressChartsState extends State<ProgressCharts> {
  final Stopwatch _stopwatch = Stopwatch();

  @override
  void initState() {
    super.initState();
    final sessionBloc = Provider.of<WorkoutSessionBloc>(context, listen: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        if (kDebugMode) {
          print("[ProgressCharts] initState: Refreshing session data in post-frame callback");
        }
        sessionBloc.refreshAllSessions();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final sessionBloc = context.watch<WorkoutSessionBloc>();

    if (kDebugMode) {
      _stopwatch.reset(); _stopwatch.start();
      debugPrint("[ProgressCharts] Build method called: ${_stopwatch.elapsedMilliseconds}ms");
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress Charts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh Data",
            onPressed: () {
              sessionBloc.refreshAllSessions();
            },
          ),
        ],
      ),
      body: StreamBuilder<List<WorkoutSession>>(
        stream: sessionBloc.allSessionsStream,
        builder: (context, snapshot) {
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
                      Text('Error loading workout data:', style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      Text('${snapshot.error}', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.red.shade700), textAlign: TextAlign.center),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(icon: const Icon(Icons.refresh), label: const Text('Retry'), onPressed: () => sessionBloc.refreshAllSessions())
                    ],
                  )
              ),
            );
          }

          final List<WorkoutSession> completedSessions = (snapshot.data ?? [])
              .where((s) => s.isCompleted && s.endTime != null)
              .toList();

          if (completedSessions.isEmpty) {
            return Center( // Removed const
                child: Padding( // Removed const
                  padding: const EdgeInsets.all(20.0), // Padding can be const
                  child: Text("No completed workout sessions found.\nComplete a workout to see progress charts here!", textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                )
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSectionHeader(context, "Total Workout Volume", "Sum of (Weight x Reps) per day"),
              const SizedBox(height: 12),
              _buildVolumeChart(completedSessions),
              const SizedBox(height: 32),
              _buildSectionHeader(context, "Exercise Max Weight", "Maximum weight lifted per day for each exercise"),
              const SizedBox(height: 12),
              _buildExerciseProgressCharts(completedSessions),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
        if (subtitle.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
      ],
    );
  }

  Widget _buildVolumeChart(List<WorkoutSession> sessions) {
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
        .toList()..sort((a, b) => a.x.compareTo(b.x));

    if (volumeData.length < 2) return _buildChartPlaceholder("Not enough workout data for volume trends.");

    return SizedBox(
      height: 300,
      child: Card(
        elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 20, 20, 12),
          child: LineChart(
            LineChartData(
              lineTouchData: LineTouchData(
                  handleBuiltInTouches: true,
                  touchTooltipData: LineTouchTooltipData(
                      tooltipBgColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.9),
                      maxContentWidth: 100,
                      getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
                        final date = DateTime.fromMillisecondsSinceEpoch(spot.x.toInt());
                        return LineTooltipItem(
                            '${spot.y.toStringAsFixed(0)} kg\n',
                            TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold),
                            children: [TextSpan(text: DateFormat.yMd().format(date), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.8), fontSize: 12))]);
                      }).toList())),
              lineBarsData: [
                LineChartBarData(
                    spots: volumeData, isCurved: true, curveSmoothness: 0.35, color: Theme.of(context).colorScheme.primary, barWidth: 3, isStrokeCapRound: true,
                    dotData: FlDotData(show: volumeData.length < 40),
                    belowBarData: BarAreaData(show: true, gradient: LinearGradient(colors: [Theme.of(context).colorScheme.primary.withOpacity(0.4), Theme.of(context).colorScheme.primary.withOpacity(0.0)], begin: Alignment.topCenter, end: Alignment.bottomCenter)))],
              titlesData: FlTitlesData(
                  show: true, topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, interval: _calculateDateInterval(volumeData), getTitlesWidget: _bottomTitleWidgets)),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 45, getTitlesWidget: (value, meta) => _leftTitleWidgets(value, meta, true)))),
              gridData: FlGridData(
                  show: true, drawVerticalLine: true, drawHorizontalLine: true, horizontalInterval: _calculateVolumeInterval(volumeData), verticalInterval: _calculateDateInterval(volumeData),
                  getDrawingHorizontalLine: (value) => FlLine(color: Theme.of(context).dividerColor.withOpacity(0.5), strokeWidth: 0.5),
                  getDrawingVerticalLine: (value) => FlLine(color: Theme.of(context).dividerColor.withOpacity(0.5), strokeWidth: 0.5)),
              borderData: FlBorderData(show: true, border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.5), width: 1)),
              minY: 0,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExerciseProgressCharts(List<WorkoutSession> sessions) {
    final exerciseNames = sessions.expand((s) => s.exercises).map((e) => e.exerciseName.trim()).where((name) => name.isNotEmpty).toSet();
    if (exerciseNames.isEmpty) return const Padding(padding: EdgeInsets.symmetric(vertical: 16.0), child: Text("No specific exercises with weight tracked yet."));

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: exerciseNames.map((name) => Padding(padding: const EdgeInsets.only(top: 24.0), child: _buildSingleExerciseChart(sessions, name))).toList());
  }

  Widget _buildSingleExerciseChart(List<WorkoutSession> sessions, String exerciseName) {
    final maxWeightPerDay = <DateTime, double>{};
    for (final session in sessions) {
      double maxWeightInSession = 0;
      for (final exercise in session.exercises) {
        if (exercise.exerciseName.trim() != exerciseName) continue;
        for (final set in exercise.sets) {
          if (kDebugMode) {
             debugPrint("[ProgressCharts] Processing set for ${exercise.exerciseName}: isCompleted=${set.isCompleted}, actualReps=${set.actualReps}, actualWeight=${set.actualWeight}");
          }
          if (set.isCompleted && set.actualReps > 0 && set.actualWeight > 0) {
            maxWeightInSession = max(maxWeightInSession, set.actualWeight);
          }
        }
      }
      if (maxWeightInSession > 0) {
        final dateOnly = DateUtils.dateOnly(session.endTime!);
        maxWeightPerDay.update(dateOnly, (currentMax) => max(currentMax, maxWeightInSession), ifAbsent: () => maxWeightInSession);
      }
    }
    final dataPoints = maxWeightPerDay.entries.map((e) => FlSpot(e.key.millisecondsSinceEpoch.toDouble(), e.value)).toList()..sort((a, b) => a.x.compareTo(b.x));

    if (kDebugMode) {
      // Log the generated data points (date and max weight) for this exercise
      final formattedPoints = dataPoints.map((p) => '(${DateFormat('yyyy-MM-dd').format(DateTime.fromMillisecondsSinceEpoch(p.x.toInt()))}: ${p.y})').join(', ');
      debugPrint("[ProgressCharts] Final data points for '$exerciseName': [$formattedPoints]");
    }

    if (dataPoints.length < 2) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(exerciseName, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500)), const SizedBox(height: 8), _buildChartPlaceholder("Not enough data for '$exerciseName'.")]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(exerciseName, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        SizedBox(
          height: 200,
          child: Card(
            elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 20, 20, 12),
              child: LineChart(
                LineChartData(
                  lineTouchData: LineTouchData(handleBuiltInTouches: true, touchTooltipData: LineTouchTooltipData(
                    tooltipBgColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.9),
                    maxContentWidth: 120, getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
                    final date = DateTime.fromMillisecondsSinceEpoch(spot.x.toInt());
                    final weightStr = spot.y.toStringAsFixed(spot.y.truncateToDouble() == spot.y ? 0 : 1);
                    return LineTooltipItem('$weightStr kg\n', TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold), children: [TextSpan(text: DateFormat.yMd().format(date), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.8), fontSize: 12))]);
                  }).toList())),
                  lineBarsData: [LineChartBarData(spots: dataPoints, isCurved: true, curveSmoothness: 0.35, color: Theme.of(context).colorScheme.secondary, barWidth: 3, isStrokeCapRound: true, dotData: FlDotData(show: dataPoints.length < 40), belowBarData: BarAreaData(show: false))],
                  titlesData: FlTitlesData(show: true, topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, interval: _calculateDateInterval(dataPoints), getTitlesWidget: _bottomTitleWidgets)),
                      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (value, meta) => _leftTitleWidgets(value, meta, false)))),
                  gridData: FlGridData(show: true, drawHorizontalLine: true, drawVerticalLine: true, horizontalInterval: _calculateWeightInterval(dataPoints), verticalInterval: _calculateDateInterval(dataPoints),
                      getDrawingHorizontalLine: (value) => FlLine(color: Theme.of(context).dividerColor.withOpacity(0.5), strokeWidth: 0.5),
                      getDrawingVerticalLine: (value) => FlLine(color: Theme.of(context).dividerColor.withOpacity(0.5), strokeWidth: 0.5)),
                  borderData: FlBorderData(show: true, border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.5), width: 1)),
                  minY: 0,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChartPlaceholder(String message) => SizedBox(
    height: 200,
    child: Card( // Card will use CardTheme
      // color: Theme.of(context).colorScheme.surfaceVariant, // Or let CardTheme handle it
      child: Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant))))
    )
  );

  // --- Chart Title Helper Widgets (Reverting to axisSide) ---
  Widget _bottomTitleWidgets(double value, TitleMeta meta) {
    final style = TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)); // Themed
    Widget text;
    try {
      text = Text(DateFormat('MMM d').format(DateTime.fromMillisecondsSinceEpoch(value.toInt())), style: style);
    } catch (_) {
      text = Text('', style: style);
    }
    // REVERTING TO axisSide as per fl_chart 0.66.2 API
    return SideTitleWidget(
        axisSide: meta.axisSide,
        space: 4.0, // You can adjust or remove if default is preferred
        child: text
    );
  }

  Widget _leftTitleWidgets(double value, TitleMeta meta, bool isVolumeChart) {
    final style = TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontWeight: FontWeight.w600); // Themed
    String textValue = '';
    if (value == meta.min || value > 0 || meta.max == 0) {
      textValue = isVolumeChart
          ? (value >= 1000 ? '${(value / 1000).toStringAsFixed(1)}k' : value.toStringAsFixed(0))
          : value.toStringAsFixed(0);
    }
    // REVERTING TO axisSide as per fl_chart 0.66.2 API
    return SideTitleWidget(
        axisSide: meta.axisSide,
        space: 4.0, // You can adjust or remove if default is preferred
        child: Text(textValue, style: style, textAlign: TextAlign.right)
    );
  }

  double? _calculateDateInterval(List<FlSpot> spots) {
    if (spots.length < 2) return null;
    final durationDays = Duration(milliseconds: (spots.last.x - spots.first.x).toInt()).inDays;
    if (durationDays <= 0) return null;
    if (durationDays <= 7) return const Duration(days: 1).inMilliseconds.toDouble();
    if (durationDays <= 30) return const Duration(days: 7).inMilliseconds.toDouble();
    if (durationDays <= 90) return const Duration(days: 14).inMilliseconds.toDouble();
    return (durationDays / 6.0).round() * const Duration(days: 1).inMilliseconds.toDouble();
  }

  double? _calculateCommonInterval(List<FlSpot> spots, List<double> steps, {double defaultMax = 10, double divisor = 5.0}) {
    if (spots.isEmpty) return null;
    double maxValue = spots.map((s) => s.y).fold(0.0, max);
    if (maxValue <= 0) return defaultMax;
    double interval = maxValue / divisor;
    if (interval == 0) return defaultMax;

    for (final step in steps) {
      if (interval <= step) return step;
    }
    final largestStep = steps.last;
    return (interval / largestStep).ceil() * largestStep;
  }

  double? _calculateVolumeInterval(List<FlSpot> spots) {
    return _calculateCommonInterval(spots, [100, 250, 500, 1000, 2500, 5000], defaultMax: 100);
  }

  double? _calculateWeightInterval(List<FlSpot> spots) {
    return _calculateCommonInterval(spots, [2.5, 5, 10, 20, 25, 50], defaultMax: 10);
  }
}