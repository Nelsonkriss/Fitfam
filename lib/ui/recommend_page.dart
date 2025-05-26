import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:workout_planner/bloc/routines_bloc.dart';
import 'package:workout_planner/models/main_targeted_body_part.dart';
import 'package:workout_planner/utils/routine_helpers.dart';
import 'package:workout_planner/resource/open_router_service.dart';
import 'package:workout_planner/services/notification_service.dart'; // Import NotificationService
import 'components/routine_card.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Import flutter_dotenv

class RecommendPage extends StatefulWidget {
  const RecommendPage({super.key});

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

    final apiKey = dotenv.env['OPENROUTER_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      _apiKeyMissing = true;
      _aiError = "OpenRouter API Key is missing. Please set it in your .env file and restart the app.";
      _openRouterService = OpenRouterService(apiKey: ''); 
      debugPrint("[RecommendPage] API Key missing in initState.");
    } else {
      _openRouterService = OpenRouterService(apiKey: apiKey);
      debugPrint("[RecommendPage] API Key loaded, OpenRouterService initialized.");
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
          _aiError = "OpenRouter API Key is missing. Cannot generate routine. Please set it in .env and restart.";
        });
      }
      return;
    }

    if (!mounted) return;
    setState(() {
      _isGeneratingAiRoutine = true;
      _aiError = null;
    });

    try {
      final String? routineJsonString = await _openRouterService.getAiGeneratedRoutineDescription(_aiPromptController.text.trim());

      if (!mounted) return;

      if (routineJsonString != null) {
        final Routine? newRoutine = _openRouterService.parseRoutineFromJsonString(routineJsonString);
        if (newRoutine != null) {
          if (mounted) {
            // Show notification immediately
            final notificationService = NotificationService(); // Get instance
            await notificationService.showNotification(
              // ID can be based on routine hash or a timestamp to be unique enough for immediate notifications
              id: DateTime.now().millisecondsSinceEpoch % 100000, // Simple unique ID
              title: "New AI Routine Created!",
              body: "Your new routine '${newRoutine.routineName}' is ready.",
              payload: "ai_routine_created_${newRoutine.id ?? 'new'}" // Optional: payload for navigation
            );

            await context.read<RoutinesBloc>().addRoutine(newRoutine);
            _aiPromptController.clear();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("AI routine generated, saved, and you've been notified!"), backgroundColor: Colors.green),
            );
          }
        } else {
          if (mounted) {
            setState(() {
              _aiError = "AI generated a routine, but it couldn't be understood. Please try a different prompt.";
            });
          }
          debugPrint("[RecommendPage] Failed to parse AI JSON into Routine object. JSON: $routineJsonString");
        }
      } else {
        if (mounted) {
          setState(() {
            _aiError = "Failed to get a response from the AI. Check connection/API key.";
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
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final routinesBlocInstance = context.watch<RoutinesBloc>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("AI Routine Coach"), 
        elevation: _showAppBarShadow ? 4.0 : 0.0,
        shadowColor: Colors.black.withOpacity(0.3),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "Generate with AI",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
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
                  onSubmitted: (_) => (_isGeneratingAiRoutine || _apiKeyMissing) ? null : _generateAndSaveAiRoutine(),
                  readOnly: _apiKeyMissing,
                ),
                const SizedBox(height: 12),
                if (_apiKeyMissing)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      _aiError ?? "API Key is missing. Configure .env file and restart.",
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                      textAlign: TextAlign.center,
                    ),
                  ),
                _isGeneratingAiRoutine
                    ? const Center(child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(),
                      ))
                    : ElevatedButton.icon(
                        icon: const Icon(Icons.auto_awesome),
                        label: const Text("Generate Routine"),
                        onPressed: _apiKeyMissing ? null : _generateAndSaveAiRoutine,
                        style: ElevatedButton.styleFrom( // Theme will provide base, this makes it full width
                          minimumSize: const Size(double.infinity, 48), 
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
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Routine>>(
              stream: routinesBlocInstance.allRoutinesStream, 
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'Error loading routines: ${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                        ),
                      )
                  );
                } else {
                  final aiGeneratedRoutines = snapshot.data?.where((r) => r.isAiGenerated).toList() ?? [];
                  
                  if (aiGeneratedRoutines.isEmpty) {
                    return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            'No AI-generated routines yet. Try creating one above!', 
                            textAlign: TextAlign.center,
                          ),
                        )
                    );
                  }
                  
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
                    itemCount: _calculateListItemCount(aiGeneratedRoutines), 
                    itemBuilder: (context, index) {
                      return _buildListItem(context, aiGeneratedRoutines, index); 
                    },
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Map<MainTargetedBodyPart, List<Routine>> _groupRoutines(List<Routine> routines) {
    final map = { for (var v in MainTargetedBodyPart.values) v : <Routine>[] };
    for (final routine in routines) {
      if (map.containsKey(routine.mainTargetedBodyPart)) {
        map[routine.mainTargetedBodyPart]!.add(routine);
      } else {
        if (kDebugMode) {
          print("Warning: Routine '${routine.routineName}' has unknown MainTargetedBodyPart: ${routine.mainTargetedBodyPart}");
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

  Widget _buildCategoryHeader(BuildContext context, MainTargetedBodyPart bodyPart) {
    final style = Theme.of(context).textTheme.headlineSmall?.copyWith(
      fontWeight: FontWeight.bold,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        mainTargetedBodyPartToStringConverter(bodyPart),
        style: style,
      ),
    );
  }
}