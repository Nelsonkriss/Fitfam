import 'dart:math'; // For max() function used in chart data processing
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart'; // Needed for Date parsing and formatting

// Import Models (Adjust paths if necessary)
import 'package:workout_planner/models/routine.dart';
import 'package:workout_planner/models/main_targeted_body_part.dart';

/// A Line Chart displaying the maximum weight progression for a single exercise over time.
class StackedAreaLineChart extends StatelessWidget {
  final Exercise exercise;
  final bool animate;

  const StackedAreaLineChart(this.exercise, {this.animate = false, super.key});

  @override
  Widget build(BuildContext context) {
    final List<FlSpot> dataPoints = _createDataPointsFromHistory();

    if (dataPoints.length < 2) {
      return Center( /* ... No data message ... */ );
    }

    return LineChart(
      LineChartData(
        // --- Data ---
        lineBarsData: [
          LineChartBarData( /* ... spots, curve, color, dot, belowBarData ... */
            spots: dataPoints, isCurved: true, curveSmoothness: 0.35, barWidth: 3,
            color: Colors.deepOrangeAccent, isStrokeCapRound: true,
            dotData: FlDotData(show: dataPoints.length < 30),
            belowBarData: BarAreaData( show: true,
              gradient: LinearGradient( colors: [ Colors.deepOrangeAccent.withOpacity(0.4), Colors.deepOrangeAccent.withOpacity(0.0), ],
                begin: Alignment.topCenter, end: Alignment.bottomCenter, ),
            ),
          ),
        ],

        // --- Interaction ---
        lineTouchData: LineTouchData( /* ... Tooltip setup ... */
          enabled: true, handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            maxContentWidth: 120,
            getTooltipItems: (List<LineBarSpot> touchedBarSpots) { /* ... Tooltip item generation ... */
              return touchedBarSpots.map((barSpot) {
                final DateTime date = DateTime.fromMillisecondsSinceEpoch(barSpot.x.toInt());
                final String dateStr = DateFormat.yMd().format(date);
                final double weight = barSpot.y;
                final String weightStr = weight.toStringAsFixed(weight.truncateToDouble() == weight ? 0 : 1);
                return LineTooltipItem( '$weightStr kg \n', TextStyle(color: Theme.of(context).colorScheme.onInverseSurface, fontWeight: FontWeight.bold),
                  children: [ TextSpan( text: dateStr, style: TextStyle(color: Theme.of(context).colorScheme.onInverseSurface.withOpacity(0.8), fontSize: 12), ), ],
                  textAlign: TextAlign.center, );
              }).toList();
            },
          ),
        ),

        // --- Appearance (Titles - ALTERNATIVE APPROACH) ---
        titlesData: FlTitlesData(
          show: true,
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),

          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: dataPoints.length > 1,
              reservedSize: 30, // Adjust space as needed
              interval: _calculateDateInterval(dataPoints),
              // Use Text directly with manual padding
              getTitlesWidget: (double value, TitleMeta meta) { // meta still provided
                if (value == meta.min || value == meta.max) { // Show only min/max
                  final DateTime date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                  return Padding(
                    padding: const EdgeInsets.only(top: 6.0), // Manual spacing
                    child: Text(
                      DateFormat('MMM d').format(date),
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40, // Adjust space as needed
              // interval: _calculateWeightInterval(dataPoints), // Let fl_chart decide interval
              // Use Text directly with manual padding
              getTitlesWidget: (double value, TitleMeta meta) { // meta still provided
                if ((value == meta.min && value > 0) || value == meta.max) { // Show non-zero min & max
                  return Padding(
                    padding: const EdgeInsets.only(right: 4.0), // Manual spacing
                    child: Text(
                      '${value.toStringAsFixed(0)}kg',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                      textAlign: TextAlign.right,
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ), // End titlesData

        // --- Grid, Border, Min/Max ---
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true, drawHorizontalLine: true, drawVerticalLine: false,
          horizontalInterval: _calculateWeightInterval(dataPoints),
          getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade300, strokeWidth: 0.5),
        ),
        minY: 0,
      ),
    );
  }

  // --- Data Parsing and Helper Methods ---
  List<FlSpot> _createDataPointsFromHistory() {
    // (Implementation remains the same)
    List<FlSpot> dataPoints = []; List<MapEntry<DateTime, double>> datedMaxWeights = [];
    exercise.exHistory.forEach((dateString, weightsHistoryValue) {
      try { /* ... parse date and weights ... */ } catch (e) { /* ... handle error ... */ }
    });
    // ... sort and map ...
    return dataPoints; // Placeholder return
  }
  double _getMaxWeightFromString(String weightsStr) {
    // (Implementation remains the same)
    if (weightsStr.isEmpty) return 0.0; try { return weightsStr.split('/').map((p) => double.tryParse(p.trim()) ?? 0.0).fold(0.0, max); } catch (e) { return 0.0; }
  }
  double? _calculateDateInterval(List<FlSpot> spots) {
    // (Implementation remains the same)
    if (spots.length < 2) return null; final minDateEpoch = spots.first.x; final maxDateEpoch = spots.last.x; final durationMillis = (maxDateEpoch - minDateEpoch).toInt(); if (durationMillis <= 0) return null; final durationDays = Duration(milliseconds: durationMillis).inDays; final double daysPerLabel = durationDays / 5.0; if (daysPerLabel <= 1.5) return const Duration(days: 1).inMilliseconds.toDouble(); if (daysPerLabel <= 4) return const Duration(days: 2).inMilliseconds.toDouble(); if (daysPerLabel <= 10) return const Duration(days: 7).inMilliseconds.toDouble(); if (daysPerLabel <= 20) return const Duration(days: 14).inMilliseconds.toDouble(); if (daysPerLabel <= 45) return const Duration(days: 30).inMilliseconds.toDouble(); return null;
  }
  double? _calculateWeightInterval(List<FlSpot> spots) {
    // (Implementation remains the same)
    if (spots.isEmpty) return null; double maxWeight = spots.map((s) => s.y).fold(0.0, max); if (maxWeight <= 0) return 10; double interval = maxWeight / 5.0; if (interval <= 2.5) return 2.5; if (interval <= 5) return 5.0; if (interval <= 10) return 10.0; if (interval <= 20) return 20.0; if (interval <= 25) return 25.0; if (interval <= 50) return 50.0; return (interval / 50).ceilToDouble() * 50;
  }

} // End StackedAreaLineChart


// =========================================================================
// DonutAutoLabelChart remains the same as the previous corrected version
// =========================================================================
class DonutAutoLabelChart extends StatelessWidget {
  final List<Routine> routines;
  final bool animate;

  const DonutAutoLabelChart(this.routines, {this.animate = false, super.key});

  @override
  Widget build(BuildContext context) {
    final List<PieChartSectionData> sections = _createSectionsData(context);
    if (sections.isEmpty) { return const Center( /* ... No data message ... */ ); }
    return PieChart( PieChartData(/* ... Sections, touch data etc. ... */), );
  }

  List<PieChartSectionData> _createSectionsData(BuildContext context) {
    // (Implementation remains the same)
    final Map<MainTargetedBodyPart, int> countsByBodyPart = {}; int totalCompletions = 0; for (final routine in routines) { if (routine.completionCount > 0) { countsByBodyPart.update( routine.mainTargetedBodyPart, (v) => v + routine.completionCount, ifAbsent: () => routine.completionCount, ); totalCompletions += routine.completionCount; } } if (totalCompletions == 0) return []; final List<Color> colors = [ Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.secondary, Theme.of(context).colorScheme.tertiary ?? Colors.green, Colors.orange.shade600, Colors.red.shade400, Colors.purple.shade400, Colors.teal.shade400, Colors.pink.shade300, Colors.amber.shade600, Colors.indigo.shade400, ]; int colorIndex = 0; final List<PieChartSectionData> sections = []; countsByBodyPart.forEach((bodyPart, count) { final double percentage = (count / totalCompletions) * 100; final Color sectionColor = colors[colorIndex % colors.length]; colorIndex++; sections.add(PieChartSectionData( color: sectionColor, value: count.toDouble(), title: '${percentage.toStringAsFixed(0)}%', radius: 50, titleStyle: const TextStyle( fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white, shadows: [ Shadow(color: Colors.black54, blurRadius: 2) ] ), )); }); return sections;
  }
} // End DonutAutoLabelChart