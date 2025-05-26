import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:keyboard_actions/keyboard_actions.dart';

// Import Models, Utils
import 'package:workout_planner/models/routine.dart';
import 'package:workout_planner/models/part.dart';
import 'package:workout_planner/utils/routine_helpers.dart';

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
  final TextEditingController nameController;
  final TextEditingController weightController;
  final TextEditingController setsController;
  final TextEditingController repsController;
  WorkoutType workoutType;

  _ExerciseEditState({
    required String name,
    required double weight,
    required int sets,
    required String reps,
    required this.workoutType,
  }) : nameController = TextEditingController(text: name),
       weightController = TextEditingController(text: StringHelper.weightToString(weight)),
       setsController = TextEditingController(text: sets > 0 ? sets.toString() : ''),
       repsController = TextEditingController(text: reps);

  factory _ExerciseEditState.fromExercise(Exercise ex) {
    return _ExerciseEditState(
      name: ex.name,
      weight: ex.weight,
      sets: ex.sets,
      reps: ex.reps,
      workoutType: ex.workoutType,
    );
  }

  factory _ExerciseEditState.empty() {
    return _ExerciseEditState(
      name: '',
      weight: 0,
      sets: 3,
      reps: '10',
      workoutType: WorkoutType.Weight,
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
    int exerciseCount = setTypeToExerciseCountConverter(_selectedSetType);

    for (int i = 0; i < exerciseCount; i++) {
      if (i < initialPart.exercises.length) {
        _exerciseEditStates.add(_ExerciseEditState.fromExercise(initialPart.exercises[i]));
      } else {
        _exerciseEditStates.add(_ExerciseEditState.empty());
      }
    }

    _focusNodes.clear();
    for (int i = 0; i < 4 * 4; i++) {
      _focusNodes.add(FocusNode());
    }
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

    final List<Exercise> finalExercises = _exerciseEditStates.map((editState) => editState.toExercise()).toList();
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
                  child: _buildSetDetailsList(),
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
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
    bool initiallyExpanded = true,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 2,
      child: ExpansionTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.secondary),
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w500),
        ),
        initiallyExpanded: initiallyExpanded,
        childrenPadding: const EdgeInsets.all(16.0).copyWith(top: 0),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        iconColor: Theme.of(context).colorScheme.onSurfaceVariant,
        collapsedIconColor: Theme.of(context).colorScheme.onSurfaceVariant,
        children: [child],
      ),
    );
  }

  Widget _buildTargetedBodyPartRadioList() {
    int currentRadioValue = PartEditPageHelper.targetedBodyPartToRadioValue(_selectedTargetedBodyPart);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: TargetedBodyPart.values.map((bodyPart) {
        int radioValue = PartEditPageHelper.targetedBodyPartToRadioValue(bodyPart);
        return RadioListTile<int>(
          title: Text(
            targetedBodyPartToStringConverter(bodyPart),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          value: radioValue,
          groupValue: currentRadioValue,
          onChanged: (newValue) {
            if (newValue != null) {
              setState(() {
                _selectedTargetedBodyPart = PartEditPageHelper.radioValueToTargetedBodyPartConverter(newValue);
              });
            }
          },
          dense: true,
          visualDensity: VisualDensity.compact,
          activeColor: Theme.of(context).colorScheme.primary,
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(_exerciseEditStates.length, (index) {
        return _buildSingleExerciseEditor(index);
      }),
    );
  }

  Widget _buildSingleExerciseEditor(int index) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Exercise ${index + 1}', style: textTheme.titleMedium),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Weight',
                    style: textTheme.labelSmall?.copyWith(
                      color: exerciseState.workoutType == WorkoutType.Weight
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Switch(
                    value: exerciseState.workoutType == WorkoutType.Cardio,
                    onChanged: (isCardio) {
                      setState(() {
                        exerciseState.workoutType = isCardio ? WorkoutType.Cardio : WorkoutType.Weight;
                      });
                    },
                    activeColor: colorScheme.secondary,
                    inactiveThumbColor: colorScheme.outline,
                    inactiveTrackColor: colorScheme.surfaceContainerHighest,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  Text(
                    'Time',
                    style: textTheme.labelSmall?.copyWith(
                      color: exerciseState.workoutType == WorkoutType.Cardio
                          ? colorScheme.secondary
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: exerciseState.nameController,
            focusNode: getNode(0),
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Exercise Name *',
              isDense: true,
            ),
            validator: (value) => (value == null || value.trim().isEmpty) ? 'Name required' : null,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (exerciseState.workoutType == WorkoutType.Weight)
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: exerciseState.weightController,
                    focusNode: getNode(1),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Wt (kg)',
                      isDense: true,
                    ),
                    validator: (value) => (value != null && value.isNotEmpty && double.tryParse(value) == null)
                        ? 'Invalid'
                        : null,
                    textInputAction: TextInputAction.next,
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
          if (index < _exerciseEditStates.length - 1)
            Divider(
              height: 32,
              thickness: 0.5,
              indent: 8,
              endIndent: 8,
              color: theme.dividerColor,
            ),
        ],
      ),
    );
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
