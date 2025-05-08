// lib/ui/components/chart.dart

import 'dart:math'; // For max() function used in chart data processing
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart'; // If used, otherwise remove
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:async';

// Import your actual models
import 'package:workout_planner/models/part.dart'; // Changed from routine.dart
// MainTargetedBodyPart is no longer directly used here, TargetedBodyPart from part.dart will be used.
import 'package:workout_planner/models/exercise.dart'; // Ensure this path is correct

class StackedAreaLineChart extends StatelessWidget {
  final Exercise exercise;
  final bool animate;

  const StackedAreaLineChart(this.exercise, {this.animate = false, super.key});

  static List<MapEntry<DateTime, double>> _datedMaxWeightsCache = [];

  @override
  Widget build(BuildContext context) {
    final List<FlSpot> dataPoints = _createDataPointsFromHistory();

    if (dataPoints.length < 2) {
      return const Center( child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Text("Not enough historical data for this exercise to display a trend chart.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
      ));
    }

    return LineChart(
      LineChartData(
        lineBarsData: [
          LineChartBarData(
            spots: dataPoints, isCurved: true, curveSmoothness: 0.35, barWidth: 3,
            color: Colors.deepOrangeAccent, isStrokeCapRound: true,
            dotData: FlDotData(show: dataPoints.length < 30),
            belowBarData: BarAreaData( show: true,
              gradient: LinearGradient( colors: [ Colors.deepOrangeAccent.withOpacity(0.4), Colors.deepOrangeAccent.withOpacity(0.0), ],
                begin: Alignment.topCenter, end: Alignment.bottomCenter, ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          enabled: true, handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            maxContentWidth: 120,
            getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
              return touchedBarSpots.map((barSpot) {
                String dateStr = "Date N/A";
                if (_datedMaxWeightsCache.isNotEmpty) {
                  final firstDate = _datedMaxWeightsCache.first.key;
                  try {
                    final actualDate = firstDate.add(Duration(days: barSpot.x.toInt()));
                    dateStr = DateFormat.yMd().format(actualDate);
                  } catch (e) {
                    debugPrint("Error calculating tooltip date: $e");
                  }
                }
                final double weight = barSpot.y;
                final String weightStr = weight.toStringAsFixed(weight.truncateToDouble() == weight ? 0 : 1);
                return LineTooltipItem( '$weightStr kg \n', TextStyle(color: Theme.of(context).colorScheme.onInverseSurface ?? Colors.white, fontWeight: FontWeight.bold),
                  children: [ TextSpan( text: dateStr, style: TextStyle(color: (Theme.of(context).colorScheme.onInverseSurface ?? Colors.white).withOpacity(0.8), fontSize: 12), ), ],
                  textAlign: TextAlign.center, );
              }).toList();
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: dataPoints.length > 1,
              reservedSize: 30,
              interval: _calculateDateInterval(dataPoints),
              getTitlesWidget: (double value, TitleMeta meta) {
                if (_datedMaxWeightsCache.isNotEmpty) {
                  final firstDate = _datedMaxWeightsCache.first.key;
                  bool isMin = (value - meta.min).abs() < 1e-9;
                  bool isMax = (value - meta.max).abs() < 1e-9;
                  bool isIntervalMultiple = meta.appliedInterval != null && meta.appliedInterval! > 0
                      ? ((value - meta.min) % meta.appliedInterval!).abs() < 1e-9
                      : false;
                  if (isMin || isMax || isIntervalMultiple) {
                    final DateTime date = firstDate.add(Duration(days: value.toInt()));
                    // *** REVERTING TO axisSide HERE ***
                    return SideTitleWidget(
                      axisSide: meta.axisSide,
                      space: 6.0,
                      child: Text(
                        DateFormat('MMM d').format(date),
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                      ),
                    );
                  }
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (double value, TitleMeta meta) {
                if ((value == meta.min && value >= 0) || value == meta.max || (value == 0 && meta.max ==0)) {
                  // *** REVERTING TO axisSide HERE ***
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    space: 4.0,
                    child: Text(
                      '${value.toStringAsFixed(0)}kg',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
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

  List<FlSpot> _createDataPointsFromHistory() {
    final List<FlSpot> dataPoints = [];
    final List<MapEntry<DateTime, double>> datedMaxWeights = [];
    if (exercise.exHistory == null) {
      _datedMaxWeightsCache = [];
      return dataPoints;
    }

    exercise.exHistory.forEach((dateString, historyEntryList) {
      try {
        final date = DateTime.parse(dateString);
        if (historyEntryList.isNotEmpty) {
          double maxWeightInDay = 0.0;
          for (final entry in historyEntryList) {
            if (entry != null && entry.weight != null) {
              if (entry.weight! > maxWeightInDay) {
                maxWeightInDay = entry.weight!;
              }
            }
          }
          if (maxWeightInDay > 0) {
            datedMaxWeights.add(MapEntry(date, maxWeightInDay));
          }
        }
      } catch (e) {
        debugPrint('Error parsing history for ${exercise.name} on $dateString: $e. EntryList type: ${historyEntryList.runtimeType}');
      }
    });

    datedMaxWeights.sort((a, b) => a.key.compareTo(b.key));
    _datedMaxWeightsCache = List.from(datedMaxWeights);

    if (datedMaxWeights.isNotEmpty) {
      final firstDate = datedMaxWeights.first.key;
      dataPoints.addAll(datedMaxWeights.map((entry) {
        final xValue = entry.key.difference(firstDate).inDays.toDouble();
        return FlSpot(xValue, entry.value);
      }));
    }
    return dataPoints;
  }

  double? _calculateDateInterval(List<FlSpot> spots) {
    if (spots.length < 2) return 1;
    final double minX = spots.first.x;
    final double maxX = spots.last.x;
    final double durationDays = maxX - minX;

    if (durationDays <= 0) return 1;
    if (durationDays <= 7) return 1;
    if (durationDays <= 30) return 7;
    if (durationDays <= 90) return 14;
    if (durationDays <= 180) return 30;
    double calculatedInterval = (durationDays / 6.0).roundToDouble();
    return calculatedInterval > 0 ? calculatedInterval : 1;
  }

  double? _calculateWeightInterval(List<FlSpot> spots) {
    if (spots.isEmpty) return 10;
    double maxWeight = spots.map((s) => s.y).fold(0.0, (prev, current) => max(prev, current));
    if (maxWeight <= 0) return 10;
    double interval = maxWeight / 5.0;
    if (interval == 0) return 10;

    const List<double> steps = [2.5, 5, 10, 20, 25, 50];
    for (final step in steps) {
      if (interval <= step) return step;
    }
    return (interval / steps.last).ceil() * steps.last;
  }
}

// =========================================================================
// DonutAutoLabelChart - (No changes from previous version)
// =========================================================================
class DonutAutoLabelChart extends StatelessWidget { // Changed to StatelessWidget
  final List<Part> parts; // Changed from List<Routine> routines
  final bool animate;

  const DonutAutoLabelChart(this.parts, {this.animate = false, super.key}); // Updated constructor

  @override
  Widget build(BuildContext context) {
    final List<PieChartSectionData> sections = _createSectionsData(context, parts); // Pass parts directly
    if (sections.isEmpty) {
      return const Center( child: Text("No routine completion data to display.", style: TextStyle(color: Colors.grey)) );
    }
    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 60,
        sections: sections,
        pieTouchData: PieTouchData(
          touchCallback: (FlTouchEvent event, pieTouchResponse) {
            // Handle touch events if needed
          },
        ),
        startDegreeOffset: 180,
      ),
      swapAnimationDuration: Duration(milliseconds: animate ? 350 : 0), // Use animate directly
      swapAnimationCurve: Curves.easeInOutQuint,
    );
  }

List<PieChartSectionData> _createSectionsData(BuildContext context, List<Part> parts) { // Changed signature
    final Map<TargetedBodyPart, int> countsByBodyPart = {}; // Changed to TargetedBodyPart
    int totalPartsCount = 0;

    // Iterate over parts instead of routines
    for (final part in parts) {
      // Assuming each part instance counts as one towards its targeted body part.
      // If parts have a specific "count" or "completion" metric, use that here.
      // For now, we count each part as 1.
      final TargetedBodyPart bodyPart = part.targetedBodyPart;

      countsByBodyPart.update(
        bodyPart,
        (v) => v + 1, // Increment count for this body part
        ifAbsent: () => 1,
      );
      totalPartsCount += 1; // Increment total parts processed
    }

    if (totalPartsCount == 0) return [];

    final List<Color> colors = [
      Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.secondary,
      Theme.of(context).colorScheme.tertiary, Theme.of(context).colorScheme.primaryContainer,
      Theme.of(context).colorScheme.secondaryContainer, Theme.of(context).colorScheme.tertiaryContainer,
      Colors.orange.shade600, Colors.red.shade500, Colors.purple.shade500, Colors.teal.shade400,
      Colors.pink.shade300, Colors.amber.shade600, Colors.indigo.shade400,
      Colors.lightGreen.shade500, Colors.blueGrey.shade400,
    ];
    int colorIndex = 0;
    final List<PieChartSectionData> sections = [];

    var sortedEntries = countsByBodyPart.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (var entry in sortedEntries) {
      final bodyPart = entry.key;
      final count = entry.value;
      final double percentage = (count / totalPartsCount) * 100; // Use totalPartsCount
      final Color sectionColor = colors[colorIndex % colors.length];
      colorIndex++;

      sections.add(PieChartSectionData(
        color: sectionColor,
        value: count.toDouble(),
        title: bodyPart.name,
        radius: 60,
        titleStyle: TextStyle(
            fontSize: 12, fontWeight: FontWeight.bold,
            color: ThemeData.estimateBrightnessForColor(sectionColor) == Brightness.dark ? Colors.white : Colors.black,
            shadows: const [Shadow(color: Colors.black26, blurRadius: 2.0)]
        ),
      ));
    }
    return sections;
  }
}