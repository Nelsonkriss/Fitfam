import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:keyboard_actions/keyboard_actions.dart';

// Import Models, Utils
import 'package:workout_planner/models/routine.dart';
import 'package:workout_planner/models/part.dart';
import 'package:workout_planner/utils/routine_helpers.dart';
import 'package:workout_planner/ui/components/exercise_search_dialog.dart';
import 'package:workout_planner/models/exercise_animation_data.dart';
import 'package:workout_planner/services/ai_weight_recommendation_service.dart';
import 'package:workout_planner/models/user_profile.dart';
import 'package:workout_planner/resource/shared_prefs_provider.dart';

// --- Helper Classes ---
class StringHelper {
  static String weightToString(double weight) {
    if (weight <= 0) return "0";
    if (weight == weight.truncateToDouble()) {
      return weight.toStringAsFixed(0);
    } else {
      return weight.toStringAsFixed(1);
    }
  }
}

// Helper class for enum conversion
class PartEditPageHelper {
  static SetType radioValueToSetTypeConverter(int radioValue) {
    switch (radioValue) {
      case 0: return SetType.Regular;
      case 1: return SetType.Drop;
      case 2: return SetType.Super;
      case 3: return SetType.Tri;
      case 4: return SetType.Giant;
      default:
        debugPrint("Error: Invalid radio value $radioValue for SetType");
        return SetType.Regular;
    }
  }

  static TargetedBodyPart radioValueToTargetedBodyPartConverter(int radioValue) {
    switch (radioValue) {
      case 0: return TargetedBodyPart.Abs;
      case 1: return TargetedBodyPart.Arm;
      case 2: return TargetedBodyPart.Back;
      case 3: return TargetedBodyPart.Chest;
      case 4: return TargetedBodyPart.Leg;
      case 5: return TargetedBodyPart.Shoulder;
      case 6: return TargetedBodyPart.Bicep;
      case 7: return TargetedBodyPart.Tricep;
      case 8: return TargetedBodyPart.FullBody;
      default:
        debugPrint("Error: Invalid radio value $radioValue for TargetedBodyPart");
        return TargetedBodyPart.Chest;
    }
  }

  static int targetedBodyPartToRadioValue(TargetedBodyPart bodyPart) {
    switch (bodyPart) {
      case TargetedBodyPart.Abs: return 0;
      case TargetedBodyPart.Arm: return 1;
      case TargetedBodyPart.Back: return 2;
      case TargetedBodyPart.Chest: return 3;
      case TargetedBodyPart.Leg: return 4;
      case TargetedBodyPart.Shoulder: return 5;
      case TargetedBodyPart.Bicep: return 6;
      case TargetedBodyPart.Tricep: return 7;
      case TargetedBodyPart.FullBody: return 8;
      default: return 3; // Default to Chest
    }
  }

  static int setTypeToRadioValue(SetType setType) {
    switch (setType) {
      case SetType.Regular: return 0;
      case SetType.Drop: return 1;
      case SetType.Super: return 2;
      case SetType.Tri: return 3;
      case SetType.Giant: return 4;
      default: return 0; // Default to Regular
    }
  }
}

class _ExerciseEditState {
  final String uid;
  final TextEditingController nameController;
  final TextEditingController weightController;
  final TextEditingController setsController;
  final TextEditingController repsController;
  WorkoutType workoutType;
  TargetedBodyPart primaryTarget;
  List<TargetedBodyPart> secondaryTargets;

  _ExerciseEditState({
    String? uid,
    required String name,
    required double weight,
    required int sets,
    required String reps,
    required this.workoutType,
    required this.primaryTarget,
    List<TargetedBodyPart>? secondaryTargets,
  }) : uid = uid ?? UniqueKey().toString(),
       nameController = TextEditingController(text: name),
       weightController = TextEditingController(text: StringHelper.weightToString(weight)),
       setsController = TextEditingController(text: sets > 0 ? sets.toString() : ''),
       repsController = TextEditingController(text: reps),
       secondaryTargets = secondaryTargets ?? <TargetedBodyPart>[];

