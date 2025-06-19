import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:workout_planner/bloc/routines_bloc.dart';
import 'package:workout_planner/models/main_targeted_body_part.dart';
import 'package:workout_planner/ui/recommend_page.dart';
import 'package:workout_planner/ui/routine_edit_page.dart';
import 'package:workout_planner/utils/routine_helpers.dart';
import 'package:workout_planner/ui/components/routine_card.dart';
import 'package:workout_planner/ui/workout_session_page.dart'; // Import WorkoutSessionPage

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ScrollController _scrollController = ScrollController();
  bool _showAppBarShadow = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RoutinesBloc>().fetchAllRoutines();
    });

    _scrollController.addListener(_scrollListener);
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final routinesBloc = context.watch<RoutinesBloc>();
    return Scaffold(
      body: NestedScrollView(
        controller: _scrollController,
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            title: const Text('Workout Planner'),
            pinned: true,
            floating: true,
            forceElevated: _showAppBarShadow,
          ),
        ],
        body: ListView(
          padding: EdgeInsets.zero,
          children: [
            _buildAiCard(context),
            _buildQuickStart(context),
            StreamBuilder<List<Routine>>(
              stream: routinesBloc.allRoutinesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ));
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildEmptyState(context);
                }
                return _buildRoutineListSectionsWidget(context, snapshot.data!);
              },
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => _showAddRoutineSheet(context),
      ),
    );
  }

  Widget _buildRoutineListSectionsWidget(BuildContext context, List<Routine> routines) {
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
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const RecommendPage()),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, size: 32, color: Theme.of(context).colorScheme.secondary),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Create with AI", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        "Let AI generate a workout routine based on your goals.",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStart(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: ElevatedButton.icon(
        icon: const Icon(Icons.play_arrow),
        label: const Text('Quick Start'),
        onPressed: () async {
          final routinesBloc = context.read<RoutinesBloc>();
          try {
            final routines = await routinesBloc.allRoutinesStream.first;
            if (routines.isEmpty) {
              // Show questionnaire dialog if no routines exist
              await _showQuickStartQuestionnaire(context);
            } else {
              // Use the first available routine
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => WorkoutSessionPage(routine: routines.first),
                ),
              );
            }
          } catch (error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error loading routines: $error')),
            );
          }
        },
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Future<void> _showQuickStartQuestionnaire(BuildContext context) async {
    String? fitnessLevel;
    String? mainGoal;
    int? availableMinutes;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Quick Start Setup'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Let\'s create a personalized workout routine for you.'),
                    const SizedBox(height: 20),
                    const Text('What\'s your fitness level?'),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'Beginner', label: Text('Beginner')),
                        ButtonSegment(value: 'Intermediate', label: Text('Intermediate')),
                        ButtonSegment(value: 'Advanced', label: Text('Advanced')),
                      ],
                      selected: fitnessLevel != null ? {fitnessLevel!} : <String>{},
                      onSelectionChanged: (Set<String> selection) {
                        setState(() => fitnessLevel = selection.first);
                      },
                    ),
                    const SizedBox(height: 20),
                    const Text('What\'s your main goal?'),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'Strength', label: Text('Strength')),
                        ButtonSegment(value: 'Endurance', label: Text('Endurance')),
                        ButtonSegment(value: 'Weight Loss', label: Text('Weight Loss')),
                      ],
                      selected: mainGoal != null ? {mainGoal!} : <String>{},
                      onSelectionChanged: (Set<String> selection) {
                        setState(() => mainGoal = selection.first);
                      },
                    ),
                    const SizedBox(height: 20),
                    const Text('How many minutes do you have?'),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 15, label: Text('15 min')),
                        ButtonSegment(value: 30, label: Text('30 min')),
                        ButtonSegment(value: 45, label: Text('45 min')),
                      ],
                      selected: availableMinutes != null ? {availableMinutes!} : <int>{},
                      onSelectionChanged: (Set<int> selection) {
                        setState(() => availableMinutes = selection.first);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: fitnessLevel != null && mainGoal != null && availableMinutes != null
                      ? () => Navigator.pop(context, true)
                      : null,
                  child: const Text('Create Workout'),
                ),
              ],
            );
          },
        );
      },
    ).then((value) {
      if (value == true) {
        // Navigate to RecommendPage with the questionnaire answers
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const RecommendPage(),
          ),
        );
      }
    });
  }


  List<Widget> _buildRoutineListSections(BuildContext context, List<Routine> routines) {
    final todayRoutines = routines.where((r) => r.weekdays.contains(DateTime.now().weekday)).toList();
    final categorizedRoutines = _categorizeRoutines(routines);

    return [
      if (todayRoutines.isNotEmpty) ..._buildTodaySection(context, todayRoutines),
      ..._buildCategorizedSections(context, categorizedRoutines),
    ];
  }

  Map<MainTargetedBodyPart, List<Routine>> _categorizeRoutines(List<Routine> routines) {
    final map = <MainTargetedBodyPart, List<Routine>>{};
    for (final routine in routines) {
      (map[routine.mainTargetedBodyPart] ??= []).add(routine);
    }
    return map;
  }

  List<Widget> _buildTodaySection(BuildContext context, List<Routine> todayRoutines) {
    final theme = Theme.of(context);
    final weekday = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][DateTime.now().weekday - 1];

    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(weekday, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.secondary)),
            const SizedBox(width: 8),
            Text("Workout${todayRoutines.length > 1 ? 's' : ''}", style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
      ...todayRoutines.map((routine) => RoutineCard(key: ValueKey('today_${routine.id}'), isActive: true, routine: routine)),
      const SizedBox(height: 16),
    ];
  }

  List<Widget> _buildCategorizedSections(BuildContext context, Map<MainTargetedBodyPart, List<Routine>> categorizedRoutines) {
    final theme = Theme.of(context);
    return MainTargetedBodyPart.values.expand((bodyPart) {
      final routines = categorizedRoutines[bodyPart] ?? [];
      if (routines.isEmpty) return <Widget>[];
      return [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(mainTargetedBodyPartToStringConverter(bodyPart), style: theme.textTheme.titleLarge),
        ),
        ...routines.map((routine) => RoutineCard(key: ValueKey('cat_${routine.id}'), routine: routine)),
      ];
    }).toList();
  }

  Widget _buildEmptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 32.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.fitness_center, size: 50, color: Theme.of(context).hintColor.withOpacity(0.7)),
          const SizedBox(height: 16),
          Text(
            'No Routines Created',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            "Tap the '+' button to create a new routine or use the AI to generate one for you.",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).hintColor),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showAddRoutineSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Wrap(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Text("Create New Routine", style: Theme.of(context).textTheme.titleLarge),
              ),
              const Divider(height: 1),
              ...MainTargetedBodyPart.values.map((val) {
                final title = mainTargetedBodyPartToStringConverter(val);
                return ListTile(
                  leading: Icon(Icons.fitness_center, color: Theme.of(context).colorScheme.primary),
                  title: Text("New '$title' Routine"),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RoutineEditPage.add(mainTargetedBodyPart: val),
                      ),
                    );
                  },
                );
              }),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: Icon(Icons.list_alt_outlined, color: Theme.of(context).colorScheme.secondary),
                title: Text('Add from Template', style: TextStyle(color: Theme.of(context).colorScheme.secondary)),
                onTap: () {
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
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RecommendPage()),
    );
  }
}
