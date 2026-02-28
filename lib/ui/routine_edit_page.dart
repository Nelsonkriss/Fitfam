import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Import BLoC, Models, Utils, Services
import 'package:workout_planner/services/notification_service.dart';
import 'package:workout_planner/bloc/routines_bloc.dart';
import 'package:workout_planner/models/main_targeted_body_part.dart';
import 'package:workout_planner/ui/components/part_edit_card.dart';
import 'package:workout_planner/ui/part_edit_page.dart';
import 'package:workout_planner/utils/routine_helpers.dart';

class _QuickPartTemplate {
  final String title;
  final String subtitle;
  final IconData icon;
  final SetType setType;
  final TargetedBodyPart targetedBodyPart;
  final List<Exercise> exercises;

  const _QuickPartTemplate({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.setType,
    required this.targetedBodyPart,
    required this.exercises,
  });

  Part toPart() {
    return Part(
      setType: setType,
      targetedBodyPart: targetedBodyPart,
      exercises: exercises.map((e) => e.copyWith()).toList(),
      partName: title,
    );
  }
}

class _RoutineBlueprint {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;
  final List<_QuickPartTemplate> partTemplates;
  final List<int> suggestedWeekdays;

  const _RoutineBlueprint({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colors,
    required this.partTemplates,
    required this.suggestedWeekdays,
  });
}

class RoutineEditPage extends StatefulWidget {
  final AddOrEdit addOrEdit;
  final Routine? initialRoutine;
  final MainTargetedBodyPart? mainTargetedBodyPart;

  const RoutineEditPage._({
    super.key,
    required this.addOrEdit,
    this.initialRoutine,
    this.mainTargetedBodyPart,
  });

  factory RoutineEditPage.add({
    Key? key,
    required MainTargetedBodyPart mainTargetedBodyPart,
  }) {
    return RoutineEditPage._(
      key: key,
      addOrEdit: AddOrEdit.add,
      mainTargetedBodyPart: mainTargetedBodyPart,
      initialRoutine: null,
    );
  }

  factory RoutineEditPage.edit({Key? key, required Routine routine}) {
    return RoutineEditPage._(
      key: key,
      addOrEdit: AddOrEdit.edit,
      initialRoutine: routine,
      mainTargetedBodyPart: routine.mainTargetedBodyPart,
    );
  }

  @override
  State<RoutineEditPage> createState() => _RoutineEditPageState();
}

