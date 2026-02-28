import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'design_system.dart';
import 'package:provider/provider.dart';
import 'package:workout_planner/bloc/routines_bloc.dart';
import 'package:workout_planner/models/main_targeted_body_part.dart';
import 'package:workout_planner/utils/routine_helpers.dart';
import 'package:workout_planner/resource/open_router_service.dart';
import 'package:workout_planner/services/notification_service.dart'; // Import NotificationService
import 'components/routine_card.dart';
import 'package:flutter/foundation.dart';
import 'package:workout_planner/resource/ai_parse_isolate.dart';
import 'package:workout_planner/services/progressive_plan_service.dart';
import 'package:workout_planner/config/app_config.dart';
// For optional prompt templates

class RecommendPage extends StatefulWidget {
  final MainTargetedBodyPart? initialPart;
  const RecommendPage({super.key, this.initialPart});

  @override
  _RecommendPageState createState() => _RecommendPageState();
}

class _RecommendPageState extends State<RecommendPage> {
  final ScrollController _scrollController = ScrollController();
  bool _showAppBarShadow = false;

  // --- AI Routine Generation State ---
  final TextEditingController _aiPromptController = TextEditingController();
  bool _isGeneratingAiRoutine = false;
  String? _aiError;
  late final OpenRouterService _openRouterService;
  bool _apiKeyMissing = false;
  // --- End AI State ---

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);

    final apiKey = AppConfig.openRouterApiKey;
    final model = AppConfig.openRouterModel;
    if (apiKey.isEmpty) {
      _apiKeyMissing = true;
      _aiError =
          "OpenRouter API Key is missing. Pass OPENROUTER_API_KEY via --dart-define.";
      _openRouterService = OpenRouterService(apiKey: '', defaultModel: model);
      debugPrint("[RecommendPage] API Key missing in initState.");
    } else {
      _openRouterService = OpenRouterService(
        apiKey: apiKey,
        defaultModel: model,
      );
      debugPrint(
        "[RecommendPage] API Key loaded, OpenRouterService initialized.",
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<RoutinesBloc>().fetchAllRoutines();
        if (_apiKeyMissing) {
          setState(() {});
        }
      }
    });
  }

  void _handleScroll() {
    if (!mounted) return;
    final bool shouldShowShadow = _scrollController.offset > 0;
    if (shouldShowShadow != _showAppBarShadow) {
      setState(() {
        _showAppBarShadow = shouldShowShadow;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _aiPromptController.dispose();
    super.dispose();
  }

  Future<void> _generateAndSaveAiRoutine() async {
    if (_isGeneratingAiRoutine) return; // Prevent double trigger

    // Show a full-screen generating overlay while we work
    bool overlayShown = false;
    void _showGeneratingOverlay() {
      overlayShown = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (ctx) => const _GeneratingOverlay(),
      );
    }

    if (_aiPromptController.text.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _aiError = "Please enter a description for the routine you want.";
        });
      }
      return;
    }

    if (_apiKeyMissing) {
      if (mounted) {
        setState(() {
          _aiError = "OpenRouter API Key is missing. Cannot generate routine.";
        });
      }
      return;
    }

    if (!mounted) return;
    setState(() {
      _isGeneratingAiRoutine = true;
      _aiError = null;
    });
    if (mounted) _showGeneratingOverlay();

    try {
      final String? routineJsonString = await _openRouterService
          .getAiGeneratedRoutineDescription(_aiPromptController.text.trim());

      if (!mounted) return;

      if (routineJsonString != null) {
        final List<Routine> newRoutines = await compute(
          parseRoutinesOnIsolate,
          routineJsonString,
        );
        if (newRoutines.isNotEmpty) {
          if (mounted) {
            // Show notification immediately
            final notificationService = NotificationService(); // Get instance
            await notificationService.showNotification(
              // ID can be based on routine hash or a timestamp to be unique enough for immediate notifications
              id:
                  DateTime.now().millisecondsSinceEpoch %
                  100000, // Simple unique ID
              title: "New AI Routines Created!",
              body: "Your new routines are ready.",
              payload:
                  "ai_routines_created", // Optional: payload for navigation
            );

            await context.read<RoutinesBloc>().addRoutines(newRoutines);
            _aiPromptController.clear();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("AI routines generated and saved!"),
                backgroundColor: Colors.green,
              ),
            );
            // Offer to build a progressive plan
            await _promptBuildPlan(newRoutines);
          }
        } else {
          if (mounted) {
            setState(() {
              _aiError =
                  "AI generated a routine, but it couldn't be understood. Please try a different prompt.";
            });
          }
          debugPrint(
            "[RecommendPage] Failed to parse AI JSON into Routine object. JSON: $routineJsonString",
          );
        }
      } else {
        if (mounted) {
          setState(() {
            _aiError =
                "Failed to get a response from the AI. Check connection.";
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _aiError = "An error occurred: ${e.toString()}";
        });
      }
      debugPrint("[RecommendPage] Error generating AI routine: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingAiRoutine = false;
        });
        // Dismiss the overlay if it's still showing
        if (overlayShown) {
          Navigator.of(context, rootNavigator: true).pop();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final routinesBlocInstance = context.watch<RoutinesBloc>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("AI Routine Coach"),
        elevation: _showAppBarShadow ? 4.0 : 0.0,
        shadowColor: Colors.black.withOpacity(0.3),
      ),
      body: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // Featured and quick picks (restored design)
          _buildFeaturedForStudents(context),
          _buildQuickPicks(context),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "Generate with AI",
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _aiPromptController,
                  decoration: InputDecoration(
                    hintText: "e.g., 3-day full body for beginners",
                    // border: const OutlineInputBorder(), // Will pick up from InputDecorationTheme
                    errorText: _aiError,
                  ),
                  minLines: 2,
                  maxLines: 4,
                  textInputAction: TextInputAction.done,
                  onSubmitted:
                      (_) =>
                          (_isGeneratingAiRoutine || _apiKeyMissing)
                              ? null
                              : _generateAndSaveAiRoutine(),
                  readOnly: _apiKeyMissing,
                ),
                const SizedBox(height: 12),
                if (_apiKeyMissing)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      _aiError ??
                          "API Key is missing. Configure .env file and restart.",
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                _isGeneratingAiRoutine
                    ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                    : ElevatedButton.icon(
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text("Generate Routine"),
                      onPressed:
                          _apiKeyMissing ? null : _generateAndSaveAiRoutine,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        backgroundColor: AppColors.accent,
                      ),
                    ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.only(top: 16.0, left: 16.0, right: 16.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "AI-Generated Routines",
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          StreamBuilder<List<Routine>>(
            stream: routinesBlocInstance.allRoutinesStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Error loading routines: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                );
              }
              final aiGeneratedRoutines =
                  snapshot.data?.where((r) => r.isAiGenerated).toList() ?? [];
              if (aiGeneratedRoutines.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(
                    child: Text(
                      'No AI-generated routines yet. Try creating one above!',
                    ),
                  ),
                );
              }
              final count = _calculateListItemCount(aiGeneratedRoutines);
              return Column(
                children: List.generate(
                  count,
                  (index) =>
                      _buildListItem(context, aiGeneratedRoutines, index),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // --------------------- Restored Featured + Quick Picks ---------------------
  Widget _buildFeaturedForStudents(BuildContext context) {
    final items = _featuredItems();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Featured',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        SizedBox(
          height: 180,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemBuilder:
                (_, i) => _FeaturedCard(
                  data: items[i],
                  onTap:
                      () => _generateFromPrompt(
                        items[i].prompt,
                        title: items[i].title,
                      ),
                ),
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemCount: items.length,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickPicks(BuildContext context) {
    final items = _quickPickItems();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Quick Picks',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        SizedBox(
          height: 180,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemBuilder:
                (_, i) => _FeaturedCard(
                  data: items[i],
                  onTap:
                      () => _generateFromPrompt(
                        items[i].prompt,
                        title: items[i].title,
                      ),
                ),
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemCount: items.length,
          ),
        ),
      ],
    );
  }

  Future<void> _generateFromPrompt(
    String prompt, {
    required String title,
  }) async {
    if (_isGeneratingAiRoutine) return; // Prevent double trigger
    bool overlayShown = false;
    void _showGeneratingOverlay() {
      overlayShown = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (ctx) => const _GeneratingOverlay(),
      );
    }

    if (_apiKeyMissing) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _aiError ?? 'Missing API Key. Configure .env to use AI.',
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }
    final routinesBloc = context.read<RoutinesBloc>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _isGeneratingAiRoutine = true;
      _aiError = null;
    });
    if (mounted) _showGeneratingOverlay();
    try {
      final String? routineJsonString = await _openRouterService
          .getAiGeneratedRoutineDescription(prompt);
      if (!mounted) return;
      if (routineJsonString != null) {
        final List<Routine> routines = await compute(
          parseRoutinesOnIsolate,
          routineJsonString,
        );
        if (routines.isNotEmpty) {
          await routinesBloc.addRoutines(routines);
          await NotificationService().showNotification(
            id: DateTime.now().millisecondsSinceEpoch % 100000,
            title: 'New AI Routines Created!',
            body: '${routines.length} routine(s) ready.',
            payload: 'ai_routines_created',
          );
          messenger.showSnackBar(
            SnackBar(
              content: Text('Generated: $title'),
              backgroundColor: Colors.green,
            ),
          );
          await _promptBuildPlan(routines);
        } else {
          setState(
            () =>
                _aiError =
                    'AI returned something we could not parse. Try a different pick.',
          );
        }
      } else {
        setState(
          () => _aiError = 'No response from AI. Check connection/API key.',
        );
      }
    } catch (e) {
      setState(() => _aiError = 'Error: $e');
    } finally {
      if (mounted)
        setState(() {
          _isGeneratingAiRoutine = false;
        });
      if (mounted && overlayShown) {
        // Dismiss the overlay if it's still showing
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

  Future<void> _promptBuildPlan(List<Routine> baseRoutines) async {
    if (!mounted) return;
    int selectedWeeks = 4;
    bool includeDeload = true;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: StatefulBuilder(
            builder: (ctx, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_graph),
                      const SizedBox(width: 8),
                      Text(
                        'Build Progressive Plan',
                        style: Theme.of(ctx).textTheme.titleLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create a ${selectedWeeks}-week progression with science-based increases and deloads.',
                    style: Theme.of(ctx).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Text('Weeks', style: Theme.of(ctx).textTheme.labelLarge),
                  Wrap(
                    spacing: 8,
                    children:
                        [4, 6, 8]
                            .map(
                              (w) => ChoiceChip(
                                label: Text('$w'),
                                selected: selectedWeeks == w,
                                onSelected:
                                    (_) => setState(() => selectedWeeks = w),
                              ),
                            )
                            .toList(),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Include deload every 4th week'),
                    value: includeDeload,
                    onChanged: (v) => setState(() => includeDeload = v),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Not now'),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        icon: const Icon(Icons.add_task),
                        label: const Text('Build Plan'),
                        onPressed: () async {
                          final plan = ProgressivePlanService.buildPlan(
                            baseRoutines,
                            weeks: selectedWeeks,
                            deloadEvery: includeDeload ? 4 : 0,
                          );
                          await context.read<RoutinesBloc>().addRoutines(plan);
                          if (mounted) Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Created ${plan.length} plan routine(s).',
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  // --------------------- UI Models and Cards ---------------------
  // --------------------- UI Models and Cards ---------------------

  /*  List<_RecoData> _featuredItems() {
    return [
      _RecoData(
        title: 'Science-Based Workout',
        subtitle: 'Evidence > ego',
        gradient: [Colors.deepPurple.shade600, Colors.teal.shade400],
        prompt: 'Science-based hypertrophy routine; 60 minutes; full body emphasis with compounds (squat, hinge, push, pull); RIR 1-2; progressive overload; warmup; finishers optional.',
        assetOverlay: 'assets/exercise_images/app_bodybuilding.webp',
        emojis: '💪📈',
      ),
      _RecoData(
        title: 'After-School Lazy',
        subtitle: 'Low energy, low friction',
        gradient: [Colors.blueGrey.shade700, Colors.indigo.shade400],
        prompt: 'Ultra low-friction after-school workout for tired students; 15-20 minutes; minimal equipment; low DOMS; mood-boost focus; bodyweight + bands; simple timer-based sets.',
        assetOverlay: 'assets/dumbbells.png',
        emojis: '😌🧘',
      ),
      _RecoData(
        title: 'Bro Chest Day',
        subtitle: 'Pump + fun',
        gradient: [Colors.pink.shade400, Colors.redAccent.shade200],
        prompt: 'Classic bro chest workout; 40-50 minutes; high-volume chest focus with triceps finishers; supersets; emphasis on pump; include incline, flat, fly, dips.',
        assetOverlay: 'assets/chest-96.png',
        emojis: '🏋️🔥',
      ),
      _RecoData(
        title: 'Exam Stress Fix',
        subtitle: 'Reset + breathe',
        gradient: [Colors.cyan.shade400, Colors.greenAccent.shade400],
        prompt: 'Stress-reduction routine for exam weeks; 25 minutes; full body mobility + light circuits; nasal breathing cues; end with 3-minute box breathing; low sweat, high calm.',
        assetOverlay: 'assets/exercise_images/app_yoga.webp',
        emojis: '🧘🌿',
      ),
    ];
  }

  List<_RecoData> _quickPickItems() {
    final picks = <_RecoData>[
      _RecoData(
        title: 'Dorm Room 15', subtitle: 'No equipment',
        gradient: [Colors.orange.shade400, Colors.amber.shade600],
        prompt: '15-minute dorm-friendly bodyweight circuit; no equipment; low noise; minimal space; EMOM style; mobility finisher.',
        assetOverlay: 'assets/exercise_images/app_abdominal.webp', emojis: '🏠⏱️',
      ),
      _RecoData(
        title: 'Glute & Legs', subtitle: 'Power hour',
        gradient: [Colors.purple.shade400, Colors.deepPurple.shade700],
        prompt: 'Glutes & legs strength; 40 minutes; compounds + burnouts; progressive sets; RDLs, split squats, hip thrusts, leg press or step-ups.',
        assetOverlay: 'assets/leg-96.png', emojis: '🍑🦵',
      ),
      _RecoData(
        title: 'Pull Day', subtitle: 'Back + biceps',
        gradient: [Colors.blue.shade400, Colors.indigo.shade700],
        prompt: 'Pull day to maximize back growth; 45 minutes; back and biceps; vertical + horizontal pulls; finish with grip and rear delts; mix of strength and volume.',
        assetOverlay: 'assets/back-96.png', emojis: '🧲💪',
      ),
      _RecoData(
        title: 'Push Day', subtitle: 'Chest + shoulders',
        gradient: [Colors.red.shade400, Colors.deepOrange.shade600],
        prompt: 'Push day; 45 minutes; chest, shoulders, triceps; compounds + accessories; tempo work; safe for after-class sessions.',
        assetOverlay: 'assets/chest-96.png', emojis: '➡️🏋️',
      ),
      _RecoData(
        title: '5x5 Basics', subtitle: 'Strength first',
        gradient: [Colors.grey.shade700, Colors.blueGrey.shade500],
        prompt: 'Science-based 5x5 strength routine ; 3 days/week full body; linear progression; safety cues; optional accessories.',
        assetOverlay: 'assets/exercise_images/app_barbell.webp', emojis: '📊🏗️',
      ),
      _RecoData(
        title: 'Bro Arm Blast', subtitle: 'Biceps + triceps',
        gradient: [Colors.pinkAccent.shade200, Colors.deepPurple.shade400],
        prompt: 'High-pump arm workout ; 30-40 minutes; alternating supersets biceps/triceps; finish with forearms; low joint stress.',
        assetOverlay: 'assets/muscle-96.png', emojis: '💥💪',
      ),
    ];
    picks.shuffle(math.Random());
    return picks;
  }
*/
}

// Simple full-screen generating overlay
class _GeneratingOverlay extends StatelessWidget {
  const _GeneratingOverlay();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      child: Container(
        color: Colors.black54,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withOpacity(0.95),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  SizedBox(
                    width: 56,
                    height: 56,
                    child: CircularProgressIndicator(),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Generating your routine... ',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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

class _RecoData {
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final String prompt;
  final String? assetOverlay;
  final String? emojis;
  _RecoData({
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.prompt,
    this.assetOverlay,
    this.emojis,
  });
}

List<_RecoData> _featuredItems() {
  return [
    _RecoData(
      title: 'Science-Based Workout',
      subtitle: 'Evidence > ego',
      gradient: [Colors.deepPurple.shade600, Colors.teal.shade400],
      prompt:
          'Science-based hypertrophy routine; 60 minutes; full body emphasis with compounds (squat, hinge, push, pull); RIR 1-2; progressive overload; warmup; finishers optional.',
      assetOverlay: 'assets/exercise_images/app_bodybuilding.webp',
      emojis: '',
    ),
    _RecoData(
      title: 'After-School Lazy',
      subtitle: 'Low energy, low friction',
      gradient: [Colors.blueGrey.shade700, Colors.indigo.shade400],
      prompt:
          'Ultra low-friction after-school workout for tired students; 15-20 minutes; minimal equipment; low DOMS; mood-boost focus; bodyweight + bands; simple timer-based sets.',
      assetOverlay: 'assets/dumbbells.png',
      emojis: '',
    ),
    _RecoData(
      title: 'Bro Chest Day',
      subtitle: 'Pump + fun',
      gradient: [Colors.pink.shade400, Colors.redAccent.shade200],
      prompt:
          'Classic bro chest workout; 40-50 minutes; high-volume chest focus with triceps finishers; supersets; emphasis on pump; include incline, flat, fly, dips.',
      assetOverlay: 'assets/chest-96.png',
      emojis: '',
    ),
    _RecoData(
      title: 'Exam Stress Fix',
      subtitle: 'Reset + breathe',
      gradient: [Colors.cyan.shade400, Colors.greenAccent.shade400],
      prompt:
          'Stress-reduction routine for exam weeks; 25 minutes; full body mobility + light circuits; nasal breathing cues; end with 3-minute box breathing; low sweat, high calm.',
      assetOverlay: 'assets/exercise_images/app_yoga.webp',
      emojis: '',
    ),
  ];
}

List<_RecoData> _quickPickItems() {
  final picks = <_RecoData>[
    _RecoData(
      title: 'Dorm Room 15',
      subtitle: 'No equipment',
      gradient: [Colors.orange.shade400, Colors.amber.shade600],
      prompt:
          '15-minute dorm-friendly bodyweight circuit; no equipment; low noise; minimal space; EMOM style; mobility finisher.',
      assetOverlay: 'assets/exercise_images/app_abdominal.webp',
      emojis: '',
    ),
    _RecoData(
      title: 'Glute & Legs',
      subtitle: 'Power hour',
      gradient: [Colors.purple.shade400, Colors.deepPurple.shade700],
      prompt:
          'Glutes & legs strength + pump ; 40 minutes; compounds + burnouts; progressive sets; RDLs, split squats, hip thrusts, leg press or step-ups.',
      assetOverlay: 'assets/leg-96.png',
      emojis: '',
    ),
    _RecoData(
      title: 'Pull Day',
      subtitle: 'Back + biceps',
      gradient: [Colors.blue.shade400, Colors.indigo.shade700],
      prompt:
          'Pull day; 45 minutes; back and biceps; vertical + horizontal pulls; finish with grip and rear delts; mix of strength and volume.',
      assetOverlay: 'assets/back-96.png',
      emojis: '',
    ),
    _RecoData(
      title: 'Push Day',
      subtitle: 'Chest + shoulders',
      gradient: [Colors.red.shade400, Colors.deepOrange.shade600],
      prompt:
          'Push day; 45 minutes; chest, shoulders, triceps; compounds + accessories; tempo work; safe for after-class sessions.',
      assetOverlay: 'assets/chest-96.png',
      emojis: '',
    ),
    _RecoData(
      title: '5x5 Basics',
      subtitle: 'Strength first',
      gradient: [Colors.grey.shade700, Colors.blueGrey.shade500],
      prompt:
          'Science-based 5x5 strength routine; 3 days/week full body; linear progression; safety cues; optional accessories.',
      assetOverlay: 'assets/exercise_images/app_barbell.webp',
      emojis: '',
    ),
    _RecoData(
      title: 'Bro Arm Blast',
      subtitle: 'Biceps + triceps',
      gradient: [Colors.pinkAccent.shade200, Colors.deepPurple.shade400],
      prompt:
          'High-pump arm workout; 30-40 minutes; alternating supersets biceps/triceps; finish with forearms; low joint stress.',
      assetOverlay: 'assets/muscle-96.png',
      emojis: '',
    ),
  ];
  picks.shuffle(math.Random());
  return picks;
}

class _FeaturedCard extends StatelessWidget {
  final _RecoData data;
  final VoidCallback onTap;
  const _FeaturedCard({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 280,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: data.gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            if (data.assetOverlay != null)
              Positioned(
                right: 8,
                bottom: 8,
                child: Opacity(
                  opacity: 0.85,
                  child: Image.asset(
                    data.assetOverlay!,
                    width: 80,
                    height: 80,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            Positioned(
              right: 12,
              top: 12,
              child: Text(
                data.emojis ?? '',
                style: const TextStyle(fontSize: 24, color: Colors.white),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    data.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 220,
                    child: Text(
                      data.subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.95),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Generate',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
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

class _QuickPickCard extends StatelessWidget {
  final _RecoData data;
  final VoidCallback onTap;
  const _QuickPickCard({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 165,
        height: 66,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: data.gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(8),
        child: Stack(
          children: [
            if (data.assetOverlay != null)
              Positioned(
                right: 6,
                bottom: 6,
                child: Opacity(
                  opacity: 0.85,
                  child: Image.asset(data.assetOverlay!, width: 32, height: 32),
                ),
              ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.max,
              children: [
                Text(
                  data.emojis ?? '',
                  style: const TextStyle(fontSize: 14, color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  data.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  data.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.95),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Map<MainTargetedBodyPart, List<Routine>> _groupRoutines(
  List<Routine> routines,
) {
  final map = {for (var v in MainTargetedBodyPart.values) v: <Routine>[]};
  for (final routine in routines) {
    if (map.containsKey(routine.mainTargetedBodyPart)) {
      map[routine.mainTargetedBodyPart]!.add(routine);
    } else {
      if (kDebugMode) {
        print(
          "Warning: Routine '${routine.routineName}' has unknown MainTargetedBodyPart: ${routine.mainTargetedBodyPart}",
        );
      }
    }
  }
  map.removeWhere((key, value) => value.isEmpty);
  return map;
}

int _calculateListItemCount(List<Routine> routines) {
  final grouped = _groupRoutines(routines);
  int count = 0;
  grouped.forEach((key, value) {
    if (value.isNotEmpty) {
      count++;
      count += value.length;
    }
  });
  return count;
}

Widget _buildListItem(BuildContext context, List<Routine> routines, int index) {
  final grouped = _groupRoutines(routines);
  final categoriesWithRoutines = grouped.entries.toList();

  int currentIndex = 0;
  for (var entry in categoriesWithRoutines) {
    final bodyPart = entry.key;
    final categoryRoutines = entry.value;

    if (index == currentIndex) {
      return _buildCategoryHeader(context, bodyPart);
    }
    currentIndex++;

    if (index < currentIndex + categoryRoutines.length) {
      final routineIndexInCategory = index - currentIndex;
      final routine = categoryRoutines[routineIndexInCategory];
      return RoutineCard(routine: routine, isRecRoutine: false);
    }
    currentIndex += categoryRoutines.length;
  }
  return const SizedBox.shrink();
}

Widget _buildCategoryHeader(
  BuildContext context,
  MainTargetedBodyPart bodyPart,
) {
  final style = Theme.of(
    context,
  ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold);
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    child: Text(mainTargetedBodyPartToStringConverter(bodyPart), style: style),
  );
}
