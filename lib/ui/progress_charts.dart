import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:workout_planner/models/workout_session.dart';
import 'package:workout_planner/bloc/workout_session_bloc.dart';
import 'package:intl/intl.dart';

class ProgressCharts extends StatefulWidget {
  const ProgressCharts({Key? key}) : super(key: key);

  @override
  _ProgressChartsState createState() => _ProgressChartsState();
}

class _ProgressChartsState extends State<ProgressCharts> {
  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      print("Initializing ProgressCharts");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      print("Building ProgressCharts");
    }
    
    return Scaffold(
      appBar: AppBar(title: const Text('Progress Charts')),
      body: StreamBuilder<List<WorkoutSession>>(
        stream: workoutSessionBloc.allSessions,
        builder: (context, snapshot) {
          if (kDebugMode) {
            print("StreamBuilder state: ${snapshot.connectionState}");
            if (snapshot.hasData) {
              print("Received ${snapshot.data!.length} sessions");
            } else if (snapshot.hasError) {
              print("Error in stream: ${snapshot.error}");
            }
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No workout data available'));
          }

          final sessions = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildVolumeChart(sessions),
              const SizedBox(height: 32),
              _buildExerciseProgressChart(sessions),
            ],
          );
        },
      ),
    );
  }

  Widget _buildVolumeChart(List<WorkoutSession> sessions) {
    final volumeData = <FlSpot>[];
    final volumeByDate = <DateTime, double>{};

    for (final session in sessions) {
      if (!session.isCompleted || session.endTime == null) continue;
      
      double sessionVolume = 0;
      for (final exercise in session.exercises) {
        for (final set in exercise.sets) {
          sessionVolume += set.actualWeight * set.actualReps;
        }
      }

      final date = DateTime(
        session.endTime!.year,
        session.endTime!.month,
        session.endTime!.day
      );
      volumeByDate.update(
        date,
        (value) => value + sessionVolume,
        ifAbsent: () => sessionVolume
      );
    }

    volumeData.addAll(volumeByDate.entries
        .map((e) => FlSpot(
              e.key.millisecondsSinceEpoch.toDouble(),
              e.value,
            ))
        .toList());

    volumeData.sort((a, b) => a.x.compareTo(b.x));

    return SizedBox(
      height: 300,
      child: LineChart(
        LineChartData(
          lineBarsData: [
            LineChartBarData(
              spots: volumeData,
              isCurved: true,
              dotData: FlDotData(show: true),
              belowBarData: BarAreaData(show: true),
              color: Colors.blue,
            ),
          ],
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                  return Text(DateFormat('MMM dd').format(date));
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Text(value.toInt().toString());
                },
              ),
            ),
          ),
          gridData: FlGridData(show: true),
          borderData: FlBorderData(show: true),
        ),
      ),
    );
  }

  Widget _buildExerciseProgressChart(List<WorkoutSession> sessions) {
    final exerciseNames = <String>{};
    for (final session in sessions) {
      for (final exercise in session.exercises) {
        exerciseNames.add(exercise.exerciseName);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Exercise Progress',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ...exerciseNames.map((exercise) => 
          _buildSingleExerciseChart(sessions, exercise)
        ),
      ],
    );
  }

  Widget _buildSingleExerciseChart(List<WorkoutSession> sessions, String exerciseName) {
    final dataPoints = <FlSpot>[];

    for (final session in sessions) {
      if (!session.isCompleted || session.endTime == null) continue;

      for (final exercise in session.exercises) {
        if (exercise.exerciseName != exerciseName) continue;

        for (final set in exercise.sets) {
          if (set.actualReps > 0 && set.actualWeight > 0) {
            dataPoints.add(FlSpot(
              session.endTime!.millisecondsSinceEpoch.toDouble(),
              set.actualWeight,
            ));
          }
        }
      }
    }

    if (dataPoints.isEmpty) return Container();

    dataPoints.sort((a, b) => a.x.compareTo(b.x));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(exerciseName, style: const TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              lineBarsData: [
                LineChartBarData(
                  spots: dataPoints,
                  isCurved: true,
                  dotData: FlDotData(show: true),
                  color: Colors.green,
                ),
              ],
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                      return Text(DateFormat('MMM dd').format(date));
                    },
                  ),
                ),
              ),
              gridData: FlGridData(show: true),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}