class _RoutineEditPageState extends State<RoutineEditPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameEditingController = TextEditingController();
  late ScrollController _scrollController;
  late PageController _blueprintPageController;
  late Routine _routineEditState;
  bool _isDirty = false;
  late List<bool> _selectedWeekdaysBool;
  int _activeBlueprintPage = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _blueprintPageController = PageController(viewportFraction: 0.86);
    _initializeRoutineState();
    _nameEditingController.addListener(_markDirtyOnNameChange);
  }

  void _markDirtyOnNameChange() {
    if (!_isDirty &&
        _nameEditingController.text != _routineEditState.routineName) {
      setState(() {
        _isDirty = true;
      });
    }
  }

  void _initializeRoutineState() {
    if (widget.addOrEdit == AddOrEdit.edit && widget.initialRoutine != null) {
      final initial = widget.initialRoutine!;
      _routineEditState = initial.copyWith(
        parts:
            initial.parts
                .map(
                  (p) => p.copyWith(
                    exercises: p.exercises.map((e) => e.copyWith()).toList(),
                  ),
                )
                .toList(),
        weekdays: List<int>.from(initial.weekdays),
        routineHistory: List<int>.from(initial.routineHistory),
      );
      _nameEditingController.text = _routineEditState.routineName;
    } else {
      _routineEditState = Routine(
        routineName: '',
        mainTargetedBodyPart: widget.mainTargetedBodyPart!,
        parts: [],
        createdDate: DateTime.now(),
        weekdays: [],
        routineHistory: [],
      );
      _nameEditingController.text = '';
    }
    _selectedWeekdaysBool = List.generate(
      7,
      (index) => _routineEditState.weekdays.contains(index + 1),
    );
    _isDirty = false;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _blueprintPageController.dispose();
    _nameEditingController.removeListener(_markDirtyOnNameChange);
    _nameEditingController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  void _scrollToEnd() {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  TargetedBodyPart _defaultTargetForRoutine() {
    switch (_routineEditState.mainTargetedBodyPart) {
      case MainTargetedBodyPart.Abs:
        return TargetedBodyPart.Abs;
      case MainTargetedBodyPart.Arm:
        return TargetedBodyPart.Arm;
      case MainTargetedBodyPart.Back:
        return TargetedBodyPart.Back;
      case MainTargetedBodyPart.Chest:
        return TargetedBodyPart.Chest;
      case MainTargetedBodyPart.Leg:
        return TargetedBodyPart.Leg;
      case MainTargetedBodyPart.Shoulder:
        return TargetedBodyPart.Shoulder;
      case MainTargetedBodyPart.FullBody:
      case MainTargetedBodyPart.Other:
        return TargetedBodyPart.FullBody;
    }
  }

  List<_QuickPartTemplate> get _quickPartTemplates {
    final baseTarget = _defaultTargetForRoutine();
    return [
      _QuickPartTemplate(
        title: 'Main Lift Focus',
        subtitle: 'One heavy movement with progression-friendly setup',
        icon: Icons.trending_up_rounded,
        setType: SetType.Regular,
        targetedBodyPart: baseTarget,
        exercises: [
          Exercise(
            name: '${targetedBodyPartToStringConverter(baseTarget)} Main Lift',
            weight: 35,
            sets: 4,
            reps: '6-8',
            primaryTarget: baseTarget,
          ),
        ],
      ),
      const _QuickPartTemplate(
        title: 'Push Superset',
        subtitle: 'High tension + pump in one block',
        icon: Icons.bolt_rounded,
        setType: SetType.Super,
        targetedBodyPart: TargetedBodyPart.Chest,
        exercises: [
          Exercise(
            name: 'Incline Dumbbell Press',
            weight: 20,
            sets: 3,
            reps: '8-12',
            primaryTarget: TargetedBodyPart.Chest,
          ),
          Exercise(
            name: 'Cable Lateral Raise',
            weight: 7.5,
            sets: 3,
            reps: '12-15',
            primaryTarget: TargetedBodyPart.Shoulder,
          ),
        ],
      ),
      const _QuickPartTemplate(
        title: 'Pull Strength Pair',
        subtitle: 'Back thickness + lat width',
        icon: Icons.swap_vert_circle_outlined,
        setType: SetType.Super,
        targetedBodyPart: TargetedBodyPart.Back,
        exercises: [
          Exercise(
            name: 'Chest Supported Row',
            weight: 30,
            sets: 4,
            reps: '6-10',
            primaryTarget: TargetedBodyPart.Back,
          ),
          Exercise(
            name: 'Lat Pulldown',
            weight: 35,
            sets: 4,
            reps: '8-12',
            primaryTarget: TargetedBodyPart.Back,
          ),
        ],
      ),
      const _QuickPartTemplate(
        title: 'Leg Power Tri-Set',
        subtitle: 'Strength + stability + hypertrophy',
        icon: Icons.run_circle_outlined,
        setType: SetType.Tri,
        targetedBodyPart: TargetedBodyPart.Leg,
        exercises: [
          Exercise(
            name: 'Back Squat',
            weight: 50,
            sets: 4,
            reps: '5-8',
            primaryTarget: TargetedBodyPart.Leg,
          ),
          Exercise(
            name: 'Romanian Deadlift',
            weight: 45,
            sets: 3,
            reps: '8-10',
            primaryTarget: TargetedBodyPart.Leg,
          ),
          Exercise(
            name: 'Walking Lunge',
            weight: 12,
            sets: 3,
            reps: '10/side',
            primaryTarget: TargetedBodyPart.Leg,
          ),
        ],
      ),
      const _QuickPartTemplate(
        title: 'Core + Stability',
        subtitle: 'Timed core control circuit',
        icon: Icons.self_improvement_outlined,
        setType: SetType.Tri,
        targetedBodyPart: TargetedBodyPart.Abs,
        exercises: [
          Exercise(
            name: 'Front Plank',
            weight: 0,
            sets: 3,
            reps: '45',
            workoutType: WorkoutType.Timed,
            primaryTarget: TargetedBodyPart.Abs,
          ),
          Exercise(
            name: 'Dead Bug',
            weight: 0,
            sets: 3,
            reps: '40',
            workoutType: WorkoutType.Timed,
            primaryTarget: TargetedBodyPart.Abs,
          ),
          Exercise(
            name: 'Hollow Body Hold',
            weight: 0,
            sets: 3,
            reps: '30',
            workoutType: WorkoutType.Timed,
            primaryTarget: TargetedBodyPart.Abs,
          ),
        ],
      ),
      const _QuickPartTemplate(
        title: 'Conditioning Finisher',
        subtitle: 'Heart-rate spike with minimal setup',
        icon: Icons.local_fire_department_outlined,
        setType: SetType.Giant,
        targetedBodyPart: TargetedBodyPart.FullBody,
        exercises: [
          Exercise(
            name: 'Bike Sprint',
            weight: 0,
            sets: 4,
            reps: '45',
            workoutType: WorkoutType.Cardio,
            primaryTarget: TargetedBodyPart.FullBody,
          ),
          Exercise(
            name: 'Kettlebell Swing',
            weight: 16,
            sets: 4,
            reps: '20',
            workoutType: WorkoutType.Cardio,
            primaryTarget: TargetedBodyPart.FullBody,
          ),
          Exercise(
            name: 'Burpee',
            weight: 0,
            sets: 4,
            reps: '12',
            workoutType: WorkoutType.Cardio,
            primaryTarget: TargetedBodyPart.FullBody,
          ),
          Exercise(
            name: 'Mountain Climber',
            weight: 0,
            sets: 4,
            reps: '40',
            workoutType: WorkoutType.Cardio,
            primaryTarget: TargetedBodyPart.FullBody,
          ),
        ],
      ),
    ];
  }

  List<_RoutineBlueprint> get _routineBlueprints {
    final templates = _quickPartTemplates;
    final mainLift = templates.first;
    final push = templates[1];
    final pull = templates[2];
    final legs = templates[3];
    final core = templates[4];
    final finisher = templates[5];
    return [
      _RoutineBlueprint(
        title: 'Power Push-Pull',
        subtitle: 'Strength-first split with balanced upper volume',
        icon: Icons.flash_on_rounded,
        colors: const [Color(0xFF2DD4BF), Color(0xFF2563EB)],
        partTemplates: [mainLift, push, pull],
        suggestedWeekdays: const [1, 3, 5],
      ),
      _RoutineBlueprint(
        title: 'Athletic Full Body',
        subtitle: 'Move fast, lift heavy, finish strong',
        icon: Icons.sports_mma_rounded,
        colors: const [Color(0xFFF97316), Color(0xFFEF4444)],
        partTemplates: [mainLift, legs, core, finisher],
        suggestedWeekdays: const [1, 3, 6],
      ),
      _RoutineBlueprint(
        title: 'Lean Hybrid',
        subtitle: 'Hypertrophy + conditioning for body recomposition',
        icon: Icons.auto_graph_rounded,
        colors: const [Color(0xFF14B8A6), Color(0xFF06B6D4)],
        partTemplates: [push, pull, core, finisher],
        suggestedWeekdays: const [2, 4, 6],
      ),
      _RoutineBlueprint(
        title: 'Legs + Core Priority',
        subtitle: 'Lower body progression with resilient trunk work',
        icon: Icons.directions_run_rounded,
        colors: const [Color(0xFF8B5CF6), Color(0xFF6366F1)],
        partTemplates: [legs, core, mainLift],
        suggestedWeekdays: const [1, 4, 6],
      ),
    ];
  }

  Future<void> _onBlueprintTap(_RoutineBlueprint blueprint) async {
    bool replace = true;
    if (_routineEditState.parts.isNotEmpty) {
      final action = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Apply "${blueprint.title}"',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => Navigator.pop(sheetContext, 'replace'),
                    child: const Text('Replace current parts'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(sheetContext, 'append'),
                    child: const Text('Append to current parts'),
                  ),
                ],
              ),
            ),
          );
        },
      );
      if (!mounted || action == null) return;
      replace = action == 'replace';
    }
    _applyBlueprint(blueprint, replace: replace);
  }

  void _applyBlueprint(_RoutineBlueprint blueprint, {required bool replace}) {
    final generatedParts =
        blueprint.partTemplates.map((template) => template.toPart()).toList();
    final nextParts =
        replace
            ? generatedParts
            : [..._routineEditState.parts, ...generatedParts];
    final nextWeekdays =
        _routineEditState.weekdays.isEmpty
            ? List<int>.from(blueprint.suggestedWeekdays)
            : _routineEditState.weekdays;

    setState(() {
      _routineEditState = _routineEditState.copyWith(
        parts: nextParts,
        weekdays: nextWeekdays,
      );
      _selectedWeekdaysBool = List.generate(
        7,
        (index) => nextWeekdays.contains(index + 1),
      );
      if (_nameEditingController.text.trim().isEmpty) {
        _nameEditingController.text = blueprint.title;
      }
      _isDirty = true;
    });

    _showSnackBar(
      replace
          ? '${blueprint.title} applied'
          : '${blueprint.title} parts added to routine',
    );
    _scrollToEnd();
  }

  Future<Part?> _showAddPartTemplateSheet() {
    final templates = _quickPartTemplates;
    final blankPart = Part(
      setType: SetType.Regular,
      targetedBodyPart: _defaultTargetForRoutine(),
      exercises: [],
    );
    return showModalBottomSheet<Part>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add New Part',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'Pick a quick template or start from scratch.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: () => Navigator.pop(sheetContext, blankPart),
                  icon: const Icon(Icons.edit_note_rounded),
                  label: const Text('Start Blank Part'),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 320,
                  child: ListView.separated(
                    itemCount: templates.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final template = templates[index];
                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        tileColor:
                            Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                        leading: Icon(template.icon),
                        title: Text(template.title),
                        subtitle: Text(template.subtitle),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap:
                            () =>
                                Navigator.pop(sheetContext, template.toPart()),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _onAddPartPressed() async {
    final newPart = await _showAddPartTemplateSheet();
    if (newPart == null) return;
    if (!mounted) return;

    try {
      final Part? editedPart = await Navigator.push<Part?>(
        context,
        MaterialPageRoute(
          builder:
              (context) =>
                  PartEditPage(addOrEdit: AddOrEdit.add, part: newPart),
        ),
      );

      if (editedPart != null && mounted) {
        setState(() {
          _routineEditState = _routineEditState.copyWith(
            parts: [..._routineEditState.parts, editedPart],
          );
          _isDirty = true;
        });
        _scrollToEnd();
      }
    } catch (e) {
      debugPrint("Error during part addition: $e");
      if (mounted) {
        _showSnackBar("Failed to add part. Please try again.");
      }
    }
  }

  void _onEditPart(Part partToEdit, int partIndex) async {
    if (partIndex < 0 || partIndex >= _routineEditState.parts.length) return;

    try {
      final Part partCopyForEditing = Part.deepCopy(partToEdit);

      final Part? editedPart = await Navigator.push<Part?>(
        context,
        MaterialPageRoute(
          builder:
              (context) => PartEditPage(
                addOrEdit: AddOrEdit.edit,
                part: partCopyForEditing,
              ),
        ),
      );

      if (editedPart != null && mounted) {
        setState(() {
          final updatedParts = List<Part>.from(_routineEditState.parts);
          updatedParts[partIndex] = editedPart;
          _routineEditState = _routineEditState.copyWith(parts: updatedParts);
          _isDirty = true;
        });
      }
    } catch (e) {
      debugPrint("Error during part editing: $e");
      if (mounted) {
        _showSnackBar("Failed to edit part. Please try again.");
      }
    }
  }

  void _onDonePressed() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      _showSnackBar("Please enter a routine title.");
      return;
    }

    final finalRoutineName =
        _nameEditingController.text.trim().isEmpty
            ? '${mainTargetedBodyPartToStringConverter(_routineEditState.mainTargetedBodyPart)} Workout'
            : _nameEditingController.text.trim();

    Routine finalRoutineToSave = _routineEditState.copyWith(
      routineName: finalRoutineName,
    );

    // Schedule notifications for selected weekdays
    _scheduleRoutineNotifications(finalRoutineToSave);

    if (finalRoutineToSave.parts.isEmpty) {
      _showSnackBar('Please add at least one exercise part.');
      return;
    }

    for (final part in finalRoutineToSave.parts) {
      if (!Part.validateExercises(part)) {
        _showSnackBar('Please complete exercise details in all parts.');
        return;
      }
    }

    final routinesBlocInstance = context.read<RoutinesBloc>();

    try {
      if (widget.addOrEdit == AddOrEdit.add) {
        routinesBlocInstance.addRoutine(finalRoutineToSave);
      } else {
        if (finalRoutineToSave.id != null) {
          routinesBlocInstance.updateRoutine(finalRoutineToSave);
        } else {
          debugPrint("Error: Editing routine with null ID. Saving as new.");
          _showSnackBar("Error: Missing ID. Saved as new routine.");
          routinesBlocInstance.addRoutine(
            finalRoutineToSave.copyWith(id: null),
          );
        }
      }
      _isDirty = false;
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint("Error saving routine via BLoC: $e");
      _showSnackBar("Failed to save routine: ${e.toString()}");
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;
    if (oldIndex < newIndex) newIndex -= 1;

    setState(() {
      final updatedParts = List<Part>.from(_routineEditState.parts);
      final part = updatedParts.removeAt(oldIndex);
      updatedParts.insert(newIndex, part);
      _routineEditState = _routineEditState.copyWith(parts: updatedParts);
      _isDirty = true;
    });
    _showSnackBar("Parts reordered.");
  }

  void _onDeletePart(Part partToDelete) {
    setState(() {
      _routineEditState = _routineEditState.copyWith(
        parts: _routineEditState.parts.where((p) => p != partToDelete).toList(),
      );
      _isDirty = true;
    });
    _showSnackBar("Part deleted.");
  }

  void _onWeekdaySelected(int dayIndex) {
    setState(() {
      _selectedWeekdaysBool[dayIndex] = !_selectedWeekdaysBool[dayIndex];
      final List<int> updatedWeekdays = [];
      for (int i = 0; i < _selectedWeekdaysBool.length; i++) {
        if (_selectedWeekdaysBool[i]) {
          updatedWeekdays.add(i + 1);
        }
      }
      _routineEditState = _routineEditState.copyWith(weekdays: updatedWeekdays);
      _isDirty = true;
    });
  }

  Future<bool> _onWillPop() async {
    if (!_isDirty) return true;

    final shouldPop = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Discard changes?'),
            content: const Text('Your edits will not be saved.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text(
                  'Discard',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
    return shouldPop ?? false;
  }

  void _showDeleteDialog() {
    final routinesBlocInstance = context.read<RoutinesBloc>();
    final routineIdToDelete =
        (widget.addOrEdit == AddOrEdit.edit) ? _routineEditState.id : null;
    if (routineIdToDelete == null) {
      _showSnackBar("Cannot delete unsaved routine.");
      return;
    }

    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Delete Routine?'),
            content: Text(
              'Permanently delete "${_routineEditState.routineName}"?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                onPressed: () {
                  Navigator.pop(dialogContext);
                  try {
                    routinesBlocInstance.deleteRoutine(routineIdToDelete);
                    _showSnackBar("Routine deleted.");
                    if (Navigator.canPop(context)) Navigator.pop(context);
                  } catch (e) {
                    _showSnackBar("Failed to delete routine: ${e.toString()}");
                  }
                },
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await _onWillPop() && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: Text(
            widget.addOrEdit == AddOrEdit.add
                ? 'Create Routine'
                : 'Edit Routine',
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back',
            onPressed: () async {
              if (await _onWillPop()) {
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
          actions: [
            if (widget.addOrEdit == AddOrEdit.edit &&
                _routineEditState.id != null)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete Routine',
                onPressed: _showDeleteDialog,
              ),
            IconButton(
              icon: const Icon(Icons.check),
              tooltip: 'Save Routine',
              onPressed: _onDonePressed,
            ),
          ],
        ),
        body: ListView(
          controller: _scrollController,
          padding: EdgeInsets.zero,
          children: [
            _buildHeroHeader(),
            if (widget.addOrEdit == AddOrEdit.add) _buildBlueprintReel(),
            _buildRoutineNameCard(),
            _buildWeekdaySelectorCard(),
            // Reorderable parts list (non-scrollable; outer ListView scrolls)
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: true,
              onReorder: _onReorder,
              padding: const EdgeInsets.only(bottom: 96),
              itemCount: _routineEditState.parts.length,
              itemBuilder: (context, index) {
                final part = _routineEditState.parts[index];
                return Container(
                  key: ObjectKey(part),
                  child: PartEditCard(
                    part: part,
                    curRoutine: _routineEditState,
                    onDelete: () => _onDeletePart(part),
                    onEdit: () => _onEditPart(part, index),
                  ),
                );
              },
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          icon: const Icon(Icons.add),
          label: const Text('ADD PART+'),
          onPressed: _onAddPartPressed,
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).dividerColor.withOpacity(0.5),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      if (await _onWillPop()) {
                        if (context.mounted) Navigator.maybePop(context);
                      }
                    },
                    icon: const Icon(Icons.close),
                    label: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _onDonePressed,
                    icon: const Icon(Icons.check),
                    label: const Text('Save Routine'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildPartEditCards() {
    if (_routineEditState.parts.isEmpty) {
      return [
        Container(
          key: const ValueKey('empty_list_placeholder'),
          padding: const EdgeInsets.all(16.0),
          alignment: Alignment.center,
          child: Text(
            'No exercise parts added yet.\nTap the ADD PART button to begin.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ];
    }
    return List.generate(_routineEditState.parts.length, (index) {
      final part = _routineEditState.parts[index];
      return PartEditCard(
        key: ObjectKey(part),
        part: part,
        curRoutine: _routineEditState,
        onDelete: () => _onDeletePart(part),
        onEdit: () => _onEditPart(part, index),
      );
    });
  }

  Widget _buildBlueprintReel() {
    final blueprints = _routineBlueprints;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Card(
        elevation: 0,
        color: cs.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Routine Blueprints',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                'Swipe, preview, and inject a complete routine style in one tap.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 162,
                child: PageView.builder(
                  controller: _blueprintPageController,
                  itemCount: blueprints.length,
                  onPageChanged: (value) {
                    setState(() {
                      _activeBlueprintPage = value;
                    });
                  },
                  itemBuilder: (context, index) {
                    final blueprint = blueprints[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: blueprint.colors,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(blueprint.icon, color: Colors.white),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      blueprint.title,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                blueprint.subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.92),
                                ),
                              ),
                              const Spacer(),
                              Align(
                                alignment: Alignment.bottomRight,
                                child: FilledButton(
                                  onPressed: () => _onBlueprintTap(blueprint),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.black87,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                  child: const Text('Apply'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(blueprints.length, (index) {
                  final selected = index == _activeBlueprintPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: selected ? 18 : 7,
                    height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: selected ? cs.primary : cs.outlineVariant,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoutineNameCard() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Card(
        elevation: 0,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Form(
            key: _formKey,
            child: TextFormField(
              controller: _nameEditingController,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.edit_rounded),
                labelText: 'Routine Title *',
                hintText: 'e.g., Push Day',
                border: InputBorder.none,
                isDense: true,
                labelStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                hintStyle: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withOpacity(0.7),
                ),
              ),
              validator:
                  (value) =>
                      (value == null || value.trim().isEmpty)
                          ? 'Please enter a routine title'
                          : null,
              textInputAction: TextInputAction.done,
              onChanged: (_) => _markDirtyOnNameChange(),
            ),
          ),
        ),
      ),
    );
  }

  /// Schedules notifications for the routine based on selected weekdays
  void _scheduleRoutineNotifications(Routine routine) async {
    final notificationService = NotificationService();

    // Cancel any existing notifications for this routine
    if (routine.id != null) {
      await notificationService.cancelNotification(routine.id!);
    }

    // If no weekdays are selected, don't schedule any notifications
    if (routine.weekdays.isEmpty) {
      return;
    }

    // Get current time
    final now = DateTime.now();

    // Weekly recurring notifications at 9:00 for selected weekdays
    for (int weekday in routine.weekdays) {
      try {
        await notificationService.scheduleWeeklyNotification(
          id: (routine.id ?? 0) * 10 + weekday,
          title: 'Workout Reminder',
          body: 'Time for your ${routine.routineName} workout!',
          weekday: weekday,
          hour: 9,
          minute: 0,
        );
        debugPrint(
          'Scheduled weekly notification for ${routine.routineName} on weekday $weekday',
        );
      } catch (e) {
        debugPrint('Failed to schedule weekly notification: $e');
      }
    }
  }

  Widget _buildWeekdaySelectorCard() {
    final List<String> dayAbbreviations = [
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Card(
        elevation: 0,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Schedule (Optional)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: List.generate(7, (index) {
                  final bool isSelected = _selectedWeekdaysBool[index];
                  return ChoiceChip(
                    label: Text(dayAbbreviations[index]),
                    selected: isSelected,
                    onSelected: (bool selected) {
                      _onWeekdaySelected(index);
                    },
                    selectedColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    labelStyle: TextStyle(
                      color:
                          isSelected
                              ? Theme.of(context).colorScheme.onPrimaryContainer
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    backgroundColor:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color:
                            isSelected
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Theme.of(
                                  context,
                                ).colorScheme.outline.withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    showCheckmark: false,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroHeader() {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              cs.primaryContainer.withOpacity(0.9),
              cs.secondaryContainer.withOpacity(0.9),
            ],
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.view_agenda_rounded,
              color: cs.onPrimaryContainer,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Build Your Routine',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Swipe blueprints, set your schedule, then add custom parts. Reorder anytime.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onPrimaryContainer.withOpacity(0.95),
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
