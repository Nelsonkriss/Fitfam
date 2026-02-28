import 'dart:async'; // For Future
// For max() if needed by helpers, used in _getRatio calculation

import 'package:flutter/foundation.dart'; // For kDebugMode
import 'package:flutter/material.dart';
import 'design_system.dart';
import 'package:percent_indicator/circular_percent_indicator.dart'; // For weekly progress
import 'package:fl_chart/fl_chart.dart'; // Trend chart
import 'package:intl/intl.dart';
import 'package:provider/provider.dart'; // To access BLoCs

// Import BLoCs and Providers (Adjust paths if needed)
import 'package:workout_planner/bloc/routines_bloc.dart'; // Your RxDart BLoC
import 'package:workout_planner/bloc/workout_session_bloc.dart'; // Now needed for workout session data
import 'package:workout_planner/resource/shared_prefs_provider.dart'; // For getFirstRunDate
// Re-add import statement

// Import Models and UI Components
import 'package:workout_planner/models/workout_session.dart';
import 'package:workout_planner/models/set_performance.dart';
// Import Part model
import 'package:workout_planner/ui/calender_page.dart'; // Your Calendar Page implementation
import 'package:workout_planner/ui/components/chart.dart'; // Assuming DonutAutoLabelChart is here
import 'package:workout_planner/services/exercise_muscle_map.dart';

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
  // Dashboard range selection
  DashboardRange _range = DashboardRange.week;
  bool _useTonnage = false;
  String _weightUnit = 'kg';

  @override
  void initState() {
    super.initState();
    _loadFirstRunDate(); // Load async data once when state initializes
    _loadSelectedWeeklyProgressRoutines(); // Load selected routines for weekly progress
    _loadWeeklyAmount(); // Load weekly workout amount
    _loadSavedRange(); // Load persisted dashboard range
    _loadWeightUnit();
  }

  Future<void> _loadSavedRange() async {
    final saved = await sharedPrefsProvider.getStatsDashboardRange();
    final tonnage = await sharedPrefsProvider.getStatsUseTonnage();
    if (!mounted) return;
    setState(() {
      if (saved != null) {
        _range = saved == 1 ? DashboardRange.days30 : DashboardRange.week;
      }
      _useTonnage = tonnage;
    });
  }

  Future<void> _loadWeightUnit() async {
    final unit = await sharedPrefsProvider.getWeightUnit();
    if (!mounted) return;
    setState(() {
      _weightUnit = unit;
    });
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
      backgroundColor: AppColors.background,
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
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.onSurface,
              surfaceTintColor: AppColors.surface,
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
                            // --- Build Modern Dashboard Layout ---
            return CustomScrollView(
              slivers: <Widget>[
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(context, routines, sessions),
                      const SizedBox(height: 16),
                      _buildHighlights(context, routines, sessions),
                      const SizedBox(height: 16),
                      _buildWeeklyReview(context, sessions),
                      const SizedBox(height: 16),
                      _buildPersonalRecords(context, sessions),
                      const SizedBox(height: 16),
                      _buildVolumeTrend(context, sessions),
                      const SizedBox(height: 16),
                      _buildTrend(context, sessions),
                      const SizedBox(height: 16),
                      _buildBodyPartSplit(context, routines, sessions),
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Workout Calendar',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const CalenderPage(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            );
              },
            );
          },
        ),
      ),
    );
  }

  // Old grid removed in favor of modern dashboard

  // Old helper removed; new UI uses _sectionCard/_kpiCard

  // --- Modern dashboard helpers ---
  Widget _buildHeader(BuildContext context, List<Routine> routines, List<WorkoutSession> sessions) {
    final weeklyTarget = _selectedWeeklyAmount ?? 0;
    final completedThisWeek = _countWorkoutsThisWeek(routines);
    final ratio = _calculateWeeklyRatio(routines);
    final since = _firstRunDate == 'loading...' ? '' : 'Since $_firstRunDate';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [
              Color(0x2921E9B6),
              Color(0x337C5CFF),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your Progress', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(since, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70)),
                  const SizedBox(height: 12),
                  Row(children: [
                    _chip(
                      context,
                      'This Week',
                      selected: _range == DashboardRange.week,
                      onTap: () {
                        setState(() => _range = DashboardRange.week);
                        sharedPrefsProvider.setStatsDashboardRange(0);
                      },
                    ),
                    const SizedBox(width: 8),
                    _chip(
                      context,
                      '30 Days',
                      selected: _range == DashboardRange.days30,
                      onTap: () {
                        setState(() => _range = DashboardRange.days30);
                        sharedPrefsProvider.setStatsDashboardRange(1);
                      },
                    ),
                  ])
                ],
              ),
            ),
            SizedBox(
              width: 110,
              height: 110,
              child: CircularPercentIndicator(
                radius: 50,
                lineWidth: 10,
                percent: ratio,
                animation: true,
                circularStrokeCap: CircularStrokeCap.round,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                progressColor: Theme.of(context).colorScheme.primary,
                center: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${(ratio * 100).toStringAsFixed(0)}%', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    Text('$completedThisWeek/${weeklyTarget > 0 ? weeklyTarget : '—'}', style: Theme.of(context).textTheme.labelMedium),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildHighlights(BuildContext context, List<Routine> routines, List<WorkoutSession> sessions) {
    final totalWorkouts = _getTotalWorkoutCount(routines);
    final totalMinutes = _sumCompletedMinutes(sessions);
    final completedSessions = sessions.where((s) => s.isCompleted && s.endTime != null).length;
    final avgDuration = completedSessions > 0 ? (totalMinutes / completedSessions).round() : 0;
    final streak = _calculateCurrentStreakDays(sessions);

    return SizedBox(
      height: 140,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _kpiCard(
            context,
            icon: Icons.sports_gymnastics_rounded,
            label: 'Total Workouts',
            gradient: _kpiGradient(context, 0),
            valueWidget: CountUp(value: totalWorkouts, suffix: ''),
          ),
          _kpiCard(
            context,
            icon: Icons.timer_rounded,
            label: 'Minutes Trained',
            gradient: _kpiGradient(context, 1),
            valueWidget: CountUp(value: totalMinutes, suffix: ''),
          ),
          _kpiCard(
            context,
            icon: Icons.speed_rounded,
            label: 'Avg Duration',
            gradient: _kpiGradient(context, 2),
            valueWidget: CountUp(value: avgDuration, suffix: 'm'),
          ),
          _kpiCard(
            context,
            icon: Icons.local_fire_department_rounded,
            label: 'Streak',
            gradient: _kpiGradient(context, 3),
            valueWidget: CountUp(value: streak, suffix: 'd'),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyReview(BuildContext context, List<WorkoutSession> sessions) {
    final now = DateTime.now();
    final startThisWeek = _startOfWeek(now);
    final startLastWeek = startThisWeek.subtract(const Duration(days: 7));
    final endLastWeek = startThisWeek.subtract(const Duration(days: 1));

    final thisWeekSessions = _completedSessionsInRange(sessions, startThisWeek, now);
    final lastWeekSessions = _completedSessionsInRange(sessions, startLastWeek, endLastWeek);

    final thisWeekWorkouts = thisWeekSessions.length;
    final lastWeekWorkouts = lastWeekSessions.length;
    final thisWeekMinutes = _sumCompletedMinutes(thisWeekSessions);
    final lastWeekMinutes = _sumCompletedMinutes(lastWeekSessions);
    final thisWeekVolume = _sumVolume(thisWeekSessions);
    final lastWeekVolume = _sumVolume(lastWeekSessions);

    final recentPrs = _findPersonalRecords(sessions, since: startLastWeek);
    final thisWeekPrs = recentPrs.where((pr) => !_isBeforeDay(pr.date, startThisWeek)).length;
    final lastWeekPrs = recentPrs.where((pr) => _isBeforeDay(pr.date, startThisWeek)).length;

    final rangeLabel = '${DateFormat.MMMd().format(startThisWeek)} - ${DateFormat.MMMd().format(now)}';
    final volumeUnit = _useTonnage ? _weightUnit : 'reps';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _sectionCard(
        context,
        title: 'Weekly Review',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This week · $rangeLabel',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _reviewTile(
                    context,
                    icon: Icons.event_available,
                    label: 'Workouts',
                    value: thisWeekWorkouts.toString(),
                    delta: _formatDeltaLabel(thisWeekWorkouts - lastWeekWorkouts),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _reviewTile(
                    context,
                    icon: Icons.timer,
                    label: 'Minutes',
                    value: '${thisWeekMinutes}m',
                    delta: _formatDeltaLabel(thisWeekMinutes - lastWeekMinutes, suffix: 'm'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _reviewTile(
                    context,
                    icon: Icons.auto_graph,
                    label: 'Volume ($volumeUnit)',
                    value: _formatCompact(thisWeekVolume),
                    delta: _formatDeltaLabel(thisWeekVolume - lastWeekVolume),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _reviewTile(
                    context,
                    icon: Icons.emoji_events,
                    label: 'PRs',
                    value: thisWeekPrs.toString(),
                    delta: _formatDeltaLabel(thisWeekPrs - lastWeekPrs),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalRecords(BuildContext context, List<WorkoutSession> sessions) {
    final rangeStart = _range == DashboardRange.week
        ? _startOfWeek(DateTime.now())
        : DateUtils.dateOnly(DateTime.now().subtract(const Duration(days: 29)));
    final recentPrs = _findPersonalRecords(sessions, since: rangeStart)
      ..sort((a, b) => b.date.compareTo(a.date));
    final items = recentPrs.take(5).toList();
    final rangeLabel = _range == DashboardRange.week ? 'This week' : 'Last 30 days';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _sectionCard(
        context,
        title: 'Personal Records',
        child: items.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('No PRs yet for $rangeLabel.', style: Theme.of(context).textTheme.bodyMedium),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rangeLabel,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(items.length, (index) {
                    final item = items[index];
                    return Padding(
                      padding: EdgeInsets.only(bottom: index == items.length - 1 ? 0 : 12),
                      child: _recordRow(context, item),
                    );
                  }),
                ],
              ),
      ),
    );
  }

  Widget _buildVolumeTrend(BuildContext context, List<WorkoutSession> sessions) {
    final rangeDays = _range == DashboardRange.week ? 7 : 30;
    final data = _buildDailyVolumeSeries(sessions, days: rangeDays);
    final hasVolume = data.any((entry) => entry.value > 0);
    if (data.isEmpty || !hasVolume) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _sectionCard(
          context,
          title: 'Volume Trend',
          child: const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Complete some workouts to see your volume trend.'),
          ),
        ),
      );
    }

    final spots = <FlSpot>[];
    for (int i = 0; i < data.length; i++) {
      spots.add(FlSpot(i.toDouble(), data[i].value));
    }
    final maxValue = data.map((e) => e.value).fold<double>(0, (a, b) => b > a ? b : a);
    final interval = (maxValue / 3).clamp(1, double.infinity).toDouble();
    final yFormat = NumberFormat.compact();
    final volumeUnit = _useTonnage ? _weightUnit : 'reps';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _sectionCard(
        context,
        title: 'Volume Trend ($volumeUnit)',
        child: SizedBox(
          height: 180,
          child: LineChart(
            LineChartData(
              minY: 0,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (v) => FlLine(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
                  strokeWidth: .5,
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    interval: interval,
                    getTitlesWidget: (v, m) => Text(
                      yFormat.format(v),
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 10),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    interval: (data.length / 5).clamp(1, 7).toDouble(),
                    getTitlesWidget: (v, m) {
                      final idx = v.toInt();
                      if (idx < 0 || idx >= data.length) return const SizedBox.shrink();
                      return Text(
                        DateFormat.Md().format(data[idx].key),
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 10),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: Theme.of(context).colorScheme.secondary,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.secondary.withValues(alpha: 0.35),
                        Colors.transparent,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrend(BuildContext context, List<WorkoutSession> sessions) {
    final rangeDays = _range == DashboardRange.week ? 7 : 30;
    final data = _buildDailyCountSeries(sessions, days: rangeDays);
    if (data.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _sectionCard(
          context,
          title: 'Activity Trend',
          child: const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Complete some workouts to see your trend.'),
          ),
        ),
      );
    }

    final spots = <FlSpot>[];
    for (int i = 0; i < data.length; i++) {
      spots.add(FlSpot(i.toDouble(), data[i].value.toDouble()));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _sectionCard(
        context,
        title: 'Activity Trend',
        child: SizedBox(
          height: 180,
          child: LineChart(
            LineChartData(
              minY: 0,
              gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: Theme.of(context).dividerColor.withValues(alpha: 0.5), strokeWidth: .5)),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, interval: 1, getTitlesWidget: (v, m) => Text(v.toInt().toString(), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 10)))),
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22, interval: (data.length / 5).clamp(1, 7).toDouble(), getTitlesWidget: (v, m) {
                  final idx = v.toInt();
                  if (idx < 0 || idx >= data.length) return const SizedBox.shrink();
                  return Text(DateFormat.Md().format(data[idx].key), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 10));
                })),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: Theme.of(context).colorScheme.primary,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(show: false),
                  belowBarData: BarAreaData(show: true, gradient: LinearGradient(colors: [
                    Theme.of(context).colorScheme.primary.withValues(alpha: 0.35),
                    Colors.transparent,
                  ], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBodyPartSplit(BuildContext context, List<Routine> routines, List<WorkoutSession> sessions) {
    final now = DateUtils.dateOnly(DateTime.now());
    final fromDate = _range == DashboardRange.week ? now.subtract(Duration(days: now.weekday - 1)) : now.subtract(const Duration(days: 29));
    final parts = _extractTrainedBodyParts(sessions, routines, fromDate: fromDate);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _sectionCard(
        context,
        title: 'Body Part Split',
        child: SizedBox(
          height: 180,
          child: DonutAutoLabelChart(parts, animate: true),
        ),
      ),
    );
  }

  Widget _sectionCard(BuildContext context, {String? title, required Widget child}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
            ],
            child,
          ],
        ),
      ),
    );
  }

  Widget _reviewTile(BuildContext context, {required IconData icon, required String label, required String value, required String delta}) {
    final cs = Theme.of(context).colorScheme;
    final deltaColor = delta.startsWith('+')
        ? AppColors.success
        : delta.startsWith('-')
            ? AppColors.danger
            : cs.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: cs.primary),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 6),
          Text(delta, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: deltaColor, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _recordRow(BuildContext context, _PersonalRecord record) {
    final cs = Theme.of(context).colorScheme;
    final icon = _recordIcon(record.workoutType);
    final dateLabel = DateFormat.MMMd().format(record.date);
    final valueLabel = _formatRecordValue(record);

    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: cs.primaryContainer.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: cs.onPrimaryContainer),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                record.exerciseName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                dateLabel,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
        Text(
          valueLabel,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _kpiCard(BuildContext context, {required IconData icon, required String label, required Gradient gradient, Widget? valueWidget, String? value}) {
    return Container(
      width: 180,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: gradient,
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.9)),
          const Spacer(),
          valueWidget ?? Text(value ?? '', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Gradient _kpiGradient(BuildContext context, int index) {
    final cs = Theme.of(context).colorScheme;
    final list = [
      LinearGradient(colors: [cs.primaryContainer.withValues(alpha: 0.65), cs.secondaryContainer.withValues(alpha: 0.55)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      LinearGradient(colors: [cs.tertiaryContainer.withValues(alpha: 0.65), cs.primary.withValues(alpha: 0.40)], begin: Alignment.topRight, end: Alignment.bottomLeft),
      LinearGradient(colors: [cs.secondary.withValues(alpha: 0.45), cs.surfaceTint.withValues(alpha: 0.35)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      LinearGradient(colors: [cs.errorContainer.withValues(alpha: 0.50), cs.tertiary.withValues(alpha: 0.40)], begin: Alignment.topRight, end: Alignment.bottomLeft),
    ];
    return list[index % list.length];
  }

  Widget _chip(BuildContext context, String text, {bool selected = false, VoidCallback? onTap}) {
    final cs = Theme.of(context).colorScheme;
    final bg = selected ? cs.primaryContainer : cs.surfaceContainerHighest;
    final brd = selected ? cs.primary : Theme.of(context).dividerColor.withValues(alpha: 0.3);
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: selected ? cs.onPrimaryContainer : null,
      fontWeight: selected ? FontWeight.w600 : null,
    );
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: brd),
        ),
        child: Text(text, style: style),
      ),
    );
  }

  DateTime _dateOnly(DateTime date) => DateUtils.dateOnly(date.toLocal());

  DateTime _startOfWeek(DateTime date) {
    final day = _dateOnly(date);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  bool _isBeforeDay(DateTime date, DateTime boundary) {
    return _dateOnly(date).isBefore(_dateOnly(boundary));
  }

  List<WorkoutSession> _completedSessionsInRange(List<WorkoutSession> sessions, DateTime start, DateTime end) {
    final startDay = _dateOnly(start);
    final endDay = _dateOnly(end);
    return sessions.where((s) {
      if (!s.isCompleted || s.endTime == null) return false;
      final day = _dateOnly(s.endTime!);
      return !day.isBefore(startDay) && !day.isAfter(endDay);
    }).toList();
  }

  double _sumVolume(List<WorkoutSession> sessions) {
    double total = 0;
    for (final session in sessions) {
      if (!session.isCompleted || session.endTime == null) continue;
      total += _sessionVolume(session);
    }
    return total;
  }

  double _sessionVolume(WorkoutSession session) {
    double total = 0;
    for (final exercise in session.exercises) {
      for (final set in exercise.sets) {
        total += _setVolume(set, exercise.workoutType);
      }
    }
    return total;
  }

  double _setVolume(SetPerformance set, WorkoutType type) {
    final isCompleted = set.isCompleted || set.actualReps > 0 || set.actualWeight > 0;
    if (!isCompleted) return 0;
    final reps = set.actualReps > 0 ? set.actualReps : set.targetReps;
    if (reps <= 0) return 0;
    if (type == WorkoutType.Weight && _useTonnage) {
      final weight = set.actualWeight > 0 ? set.actualWeight : set.targetWeight;
      if (weight <= 0) return 0;
      return reps * weight;
    }
    return reps.toDouble();
  }

  List<MapEntry<DateTime, double>> _buildDailyVolumeSeries(List<WorkoutSession> sessions, {int days = 30}) {
    final now = _dateOnly(DateTime.now());
    final start = now.subtract(Duration(days: days - 1));
    final volume = <DateTime, double>{};
    for (int i = 0; i < days; i++) {
      volume[start.add(Duration(days: i))] = 0;
    }
    for (final s in sessions) {
      if (!s.isCompleted || s.endTime == null) continue;
      final d = _dateOnly(s.endTime!);
      if (d.isBefore(start) || d.isAfter(now)) continue;
      volume[d] = (volume[d] ?? 0) + _sessionVolume(s);
    }
    final list = volume.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return list;
  }

  List<_PersonalRecord> _findPersonalRecords(List<WorkoutSession> sessions, {DateTime? since}) {
    final completed = sessions.where((s) => s.isCompleted && s.endTime != null).toList()
      ..sort((a, b) => a.endTime!.compareTo(b.endTime!));
    final bestByExercise = <String, _PersonalRecord>{};
    final records = <_PersonalRecord>[];

    for (final session in completed) {
      final date = session.endTime!.toLocal();
      for (final exercise in session.exercises) {
        for (final set in exercise.sets) {
          final record = _recordFromSet(exercise.exerciseName, exercise.workoutType, set, date);
          if (record == null) continue;
          final key = '${exercise.exerciseName.toLowerCase()}|${exercise.workoutType.name}';
          final existing = bestByExercise[key];
          if (existing == null || record.value > existing.value) {
            bestByExercise[key] = record;
            if (since == null || !_isBeforeDay(date, since)) {
              records.add(record);
            }
          }
        }
      }
    }
    return records;
  }

  _PersonalRecord? _recordFromSet(String exerciseName, WorkoutType type, SetPerformance set, DateTime date) {
    final isCompleted = set.isCompleted || set.actualReps > 0 || set.actualWeight > 0;
    if (!isCompleted) return null;
    final reps = set.actualReps > 0 ? set.actualReps : set.targetReps;
    if (reps <= 0) return null;

    if (type == WorkoutType.Weight) {
      final weight = set.actualWeight > 0 ? set.actualWeight : set.targetWeight;
      if (weight <= 0) return null;
      return _PersonalRecord(
        exerciseName: exerciseName,
        workoutType: type,
        value: weight,
        reps: reps,
        date: date,
      );
    }

    return _PersonalRecord(
      exerciseName: exerciseName,
      workoutType: type,
      value: reps.toDouble(),
      reps: reps,
      date: date,
    );
  }

  IconData _recordIcon(WorkoutType type) {
    switch (type) {
      case WorkoutType.Timed:
        return Icons.timer;
      case WorkoutType.Cardio:
        return Icons.directions_run;
      case WorkoutType.Weight:
        return Icons.fitness_center;
    }
  }

  String _formatRecordValue(_PersonalRecord record) {
    switch (record.workoutType) {
      case WorkoutType.Weight:
        final repsLabel = record.reps > 0 ? ' x ${record.reps}' : '';
        return '${_formatWeightValue(record.value)} $_weightUnit$repsLabel';
      case WorkoutType.Timed:
        return '${record.value.toStringAsFixed(0)} sec';
      case WorkoutType.Cardio:
        return '${record.value.toStringAsFixed(0)} reps';
    }
  }

  String _formatWeightValue(double value) {
    return value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
  }

  String _formatCompact(num value, {int fractionDigits = 0}) {
    final absValue = value.abs();
    if (absValue >= 1000) {
      return NumberFormat.compact().format(absValue);
    }
    if (value is double && absValue % 1 != 0) {
      final digits = fractionDigits > 0 ? fractionDigits : 1;
      return absValue.toStringAsFixed(digits);
    }
    return absValue.toStringAsFixed(0);
  }

  String _formatDeltaLabel(num delta, {String suffix = ''}) {
    if (delta == 0) return 'No change';
    final sign = delta > 0 ? '+' : '-';
    final formatted = _formatCompact(delta.abs(), fractionDigits: 1);
    return '$sign$formatted$suffix vs last week';
  }

  int _countWorkoutsThisWeek(List<Routine> routines) {
    if (_selectedWeeklyAmount == null) return 0;
    final selectedIds = _selectedWeeklyProgressRoutineIds;
    final now = DateTime.now();
    final startOfWeek = DateUtils.dateOnly(now.subtract(Duration(days: now.weekday - 1)));
    int count = 0;
    for (final r in routines) {
      if (r.id == null || !selectedIds.contains(r.id!)) continue;
      for (final ts in r.routineHistory) {
        final d = DateUtils.dateOnly(DateTime.fromMillisecondsSinceEpoch(ts));
        if (!d.isBefore(startOfWeek)) count++;
      }
    }
    return count;
  }

  int _sumCompletedMinutes(List<WorkoutSession> sessions) {
    int total = 0;
    for (final s in sessions) {
      if (s.isCompleted && s.endTime != null) {
        total += s.endTime!.difference(s.startTime).inMinutes.clamp(0, 100000);
      }
    }
    return total;
  }

  int _calculateCurrentStreakDays(List<WorkoutSession> sessions) {
    final completedDates = <DateTime>{};
    for (final s in sessions) {
      if (s.isCompleted && s.endTime != null) {
        completedDates.add(DateUtils.dateOnly(s.endTime!.toLocal()));
      }
    }
    if (completedDates.isEmpty) return 0;
    DateTime day = DateUtils.dateOnly(DateTime.now());
    int streak = 0;
    if (!completedDates.contains(day)) {
      day = day.subtract(const Duration(days: 1));
      if (!completedDates.contains(day)) return 0;
    }
    while (completedDates.contains(day)) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  List<MapEntry<DateTime, int>> _buildDailyCountSeries(List<WorkoutSession> sessions, {int days = 30}) {
    final now = DateUtils.dateOnly(DateTime.now());
    final start = now.subtract(Duration(days: days - 1));
    final counts = <DateTime, int>{};
    for (int i = 0; i < days; i++) {
      counts[start.add(Duration(days: i))] = 0;
    }
    for (final s in sessions) {
      if (s.isCompleted && s.endTime != null) {
        final d = DateUtils.dateOnly(s.endTime!.toLocal());
        if (!d.isBefore(start) && !d.isAfter(now)) {
          counts[d] = (counts[d] ?? 0) + 1;
        }
      }
    }
    final list = counts.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return list;
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

  // Font sizing helper removed (not used in new UI)

  /// Calculates the total completion count across all routines.
  int _getTotalWorkoutCount(List<Routine> routines) {
    // completionCount is non-nullable in model
    return routines.fold<int>(0, (sum, routine) => sum + routine.completionCount);
  }

  /// Extracts body parts from completed workout sessions using per-exercise targets.
  /// Uses a weighted approach based on reps volume per exercise.
  List<Part> _extractTrainedBodyParts(List<WorkoutSession> sessions, List<Routine> routines, {DateTime? fromDate}) {
    if (sessions.isEmpty) return [];

    // Weighted volume per body part across sessions
    final Map<TargetedBodyPart, double> volumeByPart = {};

    // Only consider completed sessions within optional range
    final completedSessions = sessions.where((session) {
      if (!session.isCompleted || session.endTime == null) return false;
      if (fromDate == null) return true;
      final d = DateUtils.dateOnly(session.endTime!.toLocal());
      final f = DateUtils.dateOnly(fromDate);
      return !d.isBefore(f);
    });

    for (final session in completedSessions) {
      for (final exPerf in session.exercises) {
        // Estimate volume (reps or tonnage)
        double volume = 0;
        if (exPerf.sets.isNotEmpty) {
          for (final s in exPerf.sets) {
            final reps = (s.actualReps > 0 ? s.actualReps : s.targetReps).toDouble();
            if (_useTonnage && exPerf.workoutType == WorkoutType.Weight) {
              final wt = (s.actualWeight > 0 ? s.actualWeight : s.targetWeight);
              volume += reps * wt;
            } else {
              volume += reps;
            }
          }
        } else {
          volume = _useTonnage ? 10.0 /* unknown */ : 10.0;
        }

        // Prefer explicit exercise targets saved on the routine, fallback to mapper
        Map<TargetedBodyPart, double> targets = _lookupExerciseTargetsFromRoutines(routines, exPerf.exerciseName);
        if (targets.isEmpty) targets = ExerciseMuscleMap.targetsFor(exPerf.exerciseName);
        targets.forEach((bp, w) {
          volumeByPart[bp] = (volumeByPart[bp] ?? 0) + volume * w;
        });
      }
    }

    if (volumeByPart.isEmpty) return [];

    // Convert weighted volumes to token Parts for the existing pie chart component
    final total = volumeByPart.values.fold(0.0, (a, b) => a + b);
    if (total <= 0) return [];
    final List<Part> trainedParts = [];
    volumeByPart.forEach((bp, vol) {
      final tokens = (vol / total * 100).round().clamp(0, 100);
      for (int i = 0; i < tokens; i++) {
        trainedParts.add(Part(targetedBodyPart: bp, setType: SetType.Regular, exercises: const []));
      }
    });
    if (trainedParts.isEmpty) {
      trainedParts.add(Part(targetedBodyPart: TargetedBodyPart.FullBody, setType: SetType.Regular, exercises: const []));
    }
    return trainedParts;
  }

  Map<TargetedBodyPart, double> _lookupExerciseTargetsFromRoutines(List<Routine> routines, String exerciseName) {
    for (final r in routines) {
      for (final p in r.parts) {
        for (final e in p.exercises) {
          if (e.name.toLowerCase() == exerciseName.toLowerCase()) {
            final Map<TargetedBodyPart, double> m = {};
            if (e.primaryTarget != null) m[e.primaryTarget!] = 1.0;
            if (e.secondaryTargets.isNotEmpty) {
              final add = 0.3; // give some credit to secondary targets
              for (final s in e.secondaryTargets) {
                m[s] = (m[s] ?? 0) + add;
              }
            }
            // normalize
            final sum = m.values.fold(0.0, (a,b)=>a+b);
            if (sum > 0) return m.map((k,v)=>MapEntry(k, v/sum));
            return m;
          }
        }
      }
    }
    return {};
  }
} // End of _StatisticsPageState

// Dashboard range options
enum DashboardRange { week, days30 }

// Animated count-up text for KPI values
class CountUp extends StatefulWidget {
  final num value;
  final Duration duration;
  final TextStyle? style;
  final String suffix;
  final int fractionDigits;

  const CountUp({super.key, required this.value, this.duration = const Duration(milliseconds: 700), this.style, this.suffix = '', this.fractionDigits = 0});

  @override
  State<CountUp> createState() => _CountUpState();
}

class _CountUpState extends State<CountUp> {
  late num _old;

  @override
  void initState() {
    super.initState();
    _old = widget.value;
  }

  @override
  void didUpdateWidget(covariant CountUp oldWidget) {
    super.didUpdateWidget(oldWidget);
    _old = oldWidget.value;
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: _old.toDouble(), end: widget.value.toDouble()),
      duration: widget.duration,
      builder: (context, val, child) {
        final formatted = widget.fractionDigits > 0 ? val.toStringAsFixed(widget.fractionDigits) : val.toStringAsFixed(0);
        return Text('$formatted${widget.suffix}', style: widget.style ?? Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800));
      },
    );
  }
}

class _PersonalRecord {
  final String exerciseName;
  final WorkoutType workoutType;
  final double value;
  final int reps;
  final DateTime date;

  const _PersonalRecord({
    required this.exerciseName,
    required this.workoutType,
    required this.value,
    required this.reps,
    required this.date,
  });
}


