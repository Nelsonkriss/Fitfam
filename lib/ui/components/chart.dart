import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:workout_planner/models/routine.dart';
import 'package:workout_planner/models/main_targeted_body_part.dart';

class StackedAreaLineChart extends StatelessWidget {
  final bool animate;
  final Exercise exercise;

  const StackedAreaLineChart(this.exercise, {this.animate = false, Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        lineBarsData: [
          LineChartBarData(
            spots: _createData(),
            isCurved: true,
            barWidth: 4,
            color: Colors.deepOrange,
            belowBarData: BarAreaData(show: true, color: Colors.deepOrange.withOpacity(0.3)),
          ),
        ],
        titlesData: FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (FlSpot spot) => Colors.blueGrey,
          ),
        ),
        showingTooltipIndicators: [],
      ),
    );
  }

  List<FlSpot> _createData() {
    List<FlSpot> dataPoints = [];

    for (int i = 0; i < exercise.exHistory.length; i++) {
      double tempWeight = _getMaxWeight(exercise.exHistory.values.toList()[i]);
      dataPoints.add(FlSpot(i.toDouble(), tempWeight));
    }

    return dataPoints;
  }

  double _getMaxWeight(String weightsStr) {
    try {
      if (weightsStr.isEmpty) return 0.0;
      
      final parts = weightsStr.split('/');
      if (parts.isEmpty) return 0.0;
      
      double maxWeight = 0.0;
      for (final part in parts) {
        final weight = double.tryParse(part) ?? 0.0;
        if (weight > maxWeight) {
          maxWeight = weight;
        }
      }
      return maxWeight;
    } catch (e) {
      return 0.0;
    }
  }
}

class DonutAutoLabelChart extends StatelessWidget {
  final List<Routine> routines;
  final bool animate;

  const DonutAutoLabelChart(this.routines, {this.animate = false, Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return PieChart(
      PieChartData(
        sections: _createSections(),
        centerSpaceRadius: 40,
        sectionsSpace: 0,
        pieTouchData: PieTouchData(
          enabled: true,
          touchCallback: (FlTouchEvent event, PieTouchResponse? touchResponse) {},
        ),
      ),
    );
  }

  List<PieChartSectionData> _createSections() {
    return [
      _createSection('Abs', _getTotalCount(MainTargetedBodyPart.Abs), Colors.blue),
      _createSection('Arms', _getTotalCount(MainTargetedBodyPart.Arm), Colors.green),
      _createSection('Back', _getTotalCount(MainTargetedBodyPart.Back), Colors.orange),
      _createSection('Chest', _getTotalCount(MainTargetedBodyPart.Chest), Colors.red),
      _createSection('Legs', _getTotalCount(MainTargetedBodyPart.Leg), Colors.purple),
      _createSection('Shoulders', _getTotalCount(MainTargetedBodyPart.Shoulder), Colors.teal),
      _createSection('Full Body', _getTotalCount(MainTargetedBodyPart.FullBody), Colors.pink),
    ];
  }

  PieChartSectionData _createSection(String title, int value, Color color) {
    return PieChartSectionData(
      color: color,
      value: value.toDouble(),
      title: '$title\n$value',
      radius: 20,
      titleStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  int _getTotalCount(MainTargetedBodyPart mt) {
    return routines.where((r) => r.mainTargetedBodyPart == mt)
        .fold(0, (sum, r) => sum + r.completionCount);
  }
}