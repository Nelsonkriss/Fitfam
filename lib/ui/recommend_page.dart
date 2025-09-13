import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:workout_planner/bloc/routines_bloc.dart';
import 'package:workout_planner/models/main_targeted_body_part.dart';
import 'package:workout_planner/models/routine.dart';
import 'package:workout_planner/resource/open_router_service.dart';
import 'package:workout_planner/resource/shared_prefs_provider.dart';
import 'package:workout_planner/services/notification_service.dart';
import 'routine_edit_page.dart';
import 'package:workout_planner/services/curated_templates.dart';

class RecommendPage extends StatefulWidget {
  final MainTargetedBodyPart? initialPart;
  const RecommendPage({super.key, this.initialPart});

  @override
  State<RecommendPage> createState() => _RecommendPageState();
}

class _RecommendPageState extends State<RecommendPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _aiPromptController = TextEditingController();
  late final OpenRouterService _openRouterService;
  bool _apiKeyMissing = false;
  bool _isGenerating = false;
  String? _aiError;

  @override
  void initState() {
    super.initState();
    final apiKey = dotenv.env['OPENROUTER_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      _apiKeyMissing = true;
      _openRouterService = OpenRouterService(apiKey: '');
    } else {
      _openRouterService = OpenRouterService(apiKey: apiKey);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<RoutinesBloc>().fetchAllRoutines();
      setState(() {});
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _aiPromptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('AI Routine Coach')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Curated Templates', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          ),
          _buildCuratedTemplates(context, cs),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('Or write your own', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          ),
          _buildPromptCard(cs),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('Latest AI routines', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          ),
          _buildLatestAiRoutines(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildPromptCard(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Card(
        color: cs.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              TextField(
                controller: _aiPromptController,
                minLines: 3,
                maxLines: 6,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.edit_note_rounded),
                  border: InputBorder.none,
                  hintText: _apiKeyMissing ? 'OpenRouter API Key is missing in .env' : 'Describe your goal, days, equipment...'
                ),
                readOnly: _apiKeyMissing,
              ),
              const SizedBox(height: 8),
              if (_aiError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(_aiError!, style: TextStyle(color: cs.error)),
                ),
              FilledButton.icon(
                onPressed: _apiKeyMissing || _isGenerating ? null : _generateFromInput,
                icon: const Icon(Icons.auto_awesome),
                label: Text(_isGenerating ? 'Generating...' : 'Generate Routine'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLatestAiRoutines() {
    final bloc = context.read<RoutinesBloc>();
    return StreamBuilder<List<Routine>>(
      stream: bloc.allRoutinesStream,
      builder: (context, snapshot) {
        final items = (snapshot.data ?? []).where((r) => r.isAiGenerated).toList();
        if (items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text('No AI routines yet. Try the prompt above.'),
          );
        }
        return Column(
          children: items.map((r) => Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: ListTile(
              title: Text(r.routineName, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('${r.parts.length} parts · ${r.mainTargetedBodyPart.name}'),
              trailing: TextButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => RoutineEditPage.edit(routine: r)));
                },
                child: const Text('Open'),
              ),
            ),
          )).toList(),
        );
      },
    );
  }

  Future<void> _generateFromInput() async {
    final prompt = _aiPromptController.text.trim();
    if (prompt.isEmpty) {
      setState(() => _aiError = 'Please enter a prompt');
      return;
    }
    await _generateFromPrompt(prompt, title: 'Custom');
  }

  Future<void> _generateFromPrompt(String prompt, {required String title}) async {
    final routinesBloc = context.read<RoutinesBloc>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() { _isGenerating = true; _aiError = null; });
    try {
      final String? routineJsonString = await _openRouterService.getAiGeneratedRoutineDescription(prompt);
      if (!mounted) return;
      if (routineJsonString != null) {
        final List<Routine> routines = _openRouterService.parseRoutinesFromJsonString(routineJsonString);
        if (routines.isNotEmpty) {
          await sharedPrefsProvider.addAiPromptToHistory(prompt);
          await routinesBloc.addRoutines(routines);
          await NotificationService().showNotification(
            id: DateTime.now().millisecondsSinceEpoch % 100000,
            title: 'New AI Routines Created!',
            body: '${routines.length} routine(s) ready.',
            payload: 'ai_routines_created',
          );
          messenger.showSnackBar(
            SnackBar(content: Text('Generated: $title'), backgroundColor: Colors.green),
          );
        } else {
          setState(() => _aiError = 'AI returned something we could not parse. Try a different prompt.');
        }
      } else {
        setState(() => _aiError = 'No response from AI. Check connection/API key.');
      }
    } catch (e) {
      setState(() => _aiError = 'Error: $e');
    } finally {
      if (mounted) setState(() { _isGenerating = false; });
    }
  }

  Widget _buildCuratedTemplates(BuildContext context, ColorScheme cs) {
    final routinesBloc = context.read<RoutinesBloc>();
    final groups = <String, List<Routine>>{
      'Hypertrophy': CuratedTemplates.hypertrophy(),
      'Strength': CuratedTemplates.strength(),
      'Fat Loss': CuratedTemplates.fatLoss(),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: groups.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(entry.key, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: cs.onSurfaceVariant)),
            ),
            const SizedBox(height: 8),
            ...entry.value.map((tmpl) => Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    title: Text(tmpl.routineName, maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text('${tmpl.parts.length} parts · ${tmpl.weekdays.isEmpty ? 'Flexible' : 'Days: ${tmpl.weekdays.join(', ')}'}'),
                    trailing: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(children: [
                        TextButton(
                          onPressed: () async {
                            await routinesBloc.addRoutine(tmpl.copyWith(createdDate: DateTime.now(), isAiGenerated: false));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Template added')));
                            }
                          },
                          child: const Text('Add'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RoutineEditPage.edit(routine: tmpl.copyWith()),
                              ),
                            );
                          },
                          child: const Text('Clone & Tweak'),
                        ),
                      ]),
                    ),
                  ),
                )),
            const SizedBox(height: 8),
          ],
        );
      }).toList(),
    );
  }
}