  factory _ExerciseEditState.fromExercise(Exercise ex) {
    return _ExerciseEditState(
      name: ex.name,
      weight: ex.weight,
      sets: ex.sets,
      reps: ex.reps,
      workoutType: ex.workoutType,
      primaryTarget: ex.primaryTarget ?? TargetedBodyPart.FullBody,
      secondaryTargets: List<TargetedBodyPart>.from(ex.secondaryTargets),
    );
  }

  factory _ExerciseEditState.empty({TargetedBodyPart defaultTarget = TargetedBodyPart.FullBody}) {
    return _ExerciseEditState(
      name: '',
      weight: 0,
      sets: 3,
      reps: '10',
      workoutType: WorkoutType.Weight,
      primaryTarget: defaultTarget,
      secondaryTargets: const [],
    );
  }

  Exercise toExercise() {
    return Exercise(
      name: nameController.text.trim(),
      weight: double.tryParse(weightController.text) ?? 0.0,
      sets: int.tryParse(setsController.text) ?? 0,
      reps: repsController.text.trim(),
      workoutType: workoutType,
      exHistory: {},
      primaryTarget: primaryTarget,
      secondaryTargets: secondaryTargets,
    );
  }

  void dispose() {
    nameController.dispose();
    weightController.dispose();
    setsController.dispose();
    repsController.dispose();
  }
}

class PartEditPage extends StatefulWidget {
  final Part originalPart;
  final AddOrEdit addOrEdit;

  const PartEditPage({
    super.key,
    required this.addOrEdit,
    required Part part,
  }) : originalPart = part;

  @override
  State<PartEditPage> createState() => _PartEditPageState();
}

