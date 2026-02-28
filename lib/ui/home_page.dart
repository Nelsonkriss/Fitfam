import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:confetti/confetti.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:workout_planner/bloc/routines_bloc.dart';
import 'package:workout_planner/bloc/workout_session_bloc.dart';
import 'package:workout_planner/models/workout_session.dart';
import 'package:workout_planner/models/main_targeted_body_part.dart';
import 'package:workout_planner/models/user_profile.dart';
import 'package:workout_planner/resource/shared_prefs_provider.dart';
import 'package:workout_planner/ui/calender_page.dart';
import 'package:workout_planner/ui/recommend_page.dart';
import 'package:workout_planner/ui/routine_edit_page.dart';
import 'package:workout_planner/utils/routine_helpers.dart';
import 'package:workout_planner/ui/components/routine_card.dart';
// Removed direct use of WorkoutSessionPage
import 'package:workout_planner/ui/routine_step_page_v2.dart';
import 'package:workout_planner/ui/routine_detail_page.dart';
import 'package:workout_planner/ui/statistics_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ScrollController _scrollController = ScrollController();
  bool _showAppBarShadow = false;
  late final ConfettiController _confettiController;
  UserProfile? _userProfile;

  // Hook-copy pool (short, action-oriented lines)
  static const List<String> _hookCopy = [
    "Your future self is watching. Make them proud.",
    "One set now beats ten someday.",
    "Tiny wins, compounding power.",
    "90 seconds from momentum.",
    "Do you even lift?",
    "All weight is Lightweight.",
  ];
  String _pickHook() {
    // Avoid mutating the const list; pick a random element instead
    final i = math.Random().nextInt(_hookCopy.length);
    return _hookCopy[i];
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RoutinesBloc>().fetchAllRoutines();
    });

    _scrollController.addListener(_scrollListener);
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 2),
    );
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final profile = await sharedPrefsProvider.getUserProfile();
    if (!mounted) return;
    setState(() {
      _userProfile = profile;
    });
  }

  String _displayName() {
    final name = _userProfile?.displayName?.trim();
    if (name == null || name.isEmpty) return 'Athlete';
    return name;
  }

  String? _focusSummary() {
    final goals = _userProfile?.fitnessGoals ?? const <FitnessGoal>[];
    if (goals.isEmpty) return null;
    return goals.map((g) => g.displayName).take(2).join(' + ');
  }

  void _scrollListener() {
    if (!mounted) return;
    final shouldShowShadow = _scrollController.offset > 0;
    if (shouldShowShadow != _showAppBarShadow) {
      setState(() {
        _showAppBarShadow = shouldShowShadow;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final routinesBloc = context.watch<RoutinesBloc>();
    final theme = Theme.of(context);
    return Scaffold(
      body: Stack(
        children: [
          NestedScrollView(
            controller: _scrollController,
            headerSliverBuilder:
                (context, innerBoxIsScrolled) => [
                  SliverAppBar(
                    title: const Text('Workout Planner'),
                    pinned: true,
                    floating: true,
                    forceElevated: _showAppBarShadow,
                  ),
                ],
            body: StreamBuilder<List<Routine>>(
              stream: routinesBloc.allRoutinesStream,
              builder: (context, routinesSnapshot) {
                final routines = routinesSnapshot.data ?? const <Routine>[];
                return ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _buildHookHero(context, routines),
                    _buildStreakAndCTA(context, routines),
                    _buildContinueCard(context, routines),
                    _buildActionHub(context, routines),
                    _buildWeeklyActivity(context),
                    _buildCategories(context, routines),
                    _buildAiCard(context),
                    if (routinesSnapshot.connectionState ==
                            ConnectionState.waiting &&
                        !routinesSnapshot.hasData)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (routinesSnapshot.hasError)
                      Center(child: Text('Error: ${routinesSnapshot.error}'))
                    else if (routines.isEmpty)
                      _buildEmptyState(context)
                    else
                      _buildRoutinesGridSection(context, routines),
                    const SizedBox(height: 96),
                  ],
                );
              },
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: IgnorePointer(
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                emissionFrequency: 0.05,
                numberOfParticles: 20,
                maxBlastForce: 12,
                minBlastForce: 6,
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.secondary,
                  Colors.amber,
                  Colors.white,
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => _showAddRoutineSheet(context),
      ),
    );
  }

  // --- Hero Hook (contrast headline + micro-CTAs) ---
  Widget _buildHookHero(BuildContext context, List<Routine> routines) {
    final cs = Theme.of(context).colorScheme;
    final focus = _focusSummary();
    final hook = _pickHook();
    final subtitle =
        routines.isEmpty
            ? 'Create your first routine and start tracking progress.'
            : hook;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
          gradient: LinearGradient(
            colors: [
              cs.primary.withValues(alpha: 0.16),
              cs.secondary.withValues(alpha: 0.10),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome, ${_displayName()}',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.86),
                fontWeight: FontWeight.w600,
              ),
            ),
            if (focus != null) ...[
              const SizedBox(height: 10),
              Text(
                'Focus: $focus',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _QuickChip(
                  icon: Icons.play_arrow_rounded,
                  label: 'Quick Start',
                  onTap: () => _onPrimeTap(context, routines),
                ),
                _QuickChip(
                  icon: Icons.add_task_rounded,
                  label: 'Build Routine',
                  onTap: () => _showAddRoutineSheet(context),
                ),
                _QuickChip(
                  icon: Icons.auto_awesome,
                  label: 'AI Coach',
                  onTap: () => _goAI(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _goAI(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RecommendPage()),
    );
  }

  // --- Streak + Big CTA (attention flow to action) ---
  Widget _buildStreakAndCTA(BuildContext context, List<Routine> routines) {
    final cs = Theme.of(context).colorScheme;
    final wsBloc = context.read<WorkoutSessionBloc>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          // Streak ring fed by sessions in last 7 days
          StreamBuilder<List<WorkoutSession>>(
            stream: wsBloc.allSessionsStream,
            builder: (context, snap) {
              final sessions = snap.data ?? const <WorkoutSession>[];
              final now = DateTime.now();
              final weekAgo = now.subtract(const Duration(days: 6));
              final daysWithWorkouts =
                  sessions
                      .where(
                        (s) => s.startTime.isAfter(
                          DateTime(weekAgo.year, weekAgo.month, weekAgo.day),
                        ),
                      )
                      .map(
                        (s) => DateTime(
                          s.startTime.year,
                          s.startTime.month,
                          s.startTime.day,
                        ),
                      )
                      .toSet()
                      .length;
              final progress = (daysWithWorkouts / 7).clamp(0.0, 1.0);
              return _StreakRing(
                progress: progress,
                label: '$daysWithWorkouts/7',
              );
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: StreamBuilder<List<WorkoutSession>>(
              stream: wsBloc.allSessionsStream,
              builder: (context, snap) {
                final sessions = snap.data ?? const <WorkoutSession>[];
                final ongoing = _findOngoingSession(sessions);
                final todayRoutine = _findTodayRoutine(routines);
                final quickRoutine = _pickQuickStartRoutine(routines);
                final sessionsThisWeek = _sessionsInLastNDays(sessions, 7);

                late final String title;
                late final String subtitle;
                late final IconData icon;
                late final VoidCallback onPressed;

                if (ongoing != null) {
                  title = 'Resume Workout';
                  subtitle = ongoing.routine.routineName;
                  icon = Icons.play_circle_fill_rounded;
                  onPressed =
                      () => _startRoutine(
                        context,
                        ongoing.routine,
                        resumeSession: ongoing,
                      );
                } else if (todayRoutine != null) {
                  title = 'Start Today\'s Plan';
                  subtitle = todayRoutine.routineName;
                  icon = Icons.event_available_rounded;
                  onPressed = () => _startRoutine(context, todayRoutine);
                } else if (routines.isEmpty) {
                  title = 'Create Your First Routine';
                  subtitle = 'Start with a body-part template';
                  icon = Icons.add_task_rounded;
                  onPressed = () => _showAddRoutineSheet(context);
                } else if (sessionsThisWeek == 0 && quickRoutine != null) {
                  title = 'Reignite Momentum';
                  subtitle = 'Quick launch: ${quickRoutine.routineName}';
                  icon = Icons.local_fire_department_rounded;
                  onPressed = () => _startRoutine(context, quickRoutine);
                } else if (quickRoutine != null) {
                  title = 'Quick Start';
                  subtitle = quickRoutine.routineName;
                  icon = Icons.flash_on_rounded;
                  onPressed = () => _startRoutine(context, quickRoutine);
                } else {
                  title = 'See Progress';
                  subtitle = 'Review your training insights';
                  icon = Icons.bar_chart_rounded;
                  onPressed = () => _openProgress(context);
                }

                return _BigCTA(
                  title: title,
                  subtitle: subtitle,
                  color: cs.secondary,
                  icon: icon,
                  onPressed: onPressed,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _onPrimeTap(BuildContext context, List<Routine> routines) {
    final quick = _pickQuickStartRoutine(routines);
    if (quick == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Create a routine first to use Quick Start.'),
        ),
      );
      _showAddRoutineSheet(context);
      return;
    }
    _confettiController.play();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Prime unlocked: 90 seconds to momentum')),
    );
    _startRoutine(context, quick);
  }

  // Note: previously there was a "Surprise Me" action that randomly
  // launched a routine session. It has been removed per request.

  // --- Pattern Interrupt (break scroll with a single irresistible choice) ---
  Widget _buildPatternInterrupt(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Card(
        color: cs.primary.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(Icons.psychology, color: cs.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Break the Scroll',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Nudge into action with a quick start.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              FilledButton(
                onPressed:
                    () => _onPrimeTap(
                      context,
                      context.read<RoutinesBloc>().currentRoutinesList,
                    ),
                style: FilledButton.styleFrom(backgroundColor: cs.primary),
                child: const Text('Start Now'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Continue / Today's Plan Card (replaces old starter) ---
  Widget _buildContinueCard(BuildContext context, List<Routine> routines) {
    final wsBloc = context.read<WorkoutSessionBloc>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: StreamBuilder<List<WorkoutSession>>(
        stream: wsBloc.allSessionsStream,
        builder: (context, snap) {
          final sessions = snap.data ?? const <WorkoutSession>[];
          WorkoutSession? ongoing;
          WorkoutSession? lastCompleted;
          if (sessions.isNotEmpty) {
            // find ongoing (no endTime or !isCompleted)
            final maybeOngoing = sessions.firstWhere(
              (s) => !s.isCompleted || s.endTime == null,
              orElse: () => sessions.first,
            );
            if (!maybeOngoing.isCompleted || maybeOngoing.endTime == null) {
              ongoing = maybeOngoing;
            }

            // sort by end/start time for last completed
            final completed =
                sessions
                    .where((s) => s.isCompleted && s.endTime != null)
                    .toList()
                  ..sort(
                    (a, b) => (b.endTime ?? b.startTime).compareTo(
                      a.endTime ?? a.startTime,
                    ),
                  );
            if (completed.isNotEmpty) lastCompleted = completed.first;
          }

          final todayRoutines =
              routines
                  .where((r) => r.weekdays.contains(DateTime.now().weekday))
                  .toList();

          String title;
          String subtitle;
          IconData icon;
          VoidCallback? onPressed;

          if (ongoing != null) {
            title = 'Continue: ${ongoing.routine.routineName}';
            subtitle = 'Pick up where you left off';
            icon = Icons.play_circle_fill_rounded;
            onPressed =
                () => Navigator.push(
                  context,
                  _fadeRoute(
                    RoutineStepPageV2(
                      routine: ongoing!.routine,
                      resumeSession: ongoing,
                    ),
                  ),
                );
          } else if (todayRoutines.isNotEmpty) {
            final r = todayRoutines.first;
            title = 'Today\'s Plan: ${r.routineName}';
            subtitle = 'Scheduled for today';
            icon = Icons.event_available_rounded;
            onPressed =
                () => Navigator.push(
                  context,
                  _fadeRoute(RoutineStepPageV2(routine: r)),
                );
          } else if (lastCompleted != null) {
            title = 'Repeat: ${lastCompleted.routine.routineName}';
            subtitle = 'Run your last session again';
            icon = Icons.replay_rounded;
            onPressed =
                () => Navigator.push(
                  context,
                  _fadeRoute(
                    RoutineStepPageV2(routine: lastCompleted!.routine),
                  ),
                );
          } else {
            title = 'Build Your First Routine';
            subtitle = 'Create one manually in a minute';
            icon = Icons.add_task_rounded;
            onPressed = () => _showAddRoutineSheet(context);
          }

          final cs = Theme.of(context).colorScheme;
          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onPressed,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: cs.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionHub(BuildContext context, List<Routine> routines) {
    final cs = Theme.of(context).colorScheme;
    final hasRoutines = routines.isNotEmpty;
    final hasProfile = _userProfile != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your Dashboard',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _MiniActionButton(
                      icon: Icons.calendar_today_rounded,
                      label: 'Calendar',
                      onTap: () => _openCalendar(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MiniActionButton(
                      icon: Icons.show_chart_rounded,
                      label: 'Progress',
                      onTap: () => _openProgress(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MiniActionButton(
                      icon:
                          hasRoutines
                              ? Icons.playlist_add_check_rounded
                              : Icons.add_box_rounded,
                      label: hasRoutines ? 'Routines' : 'Create',
                      onTap:
                          () =>
                              hasRoutines
                                  ? _openRoutineDetail(context, routines.first)
                                  : _showAddRoutineSheet(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Text(
                  hasProfile
                      ? 'Keep building consistency. Small sessions done daily beat random intense bursts.'
                      : 'Complete onboarding in Settings to unlock more personalized recommendations.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openCalendar(BuildContext context) {
    Navigator.push(context, _fadeRoute(const CalenderPage()));
  }

  void _openProgress(BuildContext context) {
    Navigator.push(context, _fadeRoute(const StatisticsPage()));
  }

  void _openCategoryPath(
    BuildContext context,
    MainTargetedBodyPart part,
    List<Routine> routines,
  ) {
    final matches =
        routines.where((r) => r.mainTargetedBodyPart == part).toList()
          ..sort((a, b) => b.createdDate.compareTo(a.createdDate));
    if (matches.isNotEmpty) {
      _openRoutineDetail(context, matches.first);
      return;
    }
    Navigator.push(
      context,
      _fadeRoute(RoutineEditPage.add(mainTargetedBodyPart: part)),
    );
  }

  void _openRoutineDetail(BuildContext context, Routine routine) {
    final routinesBloc = context.read<RoutinesBloc>();
    final rid = routine.id;
    if (rid == null) {
      Navigator.push(context, _fadeRoute(RoutineStepPageV2(routine: routine)));
      return;
    }
    routinesBloc.selectRoutine(rid);
    Navigator.push(context, _fadeRoute(const RoutineDetailPage()));
  }

  WorkoutSession? _findOngoingSession(List<WorkoutSession> sessions) {
    for (final session in sessions) {
      if (!session.isCompleted || session.endTime == null) return session;
    }
    return null;
  }

  int _sessionsInLastNDays(List<WorkoutSession> sessions, int days) {
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: days - 1));
    return sessions.where((s) => !s.startTime.isBefore(start)).length;
  }

  Routine? _findTodayRoutine(List<Routine> routines) {
    final weekday = DateTime.now().weekday;
    for (final routine in routines) {
      if (routine.weekdays.contains(weekday)) return routine;
    }
    return null;
  }

  Routine? _pickQuickStartRoutine(List<Routine> routines) {
    if (routines.isEmpty) return null;
    final copy = List<Routine>.from(routines);
    copy.sort((a, b) {
      final cmpParts = a.parts.length.compareTo(b.parts.length);
      if (cmpParts != 0) return cmpParts;
      return b.completionCount.compareTo(a.completionCount);
    });
    return copy.first;
  }

  void _startRoutine(
    BuildContext context,
    Routine routine, {
    WorkoutSession? resumeSession,
  }) {
    _confettiController.play();
    Navigator.push(
      context,
      _fadeRoute(
        RoutineStepPageV2(routine: routine, resumeSession: resumeSession),
      ),
    );
  }

  // --- Weekly Activity (simple bar chart using fl_chart) ---
  Widget _buildWeeklyActivity(BuildContext context) {
    final wsBloc = context.read<WorkoutSessionBloc>();
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: StreamBuilder<List<WorkoutSession>>(
        stream: wsBloc.allSessionsStream,
        builder: (context, snap) {
          final sessions = snap.data ?? const <WorkoutSession>[];
          final now = DateTime.now();
          final start = DateTime(
            now.year,
            now.month,
            now.day,
          ).subtract(const Duration(days: 6));
          final byDay = List.generate(7, (i) => 0);
          for (final s in sessions) {
            final day = DateTime(
              s.startTime.year,
              s.startTime.month,
              s.startTime.day,
            );
            if (!day.isBefore(start)) {
              final diff = day.difference(start).inDays;
              if (diff >= 0 && diff < 7) byDay[diff] += 1;
            }
          }

          final double rawMax =
              (byDay.isEmpty ? 1 : byDay.reduce((a, b) => a > b ? a : b))
                  .toDouble();
          final double maxY =
              rawMax < 1.0 ? 1.0 : (rawMax > 5.0 ? 5.0 : rawMax);
          return Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.bar_chart_rounded, color: cs.secondary),
                      const SizedBox(width: 8),
                      Text(
                        'Weekly Activity',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 120,
                    child: BarChart(
                      BarChartData(
                        borderData: FlBorderData(show: false),
                        gridData: FlGridData(show: false),
                        titlesData: FlTitlesData(
                          leftTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final labels = [
                                  'M',
                                  'T',
                                  'W',
                                  'T',
                                  'F',
                                  'S',
                                  'S',
                                ];
                                int idx = value.toInt().clamp(0, 6);
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6.0),
                                  child: Text(
                                    labels[idx],
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        barGroups: List.generate(7, (i) {
                          final v = byDay[i].toDouble();
                          return BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: v,
                                color: cs.primary,
                                width: 12,
                                borderRadius: BorderRadius.circular(6),
                                backDrawRodData: BackgroundBarChartRodData(
                                  show: true,
                                  toY: maxY,
                                  color: cs.primary.withValues(alpha: 0.12),
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                      swapAnimationDuration: const Duration(milliseconds: 300),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // --- Body part categories row ---
  Widget _buildCategories(BuildContext context, List<Routine> routines) {
    final cs = Theme.of(context).colorScheme;
    final items = [
      ('Full Body', 'assets/muscle-96.png', MainTargetedBodyPart.FullBody),
      ('Chest', 'assets/chest-96.png', MainTargetedBodyPart.Chest),
      ('Back', 'assets/back-96.png', MainTargetedBodyPart.Back),
      ('Legs', 'assets/leg-96.png', MainTargetedBodyPart.Leg),
      ('Abs', 'assets/abs-96.png', MainTargetedBodyPart.Abs),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.category_rounded, color: cs.secondary),
              const SizedBox(width: 8),
              Text(
                'Categories',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final label = items[i].$1;
                final asset = items[i].$2;
                final part = items[i].$3;
                return _CategoryChip(
                  label: label,
                  assetPath: asset,
                  onTap: () => _openCategoryPath(context, part, routines),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoutineListSectionsWidget(
    BuildContext context,
    List<Routine> routines,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _buildRoutineListSections(context, routines),
    );
  }

  Widget _buildAiCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap:
              () => Navigator.push(context, _fadeRoute(const RecommendPage())),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  size: 32,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Create with AI",
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Let AI generate a workout routine based on your goals.",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Legacy Coach Picks Sheet (unused) ---
  void _openQuickStartSheet_unused(
    BuildContext context,
    List<Routine> routines,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        int minutes = 30;
        String fitness = 'Intermediate';
        String goal = 'Strength';
        MainTargetedBodyPart focus = MainTargetedBodyPart.FullBody;

        List<Routine> buildSuggestions() {
          final list = List<Routine>.from(routines);
          list.sort(
            (a, b) => _quickStartScore_unused(
              a,
              minutes,
              fitness,
              goal,
              focus,
            ).compareTo(
              _quickStartScore_unused(b, minutes, fitness, goal, focus),
            ),
          );
          return list.reversed.take(3).toList();
        }

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (ctx, scrollController) {
            return StatefulBuilder(
              builder: (ctx, setState) {
                final suggestions = buildSuggestions();
                return SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.flash_on_rounded),
                          const SizedBox(width: 8),
                          Text(
                            'Coach Picks',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Duration',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<int>(
                        segments: const [
                          ButtonSegment(value: 15, label: Text('15 min')),
                          ButtonSegment(value: 30, label: Text('30 min')),
                          ButtonSegment(value: 45, label: Text('45 min')),
                        ],
                        selected: {minutes},
                        onSelectionChanged:
                            (s) => setState(() => minutes = s.first),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Goal',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'Strength',
                            label: Text('Strength'),
                          ),
                          ButtonSegment(
                            value: 'Endurance',
                            label: Text('Endurance'),
                          ),
                          ButtonSegment(
                            value: 'Weight Loss',
                            label: Text('Weight Loss'),
                          ),
                        ],
                        selected: {goal},
                        onSelectionChanged:
                            (s) => setState(() => goal = s.first),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Fitness Level',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'Beginner',
                            label: Text('Beginner'),
                          ),
                          ButtonSegment(
                            value: 'Intermediate',
                            label: Text('Intermediate'),
                          ),
                          ButtonSegment(
                            value: 'Advanced',
                            label: Text('Advanced'),
                          ),
                        ],
                        selected: {fitness},
                        onSelectionChanged:
                            (s) => setState(() => fitness = s.first),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Focus',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            MainTargetedBodyPart.values.map((part) {
                              final selected = part == focus;
                              return ChoiceChip(
                                label: Text(part.name),
                                selected: selected,
                                onSelected: (_) => setState(() => focus = part),
                              );
                            }).toList(),
                      ),
                      const SizedBox(height: 20),
                      if (suggestions.isNotEmpty) ...[
                        Text(
                          'Suggested',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Column(
                          children:
                              suggestions
                                  .map(
                                    (r) => ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 8,
                                          ),
                                      leading: const Icon(Icons.fitness_center),
                                      title: Text(
                                        r.routineName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      subtitle: Text(
                                        '${r.parts.length} parts • ${r.mainTargetedBodyPart.name}',
                                      ),
                                      trailing: FilledButton(
                                        onPressed: () {
                                          Navigator.pop(ctx);
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder:
                                                  (_) => RoutineStepPageV2(
                                                    routine: r,
                                                  ),
                                            ),
                                          );
                                        },
                                        child: const Text('Start'),
                                      ),
                                    ),
                                  )
                                  .toList(),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: const Text('Start Suggested'),
                              onPressed:
                                  suggestions.isEmpty
                                      ? null
                                      : () {
                                        final r = suggestions.first;
                                        Navigator.pop(ctx);
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder:
                                                (_) => RoutineStepPageV2(
                                                  routine: r,
                                                ),
                                          ),
                                        );
                                      },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.auto_awesome),
                              label: const Text('Use AI Coach'),
                              onPressed: () {
                                Navigator.pop(ctx);
                                _goAI(context);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // --- Your Routines (modern compact grid) ---
  Widget _buildRoutinesGridSection(
    BuildContext context,
    List<Routine> routines,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.view_module_rounded,
                color: theme.colorScheme.secondary,
              ),
              const SizedBox(width: 8),
              Text(
                'Your Routines',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              // Increase tile height slightly more to eliminate tiny overflow
              // width/height = aspect; smaller value => taller cards
              childAspectRatio: 0.78,
            ),
            itemCount: routines.length,
            itemBuilder: (ctx, i) {
              return _RoutineCompactCard(routine: routines[i]);
            },
          ),
        ],
      ),
    );
  }

  int _quickStartScore_unused(
    Routine r,
    int minutes,
    String fitness,
    String goal,
    MainTargetedBodyPart focus,
  ) {
    int score = 0;
    final now = DateTime.now();
    // Duration heuristic
    int targetPartsMax;
    if (minutes <= 20) {
      targetPartsMax = 2;
    } else if (minutes <= 35) {
      targetPartsMax = 3;
    } else {
      targetPartsMax = 5;
    }
    if (r.parts.length <= targetPartsMax) {
      score += 2;
    } else if (r.parts.length <= targetPartsMax + 1) {
      score += 1;
    }
    // Goal/focus heuristic
    if (goal != 'Strength' &&
        focus == MainTargetedBodyPart.FullBody &&
        r.mainTargetedBodyPart == MainTargetedBodyPart.FullBody) {
      score += 2;
    }
    if (r.mainTargetedBodyPart == focus) {
      score += 2;
    }
    // Fitness heuristic
    if (fitness == 'Beginner' && r.parts.length <= 3) {
      score += 1;
    }
    if (fitness == 'Advanced' && r.parts.length >= 4) {
      score += 1;
    }
    // Today scheduling
    if (r.weekdays.contains(now.weekday)) {
      score += 1;
    }
    // Not completed too recently
    final last = r.lastCompletedDate;
    if (last == null || now.difference(last).inDays >= 2) score += 1;
    return score;
  }

  List<Widget> _buildRoutineListSections(
    BuildContext context,
    List<Routine> routines,
  ) {
    final todayRoutines =
        routines
            .where((r) => r.weekdays.contains(DateTime.now().weekday))
            .toList();
    final categorizedRoutines = _categorizeRoutines(routines);

    return [
      if (todayRoutines.isNotEmpty)
        ..._buildTodaySection(context, todayRoutines),
      ..._buildCategorizedSections(context, categorizedRoutines),
    ];
  }

  Map<MainTargetedBodyPart, List<Routine>> _categorizeRoutines(
    List<Routine> routines,
  ) {
    final map = <MainTargetedBodyPart, List<Routine>>{};
    for (final routine in routines) {
      (map[routine.mainTargetedBodyPart] ??= []).add(routine);
    }
    return map;
  }

  List<Widget> _buildTodaySection(
    BuildContext context,
    List<Routine> todayRoutines,
  ) {
    final theme = Theme.of(context);
    final weekday =
        [
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
          'Saturday',
          'Sunday',
        ][DateTime.now().weekday - 1];

    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              weekday,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.secondary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              "Workout${todayRoutines.length > 1 ? 's' : ''}",
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      ...todayRoutines.map(
        (routine) => RoutineCard(
          key: ValueKey('today_${routine.id}'),
          isActive: true,
          routine: routine,
        ),
      ),
      const SizedBox(height: 16),
    ];
  }

  List<Widget> _buildCategorizedSections(
    BuildContext context,
    Map<MainTargetedBodyPart, List<Routine>> categorizedRoutines,
  ) {
    final theme = Theme.of(context);
    return MainTargetedBodyPart.values.expand((bodyPart) {
      final routines = categorizedRoutines[bodyPart] ?? [];
      if (routines.isEmpty) return <Widget>[];
      return [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            mainTargetedBodyPartToStringConverter(bodyPart),
            style: theme.textTheme.titleLarge,
          ),
        ),
        ...routines.map(
          (routine) =>
              RoutineCard(key: ValueKey('cat_${routine.id}'), routine: routine),
        ),
      ];
    }).toList();
  }

  Widget _buildEmptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 32.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.fitness_center,
            size: 50,
            color: Theme.of(context).hintColor.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 16),
          Text(
            'No Routines Created',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            "Tap the '+' button to create a new routine or use the AI to generate one for you.",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).hintColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showAddRoutineSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        final items = [
          (MainTargetedBodyPart.FullBody, 'Full Body', Icons.all_inclusive),
          (MainTargetedBodyPart.Chest, 'Chest', Icons.fitness_center),
          (MainTargetedBodyPart.Back, 'Back', Icons.fitness_center),
          (MainTargetedBodyPart.Leg, 'Legs', Icons.directions_run),
          (MainTargetedBodyPart.Abs, 'Abs', Icons.self_improvement),
        ];
        final cs = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.add_circle_rounded, color: cs.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Create New Routine',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.95,
                ),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final part = items[i].$1;
                  final label = items[i].$2;
                  final icon = items[i].$3;
                  return _CreateTile(
                    label: label,
                    icon: icon,
                    onTap: () {
                      Navigator.pop(sheetContext);
                      Navigator.push(
                        context,
                        _fadeRoute(
                          RoutineEditPage.add(mainTargetedBodyPart: part),
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 6),
              FilledButton.icon(
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Use AI Templates'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: () {
                  Navigator.pop(sheetContext);
                  _navigateToAddFromTemplate(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _navigateToAddFromTemplate(BuildContext context) {
    Navigator.push(context, _fadeRoute(const RecommendPage()));
  }
}

// --- Local helper widgets (kept here for minimal footprint) ---
class _QuickChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: cs.secondary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: cs.secondary.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: cs.secondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: cs.secondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoutineCompactCard extends StatelessWidget {
  final Routine routine;
  const _RoutineCompactCard({required this.routine});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final body = mainTargetedBodyPartToStringConverter(
      routine.mainTargetedBodyPart,
    );
    final partsCount = routine.parts.length;
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          final routinesBlocInstance = context.read<RoutinesBloc>();
          final int? currentRoutineId = routine.id;
          if (currentRoutineId != null) {
            routinesBlocInstance.selectRoutine(currentRoutineId);
          }
          Navigator.push(context, _fadeRoute(RoutineDetailPage()));
        },
        onLongPress: () => _showRoutineOptions(context),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.fitness_center, color: cs.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      routine.routineName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _chipLabel(context, body),
                  _chipLabel(
                    context,
                    '$partsCount part${partsCount == 1 ? '' : 's'}',
                  ),
                  if (routine.isAiGenerated) _chipLabel(context, 'AI'),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.bottomRight,
                child: IconButton.filledTonal(
                  icon: const Icon(Icons.play_arrow_rounded),
                  color: cs.onSecondaryContainer,
                  onPressed: () {
                    // Go to Routine Detail so user can press Start Workout
                    final routinesBlocInstance = context.read<RoutinesBloc>();
                    final int? rid = routine.id;
                    if (rid != null) {
                      routinesBlocInstance.selectRoutine(rid);
                    }
                    Navigator.push(
                      context,
                      _fadeRoute(const RoutineDetailPage()),
                    );
                  },
                  tooltip: 'Open Details',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chipLabel(BuildContext context, String text) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Text(text, style: Theme.of(context).textTheme.bodySmall),
    );
  }

  void _showRoutineOptions(BuildContext context) async {
    final routinesBlocInstance = context.read<RoutinesBloc>();
    final int? rid = routine.id;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit Routine'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    _fadeRoute(RoutineEditPage.edit(routine: routine)),
                  );
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: Colors.redAccent,
                ),
                title: const Text('Delete Routine'),
                onTap: () async {
                  Navigator.pop(ctx);
                  if (rid == null) return;
                  final ok = await showDialog<bool>(
                    context: context,
                    builder:
                        (dctx) => AlertDialog(
                          title: const Text('Delete routine?'),
                          content: Text(
                            'Delete "${routine.routineName}" permanently?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dctx, false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(dctx, true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                  );
                  if (ok == true) {
                    await routinesBlocInstance.deleteRoutine(rid);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Routine deleted')),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StreakRing extends StatelessWidget {
  final double progress; // 0..1
  final String label;
  const _StreakRing({required this.progress, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 76,
      height: 76,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 76,
            height: 76,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 8,
              backgroundColor: cs.primary.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(cs.primary),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(
                'streak',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BigCTA extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;
  final VoidCallback onPressed;
  const _BigCTA({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 76,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        onPressed: onPressed,
        child: Row(
          children: [
            Icon(icon, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MiniActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outlineVariant),
          color: cs.surfaceContainerHighest.withValues(alpha: 0.7),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: cs.primary),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Small reusable bits ---
PageRoute<T> _fadeRoute<T>(Widget page) => PageRouteBuilder<T>(
  pageBuilder: (_, __, ___) => page,
  transitionsBuilder: (context, animation, secondaryAnimation, child) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.02),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  },
  transitionDuration: const Duration(milliseconds: 250),
);

class _CreateTile extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _CreateTile({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_CreateTile> createState() => _CreateTileState();
}

class _CreateTileState extends State<_CreateTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: _pressed ? 0.97 : 1.0,
        child: Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outlineVariant),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, size: 28, color: cs.primary),
              const SizedBox(height: 8),
              Text(
                widget.label,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final String assetPath;
  final VoidCallback onTap;
  const _CategoryChip({
    required this.label,
    required this.assetPath,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        width: 130,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: cs.surfaceContainerHighest,
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                assetPath,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
