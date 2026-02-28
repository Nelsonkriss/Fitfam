import 'dart:math' as math;
import 'dart:ui';
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
import 'package:flutter/services.dart';
// For optional prompt templates

class RecommendPage extends StatefulWidget {
  final MainTargetedBodyPart? initialPart;
  const RecommendPage({super.key, this.initialPart});

  @override
  _RecommendPageState createState() => _RecommendPageState();
}

class _RecommendPageState extends State<RecommendPage> {
  static const String _missingApiKeyMessage =
      "AI engine is offline. Add OPENROUTER_API_KEY in .env or via --dart-define.";
  static const String _dartDefineHint =
      "OPENROUTER_API_KEY=your_key (.env) or flutter run --dart-define=OPENROUTER_API_KEY=your_key";

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

  void _showMissingApiKeySnackBar() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(_missingApiKeyMessage),
        backgroundColor: AppColors.warning,
      ),
    );
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
      _showMissingApiKeySnackBar();
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
    final titleStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.4,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF040A12),
      appBar: AppBar(
        title: Text("AI Routine Coach", style: titleStyle),
        backgroundColor: const Color(0xFF0A111B).withValues(alpha: 0.95),
        surfaceTintColor: Colors.transparent,
        elevation: _showAppBarShadow ? 8.0 : 0.0,
        shadowColor: Colors.black.withValues(alpha: 0.35),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: _NebulaBackground()),
          ListView(
            controller: _scrollController,
            padding: const EdgeInsets.only(bottom: 28),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: _buildHeroConsole(context),
              ),
              _buildFeaturedForStudents(context),
              _buildQuickPicks(context),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _buildAiComposerPanel(context),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                child: _buildSectionTitle(
                  context,
                  title: "AI-Generated Routines",
                  subtitle: "Saved neural plans grouped by focus",
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
                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: _buildErrorCard(
                        context,
                        'Error loading routines: ${snapshot.error}',
                      ),
                    );
                  }
                  final aiGeneratedRoutines =
                      snapshot.data?.where((r) => r.isAiGenerated).toList() ??
                      [];
                  if (aiGeneratedRoutines.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: _buildEmptyAiState(),
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
        ],
      ),
    );
  }

  Widget _buildHeroConsole(BuildContext context) {
    final bool online = !_apiKeyMissing;
    final statusColor =
        online ? const Color(0xFF3CFFCC) : const Color(0xFFFFB37A);
    final statusLabel = online ? 'AI CORE ONLINE' : 'AI CORE OFFLINE';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0E1C2D), Color(0xFF131128), Color(0xFF102739)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF20E0FF).withValues(alpha: 0.14),
            blurRadius: 30,
            spreadRadius: 1,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withValues(alpha: 0.55),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                statusLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              _buildModelChip(),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Neural Routine Forge',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.2,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            online
                ? 'Generate structured programs with adaptive progression and high-signal prompts.'
                : 'Connect your OpenRouter key to unlock AI generation from templates and custom prompts.',
            style: const TextStyle(
              color: Color(0xCCFFFFFF),
              fontSize: 13,
              height: 1.35,
            ),
          ),
          if (_apiKeyMissing) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _dartDefineHint,
                    style: const TextStyle(
                      color: Color(0xCCFFFFFF),
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(
                      const ClipboardData(text: _dartDefineHint),
                    );
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Command copied.')),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Copy'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.24),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModelChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Text(
        'MODEL ${AppConfig.openRouterModel.toUpperCase()}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.9,
        ),
      ),
    );
  }

  Widget _buildAiComposerPanel(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF081320).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF24D8FF).withValues(alpha: 0.1),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionTitle(
            context,
            title: "Generate with AI",
            subtitle: "Describe split, duration, equipment, and training level",
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF030814),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color:
                    _aiError == null
                        ? Colors.white.withValues(alpha: 0.22)
                        : AppColors.danger.withValues(alpha: 0.75),
                width: 1.2,
              ),
            ),
            child: TextField(
              controller: _aiPromptController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: "e.g., 3-day upper/lower for intermediate, 45 min",
                hintStyle: TextStyle(color: Color(0x88FFFFFF)),
                border: InputBorder.none,
                contentPadding: EdgeInsets.fromLTRB(14, 14, 14, 14),
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
          ),
          if (_aiError != null) ...[
            const SizedBox(height: 8),
            _buildInlineErrorChip(_aiError!),
          ],
          if (_apiKeyMissing) ...[
            const SizedBox(height: 10),
            _buildApiKeyMissingBanner(),
          ],
          const SizedBox(height: 14),
          _buildGenerateButton(),
        ],
      ),
    );
  }

  Widget _buildInlineErrorChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.danger,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApiKeyMissingBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFA55A).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFFFB37A).withValues(alpha: 0.6),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.hub_rounded, color: Color(0xFFFFC287), size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              _missingApiKeyMessage,
              style: TextStyle(color: Color(0xFFFFD8B8), fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenerateButton() {
    final enabled = !_apiKeyMissing && !_isGeneratingAiRoutine;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: enabled ? 1 : 0.62,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient:
              enabled
                  ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF24F0CF), Color(0xFF26B9FF)],
                  )
                  : const LinearGradient(
                    colors: [Color(0xFF2C333D), Color(0xFF303845)],
                  ),
          boxShadow:
              enabled
                  ? [
                    BoxShadow(
                      color: const Color(0xFF22E7D6).withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                  : const [],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: enabled ? _generateAndSaveAiRoutine : null,
            child: Center(
              child:
                  _isGeneratingAiRoutine
                      ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                      : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            color: enabled ? Colors.black87 : Colors.white70,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Generate Routine",
                            style: TextStyle(
                              color: enabled ? Colors.black87 : Colors.white70,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(
    BuildContext context, {
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            height: 1.1,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            color: Color(0x9FFFFFFF),
            fontSize: 12.8,
            height: 1.3,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorCard(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.55)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyAiState() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1220).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.rocket_launch_rounded,
                color: Color(0xFF36E9CC),
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'No AI routines yet',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Use a featured preset or write a custom prompt above to generate your first routine.',
            style: TextStyle(color: Color(0xBBFFFFFF), fontSize: 13),
          ),
        ],
      ),
    );
  }

  // --------------------- Restored Featured + Quick Picks ---------------------
  Widget _buildFeaturedForStudents(BuildContext context) {
    final items = _featuredItems();
    final canGenerate = !_apiKeyMissing && !_isGeneratingAiRoutine;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
          child: _buildSectionTitle(
            context,
            title: 'Featured Signals',
            subtitle: 'High-performing templates tuned for consistency',
          ),
        ),
        SizedBox(
          height: 206,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemBuilder:
                (_, i) => _FeaturedCard(
                  data: items[i],
                  enabled: canGenerate,
                  onTap:
                      canGenerate
                          ? () => _generateFromPrompt(
                            items[i].prompt,
                            title: items[i].title,
                          )
                          : null,
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
    final canGenerate = !_apiKeyMissing && !_isGeneratingAiRoutine;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: _buildSectionTitle(
            context,
            title: 'Quick Picks',
            subtitle: 'Swipe and launch one-tap micro-presets',
          ),
        ),
        SizedBox(
          height: 132,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemBuilder:
                (_, i) => _QuickPickCard(
                  data: items[i],
                  enabled: canGenerate,
                  onTap:
                      canGenerate
                          ? () => _generateFromPrompt(
                            items[i].prompt,
                            title: items[i].title,
                          )
                          : null,
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
      _showMissingApiKeySnackBar();
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
  final VoidCallback? onTap;
  final bool enabled;
  const _FeaturedCard({
    required this.data,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      opacity: enabled ? 1 : 0.6,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 298,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              colors: data.gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            boxShadow: [
              BoxShadow(
                color: data.gradient.first.withValues(alpha: 0.23),
                blurRadius: 26,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -18,
                top: -14,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
              Positioned(
                left: -24,
                bottom: -24,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.08),
                  ),
                ),
              ),
              if (data.assetOverlay != null)
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: Opacity(
                    opacity: 0.93,
                    child: Image.asset(
                      data.assetOverlay!,
                      width: 84,
                      height: 84,
                      fit: BoxFit.contain,
                    ),
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
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 29,
                        fontWeight: FontWeight.w900,
                        height: 1,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      data.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            enabled
                                ? Icons.auto_awesome_rounded
                                : Icons.lock_outline_rounded,
                            color: Colors.white,
                            size: 17,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            enabled ? 'Generate' : 'Locked',
                            style: const TextStyle(
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
      ),
    );
  }
}

class _NebulaBackground extends StatelessWidget {
  const _NebulaBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF060D17), Color(0xFF030811), Color(0xFF02060D)],
            ),
          ),
        ),
        Positioned(
          top: -90,
          right: -40,
          child: _glowOrb(
            size: 220,
            color: const Color(0xFF2DF5D3).withValues(alpha: 0.18),
          ),
        ),
        Positioned(
          top: 180,
          left: -80,
          child: _glowOrb(
            size: 260,
            color: const Color(0xFF2C8BFF).withValues(alpha: 0.16),
          ),
        ),
        Positioned(
          bottom: -110,
          right: -40,
          child: _glowOrb(
            size: 280,
            color: const Color(0xFFFF6FA8).withValues(alpha: 0.11),
          ),
        ),
      ],
    );
  }

  static Widget _glowOrb({required double size, required Color color}) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}

class _QuickPickCard extends StatelessWidget {
  final _RecoData data;
  final VoidCallback? onTap;
  final bool enabled;
  const _QuickPickCard({
    required this.data,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      opacity: enabled ? 1 : 0.58,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 212,
          height: 122,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              colors: data.gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          padding: const EdgeInsets.all(12),
          child: Stack(
            children: [
              if (data.assetOverlay != null)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Opacity(
                    opacity: 0.9,
                    child: Image.asset(
                      data.assetOverlay!,
                      width: 48,
                      height: 48,
                    ),
                  ),
                ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      height: 1.05,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    data.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.95),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    enabled ? 'Launch preset' : 'AI key required',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.25,
                    ),
                  ),
                ],
              ),
            ],
          ),
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