class _PartEditPageState extends State<PartEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _additionalNotesController = TextEditingController();

  late TargetedBodyPart _selectedTargetedBodyPart;
  late SetType _selectedSetType;
  late List<_ExerciseEditState> _exerciseEditStates;

  final List<FocusNode> _focusNodes = [];
  // Personalization
  String _weightUnit = 'kg';
  double _weightIncrement = 2.5;

  @override
  void initState() {
    super.initState();
    _initializeState();
  }

  void _initializeState() {
    final initialPart = widget.originalPart;
    _selectedTargetedBodyPart = initialPart.targetedBodyPart;
    _selectedSetType = initialPart.setType;
    _additionalNotesController.text = initialPart.additionalNotes;

    _exerciseEditStates = [];
    // Prefer showing all existing exercises from the part (AI may return
    // multiple exercises even when setType is Regular). Fit setType if needed.
    final int originalCount = initialPart.exercises.length;
    final int setTypeCount = setTypeToExerciseCountConverter(_selectedSetType);
    int exerciseCount = originalCount > 0 ? originalCount : setTypeCount;
    // If there are more exercises than the selected set type typically allows,
    // auto-fit the visible set type so the UI matches what the user sees.
    if (originalCount > setTypeCount) {
      if (originalCount >= 4) {
        _selectedSetType = SetType.Giant;
      } else if (originalCount == 3) {
        _selectedSetType = SetType.Tri;
      } else if (originalCount == 2) {
        _selectedSetType = SetType.Super;
      } else {
        _selectedSetType = SetType.Regular;
      }
    }

    for (int i = 0; i < exerciseCount; i++) {
      if (i < initialPart.exercises.length) {
        _exerciseEditStates.add(_ExerciseEditState.fromExercise(initialPart.exercises[i]));
      } else {
        _exerciseEditStates.add(_ExerciseEditState.empty(defaultTarget: _selectedTargetedBodyPart));
      }
    }

    _focusNodes.clear();
    // Create focus nodes sized to number of exercises (4 fields per exercise)
    for (int i = 0; i < 4 * exerciseCount; i++) {
      _focusNodes.add(FocusNode());
    }
    // Load personalization
    _loadPersonalization();
  }

  Future<void> _loadPersonalization() async {
    try {
      final unit = await sharedPrefsProvider.getWeightUnit();
      final inc = await sharedPrefsProvider.getWeightIncrement();
      if (mounted) {
        setState(() {
          _weightUnit = unit; _weightIncrement = inc;
          if (_weightUnit == 'lb') {
            for (final s in _exerciseEditStates) {
              final kg = double.tryParse(s.weightController.text) ?? 0.0;
              final lb = kg * 2.20462;
              s.weightController.text = StringHelper.weightToString(lb);
            }
          }
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _additionalNotesController.dispose();
    for (var exState in _exerciseEditStates) {
      exState.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _updateExercisesForSetType(SetType newSetType) {
    final currentExerciseData = _exerciseEditStates.map((e) => e.toExercise()).toList();
    final newExerciseCount = setTypeToExerciseCountConverter(newSetType);
    final List<_ExerciseEditState> newStates = [];

    for (int i = 0; i < newExerciseCount; i++) {
      if (i < _exerciseEditStates.length) {
        newStates.add(_exerciseEditStates[i]);
      } else if (i < currentExerciseData.length) {
        newStates.add(_ExerciseEditState.fromExercise(currentExerciseData[i]));
      } else {
        newStates.add(_ExerciseEditState.empty());
      }
    }

    // Dispose of any extra controllers
    for (int i = newExerciseCount; i < _exerciseEditStates.length; i++) {
      _exerciseEditStates[i].dispose();
    }

    setState(() {
      _selectedSetType = newSetType;
      _exerciseEditStates = newStates;
    });
  }

  void _adjustSetTypeByCount() {
    final count = _exerciseEditStates.length;
    SetType newType;
    if (count <= 1) newType = SetType.Regular;
    else if (count == 2) newType = SetType.Super;
    else if (count == 3) newType = SetType.Tri;
    else newType = SetType.Giant;
    if (newType != _selectedSetType) {
      setState(() { _selectedSetType = newType; });
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  void _onDone() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      _showSnackBar("Please fill in required exercise details.");
      return;
    }

    // Convert display unit to kg for storage
    double toKg(double v) => _weightUnit == 'lb' ? (v / 2.20462) : v;
    final List<Exercise> finalExercises = _exerciseEditStates.map((editState) {
      final ex = editState.toExercise();
      return ex.copyWith(weight: toKg(ex.weight));
    }).toList();
    if (finalExercises.isEmpty) {
      _showSnackBar("Please add at least one exercise.");
      return;
    }

    final Part resultingPart = widget.originalPart.copyWith(
      targetedBodyPart: _selectedTargetedBodyPart,
      setType: _selectedSetType,
      exercises: finalExercises,
      additionalNotes: _additionalNotesController.text.trim(),
      partName: widget.originalPart.partName,
      defaultName: widget.originalPart.defaultName,
    );

    Navigator.pop(context, resultingPart);
  }

  Future<bool> _onWillPop() async {
    // Check for changes in a more reliable way
    bool hasChanges = false;

    // Check basic properties
    if (_selectedTargetedBodyPart != widget.originalPart.targetedBodyPart ||
        _selectedSetType != widget.originalPart.setType ||
        _additionalNotesController.text != widget.originalPart.additionalNotes ||
        _exerciseEditStates.length != widget.originalPart.exercises.length) {
      hasChanges = true;
    } else {
      // Check exercises only if basic properties haven't changed
      for (int i = 0; i < _exerciseEditStates.length; i++) {
        if (i >= widget.originalPart.exercises.length) {
          hasChanges = true;
          break;
        }

        final stateEx = _exerciseEditStates[i];
        final originalEx = widget.originalPart.exercises[i];

        // Compare exercise properties
        if (stateEx.nameController.text != originalEx.name ||
            (double.tryParse(stateEx.weightController.text) ?? 0.0) != originalEx.weight ||
            (int.tryParse(stateEx.setsController.text) ?? 0) != originalEx.sets ||
            stateEx.repsController.text != originalEx.reps ||
            stateEx.workoutType != originalEx.workoutType) {
          hasChanges = true;
          break;
        }
      }
    }

    // If no changes, allow immediate pop
    if (!hasChanges) {
      return true;
    }

    // If there are changes, show confirmation dialog
    final bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Discard Changes?'),
        content: const Text('You have unsaved changes. Are you sure you want to discard them?'),
        actions: <Widget>[
          TextButton(
            child: const Text('Keep Editing'),
            onPressed: () => Navigator.pop(dialogContext, false),
          ),
          TextButton(
            child: Text(
              'Discard',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: Text(widget.addOrEdit == AddOrEdit.add ? "Add Part" : "Edit Part"),
          actions: <Widget>[
            IconButton(
              icon: const Icon(Icons.check),
              tooltip: "Save Part",
              onPressed: _onDone,
            )
          ],
        ),
        body: KeyboardActions(
          config: _buildKeyboardActionsConfig(),
          autoScroll: true,
          child: ListView(
            padding: const EdgeInsets.all(8.0),
            children: [
              _buildSectionCard(
                title: 'Targeted Muscle Group',
                icon: Icons.ads_click_rounded,
                child: _buildTargetedBodyPartRadioList(),
              ),
              _buildSectionCard(
                title: 'Set Type',
                icon: Icons.repeat_rounded,
                child: _buildSetTypeSegmentedControl(),
              ),
              Form(
                key: _formKey,
                child: _buildSectionCard(
                  title: 'Exercise Details',
                  icon: Icons.fitness_center_rounded,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSetDetailsList(),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _exerciseEditStates.add(_ExerciseEditState.empty(defaultTarget: _selectedTargetedBodyPart));
                            for (int i = 0; i < 4; i++) { _focusNodes.add(FocusNode()); }
                            _adjustSetTypeByCount();
                          });
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add Exercise'),
                      ),
                    ],
                  ),
                ),
              ),
              _buildSectionCard(
                title: 'Additional Notes (Optional)',
                icon: Icons.notes_rounded,
                initiallyExpanded: _additionalNotesController.text.isNotEmpty,
                child: _buildAdditionalNotesField(),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(top: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.5))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(Icons.close),
                    label: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _onDone,
                    icon: const Icon(Icons.check),
                    label: const Text('Save Part'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
    bool initiallyExpanded = true,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 0,
      color: cs.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          leading: CircleAvatar(
            radius: 16,
            backgroundColor: cs.primaryContainer,
            child: Icon(icon, color: cs.onPrimaryContainer, size: 18),
          ),
          title: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          initiallyExpanded: initiallyExpanded,
          childrenPadding: const EdgeInsets.all(16.0).copyWith(top: 0),
          tilePadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          iconColor: Theme.of(context).colorScheme.onSurfaceVariant,
          collapsedIconColor: Theme.of(context).colorScheme.onSurfaceVariant,
          children: [child],
        ),
      ),
    );
  }

  Widget _buildTargetedBodyPartRadioList() {
    // Modernized as chips for compact, touch-friendly selection
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: TargetedBodyPart.values.map((bodyPart) {
        final selected = _selectedTargetedBodyPart == bodyPart;
        return ChoiceChip(
          label: Text(targetedBodyPartToStringConverter(bodyPart)),
          selected: selected,
          onSelected: (_) => setState(() => _selectedTargetedBodyPart = bodyPart),
          selectedColor: Theme.of(context).colorScheme.primaryContainer,
          showCheckmark: false,
        );
      }).toList(),
    );
  }

  Widget _buildSetTypeSegmentedControl() {
    final theme = Theme.of(context);
    final selectedTextStyle = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.bold,
      color: theme.colorScheme.onPrimaryContainer,
    );
    final unselectedTextStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    final Map<SetType, Widget> children = {
      for (var type in SetType.values)
        type: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
          child: Text(
            setTypeToStringConverter(type).split(' ').first,
            style: _selectedSetType == type ? selectedTextStyle : unselectedTextStyle,
          ),
        )
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: SizedBox(
        width: double.infinity,
        child: CupertinoSlidingSegmentedControl<SetType>(
          children: children,
          groupValue: _selectedSetType,
          thumbColor: theme.colorScheme.primaryContainer,
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          onValueChanged: (newSetType) {
            if (newSetType != null && newSetType != _selectedSetType) {
              _updateExercisesForSetType(newSetType);
            }
          },
        ),
      ),
    );
  }

  Widget _buildSetDetailsList() {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: _exerciseEditStates.length,
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (newIndex > oldIndex) newIndex -= 1;
          final item = _exerciseEditStates.removeAt(oldIndex);
          _exerciseEditStates.insert(newIndex, item);
        });
      },
      itemBuilder: (context, index) {
        final state = _exerciseEditStates[index];
        return Container(
          key: ValueKey(state.uid),
          child: _buildSingleExerciseEditor(index, showDragHandle: true),
        );
      },
    );
  }

  Widget _buildSingleExerciseEditor(int index, {bool showDragHandle = false}) {
    if (index >= _exerciseEditStates.length) return const SizedBox.shrink();

    final exerciseState = _exerciseEditStates[index];
    int focusNodeBaseIndex = index * 4;

    FocusNode? getNode(int offset) {
      int nodeIndex = focusNodeBaseIndex + offset;
      return nodeIndex < _focusNodes.length ? _focusNodes[nodeIndex] : null;
    }

    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Card(
        elevation: 0,
        color: colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: colorScheme.surfaceContainerHighest),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'Exercise ${index + 1}',
                  style: textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Remove',
                onPressed: () {
                  setState(() {
                    if (_exerciseEditStates.length > 1) {
                      _exerciseEditStates.removeAt(index);
                      _focusNodes.clear();
                      for (int i = 0; i < 4 * _exerciseEditStates.length; i++) { _focusNodes.add(FocusNode()); }
                      _adjustSetTypeByCount();
                    }
                  });
                },
              ),
              const SizedBox(width: 8),
              Flexible(
                fit: FlexFit.loose,
                child: SegmentedButton<WorkoutType>(
                  segments: [
                    ButtonSegment<WorkoutType>(
                      value: WorkoutType.Weight,
                      label: Text('W', style: textTheme.labelSmall),
                      icon: const Icon(Icons.fitness_center, size: 16),
                      tooltip: 'Weight',
                    ),
                    ButtonSegment<WorkoutType>(
                      value: WorkoutType.Timed,
                      label: Text('T', style: textTheme.labelSmall),
                      icon: const Icon(Icons.timer, size: 16),
                      tooltip: 'Timed',
                    ),
                    ButtonSegment<WorkoutType>(
                      value: WorkoutType.Cardio,
                      label: Text('C', style: textTheme.labelSmall),
                      icon: const Icon(Icons.directions_run, size: 16),
                      tooltip: 'Cardio',
                    ),
                  ],
                  selected: {exerciseState.workoutType},
                  onSelectionChanged: (Set<WorkoutType> selected) {
                    if (selected.isNotEmpty) {
                      setState(() {
                        exerciseState.workoutType = selected.first;
                      });
                    }
                  },
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: WidgetStateProperty.all(EdgeInsets.zero),
                  ),
                ),
              ),
              if (showDragHandle) ...[
                const SizedBox(width: 8),
                ReorderableDragStartListener(
                  index: index,
                  child: IconButton(
                    icon: const Icon(Icons.drag_indicator),
                    tooltip: 'Reorder',
                    onPressed: null,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: exerciseState.nameController,
                  focusNode: getNode(0),
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Exercise Name *',
                    isDense: true,
                    prefixIcon: const Icon(Icons.fitness_center_outlined),
                    suffixIcon: ExerciseAnimationData.hasAnimationForExercise(exerciseState.nameController.text)
                        ? Icon(
                            Icons.play_circle_outline,
                            color: Theme.of(context).colorScheme.primary,
                            size: 20,
                          )
                        : null,
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty) ? 'Name required' : null,
                  textInputAction: TextInputAction.next,
                  onChanged: (value) {
                    // Auto-recommend weight when exercise name changes
                    _autoRecommendWeight(index);
                    // Trigger rebuild to show/hide animation icon
                    setState(() {});
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _showExerciseSearchDialog(index),
                icon: const Icon(Icons.search),
                tooltip: 'Search Exercise Library',
                style: IconButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (exerciseState.workoutType == WorkoutType.Weight)
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: exerciseState.weightController,
                        focusNode: getNode(1),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Wt (' + _weightUnit + ')',
                          isDense: true,
                          suffixIconConstraints: const BoxConstraints.tightFor(width: 96, height: 40),
                          suffixIcon: SizedBox(
                            width: 96,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove, size: 18),
                                  visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                                  tooltip: 'Decrement',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints.tightFor(width: 28, height: 28),
                                  onPressed: () {
                                    final v = double.tryParse(exerciseState.weightController.text) ?? 0.0;
                                    final newV = (v - _weightIncrement).clamp(0.0, double.infinity);
                                    setState(() { exerciseState.weightController.text = StringHelper.weightToString(newV); });
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add, size: 18),
                                  visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                                  tooltip: 'Increment',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints.tightFor(width: 28, height: 28),
                                  onPressed: () {
                                    final v = double.tryParse(exerciseState.weightController.text) ?? 0.0;
                                    final newV = v + _weightIncrement;
                                    setState(() { exerciseState.weightController.text = StringHelper.weightToString(newV); });
                                  },
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.auto_awesome,
                                    size: 18,
                                    color: colorScheme.primary,
                                  ),
                                  visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                                  onPressed: () => _showWeightRecommendationDialog(index),
                                  tooltip: 'AI Weight Recommendation',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints.tightFor(width: 28, height: 28),
                                ),
                              ],
                            ),
                          ),
                        ),
                        validator: (value) => (value != null && value.isNotEmpty && double.tryParse(value) == null)
                            ? 'Invalid'
                            : null,
                        textInputAction: TextInputAction.next,
                      ),
                    ],
                  ),
                )
              else
                const Expanded(flex: 2, child: SizedBox()),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: TextFormField(
                  controller: exerciseState.setsController,
                  focusNode: getNode(2),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Sets *',
                    isDense: true,
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty || (int.tryParse(value.trim()) ?? 0) <= 0)
                      ? 'Invalid'
                      : null,
                  textInputAction: TextInputAction.next,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: exerciseState.repsController,
                  focusNode: getNode(3),
                  keyboardType: exerciseState.workoutType == WorkoutType.Weight
                      ? TextInputType.text
                      : TextInputType.number,
                  inputFormatters: exerciseState.workoutType == WorkoutType.Cardio
                      ? [FilteringTextInputFormatter.digitsOnly]
                      : [],
                  decoration: InputDecoration(
                    labelText: exerciseState.workoutType == WorkoutType.Weight ? 'Reps *' : 'Time (sec) *',
                    isDense: true,
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty) ? 'Required' : null,
                  textInputAction: TextInputAction.done,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: DropdownButton<TargetedBodyPart>(
              value: exerciseState.primaryTarget,
              onChanged: (bp) {
                if (bp == null) return;
                setState(() => exerciseState.primaryTarget = bp);
              },
              items: TargetedBodyPart.values.map((bp) => DropdownMenuItem(
                value: bp,
                child: Text('Target: ${bp.name}'),
              )).toList(),
            ),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: TargetedBodyPart.values.where((bp) => bp != exerciseState.primaryTarget).map((bp) {
              final selected = exerciseState.secondaryTargets.contains(bp);
              return FilterChip(
                label: Text(bp.name),
                selected: selected,
                onSelected: (v) {
                  setState(() {
                    if (v) {
                      exerciseState.secondaryTargets = [...exerciseState.secondaryTargets, bp];
                    } else {
                      exerciseState.secondaryTargets = exerciseState.secondaryTargets.where((e) => e != bp).toList();
                    }
                  });
                },
              );
            }).toList(),
          ),
          if (index < _exerciseEditStates.length - 1)
            Divider(
              height: 24,
              thickness: 0.5,
              color: theme.dividerColor,
            ),
        ],
          ),
        ),
      ),
    );
  }

  /// Auto-recommends weight when exercise name changes
  void _autoRecommendWeight(int exerciseIndex) async {
    final exerciseState = _exerciseEditStates[exerciseIndex];
    final exerciseName = exerciseState.nameController.text.trim();
    
    // Only auto-recommend if exercise name is not empty and weight is currently 0 or empty
    if (exerciseName.isNotEmpty && 
        exerciseState.workoutType == WorkoutType.Weight &&
        (exerciseState.weightController.text.isEmpty || 
         double.tryParse(exerciseState.weightController.text) == 0.0)) {
      
      try {
        debugPrint('Auto-recommending weight for exercise: $exerciseName');
        final userProfile = await _getUserProfile();
        debugPrint('User profile loaded: ${userProfile != null ? userProfile.toString() : 'null'}');
        
        final targetReps = int.tryParse(exerciseState.repsController.text) ?? 10;
        debugPrint('Target reps: $targetReps');
        
        final recommendedWeight = await AIWeightRecommendationService()
            .getRecommendedWeight(
          exerciseName: exerciseName,
          userProfile: userProfile,
          targetReps: targetReps,
        );
        
        debugPrint('Recommended weight: $recommendedWeight');
        
        if (recommendedWeight > 0 && mounted) {
          setState(() {
            final display = _weightUnit == 'lb' ? (recommendedWeight * 2.20462) : recommendedWeight;
            exerciseState.weightController.text = StringHelper.weightToString(display);
          });
          debugPrint('Weight set to: ${exerciseState.weightController.text}');
        } else {
          debugPrint('No weight recommendation applied (weight: $recommendedWeight, mounted: $mounted)');
        }
      } catch (e) {
        // Enhanced error logging for debugging
        debugPrint('Auto weight recommendation failed for $exerciseName: $e');
        debugPrint('Stack trace: ${StackTrace.current}');
      }
    } else {
      debugPrint('Auto-recommendation skipped - exerciseName: "$exerciseName", workoutType: ${exerciseState.workoutType}, currentWeight: "${exerciseState.weightController.text}"');
    }
  }

  /// Shows weight recommendation dialog with multiple rep ranges
  void _showWeightRecommendationDialog(int exerciseIndex) async {
    final exerciseState = _exerciseEditStates[exerciseIndex];
    final exerciseName = exerciseState.nameController.text.trim();
    
    if (exerciseName.isEmpty) {
      _showSnackBar('Please enter an exercise name first');
      return;
    }

    if (exerciseState.workoutType != WorkoutType.Weight) {
      _showSnackBar('Weight recommendations are only available for weight exercises');
      return;
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final userProfile = await _getUserProfile();
      final recommendations = await AIWeightRecommendationService()
          .getWeightRecommendationsForRepRanges(
        exerciseName: exerciseName,
        userProfile: userProfile,
        repRanges: [5, 8, 10, 12, 15],
      );
      
      final confidence = await AIWeightRecommendationService()
          .getRecommendationConfidence(
        exerciseName: exerciseName,
        userProfile: userProfile,
      );

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        _showWeightRecommendationBottomSheet(exerciseIndex, recommendations, confidence);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        _showSnackBar('Failed to get weight recommendations: ${e.toString()}');
      }
    }
  }

  /// Shows bottom sheet with weight recommendations
  void _showWeightRecommendationBottomSheet(
    int exerciseIndex,
    Map<int, double> recommendations,
    double confidence,
  ) {
    final exerciseState = _exerciseEditStates[exerciseIndex];
    final theme = Theme.of(context);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'AI Weight Recommendations',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'For: ${exerciseState.nameController.text}',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  confidence > 0.7 ? Icons.verified : 
                  confidence > 0.4 ? Icons.info : Icons.warning,
                  size: 16,
                  color: confidence > 0.7 ? Colors.green : 
                         confidence > 0.4 ? Colors.orange : Colors.red,
                ),
                const SizedBox(width: 4),
                Text(
                  'Confidence: ${(confidence * 100).toInt()}%',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...recommendations.entries.map((entry) {
              final reps = entry.key;
              final weight = entry.value;
              final display = _weightUnit == 'lb' ? (weight * 2.20462) : weight;
              final isCurrentReps = int.tryParse(exerciseState.repsController.text) == reps;
              
              return Card(
                color: isCurrentReps ? theme.colorScheme.primaryContainer : null,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isCurrentReps 
                        ? theme.colorScheme.primary 
                        : theme.colorScheme.surfaceContainerHighest,
                    child: Text(
                      '$reps',
                      style: TextStyle(
                        color: isCurrentReps 
                            ? theme.colorScheme.onPrimary 
                            : theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text('${StringHelper.weightToString(display)} $_weightUnit'),
                  subtitle: Text('$reps reps'),
                  trailing: isCurrentReps 
                      ? Icon(Icons.star, color: theme.colorScheme.primary)
                      : null,
                  onTap: () {
                    exerciseState.weightController.text = StringHelper.weightToString(display);
                    exerciseState.repsController.text = reps.toString();
                    Navigator.pop(context);
                    _showSnackBar('Weight recommendation applied!');
                  },
                ),
              );
            }),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Gets user profile from shared preferences
  Future<UserProfile?> _getUserProfile() async {
    try {
      final userProfile = await sharedPrefsProvider.getUserProfile();
      return userProfile;
    } catch (e) {
      debugPrint('Error loading user profile: $e');
    }
    return null;
  }

  Widget _buildAdditionalNotesField() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: _additionalNotesController,
        decoration: const InputDecoration(
          labelText: 'Notes',
          hintText: 'Add any specific instructions or tips...',
        ),
        maxLines: 3,
        textCapitalization: TextCapitalization.sentences,
      ),
    );
  }

  void _showExerciseSearchDialog(int exerciseIndex) async {
    final selectedExercise = await showExerciseSearchDialog(
      context: context,
      initialQuery: _exerciseEditStates[exerciseIndex].nameController.text,
    );
    
    if (selectedExercise != null) {
      setState(() {
        _exerciseEditStates[exerciseIndex].nameController.text = selectedExercise;
      });
    }
  }

  KeyboardActionsConfig _buildKeyboardActionsConfig() {
    final theme = Theme.of(context);
    final validFocusNodes = _focusNodes.where((node) => node != null).toList();
    return KeyboardActionsConfig(
      keyboardActionsPlatform: KeyboardActionsPlatform.ALL,
      keyboardBarColor: theme.colorScheme.surfaceContainer,
      nextFocus: true,
      actions: validFocusNodes.map((node) {
        return KeyboardActionsItem(
          focusNode: node,
          displayDoneButton: true,
        );
      }).toList(),
    );
  }
}
