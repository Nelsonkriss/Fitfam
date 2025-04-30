import 'dart:async';
// For min

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import for FilteringTextInputFormatter
import 'package:keyboard_actions/keyboard_actions.dart';
// import 'package:provider/provider.dart'; // Not currently used here

// Import Models, Utils (adjust paths)
import 'package:workout_planner/models/routine.dart'; // Contains Routine, Part, Exercise, Enums
import 'package:workout_planner/models/part.dart';
// Enum type
import 'package:workout_planner/utils/routine_helpers.dart'; // For AddOrEdit, converters etc.

// --- FIX: Define StringHelper locally or import if defined elsewhere ---
class StringHelper {
  /// Formats weight, removing ".0" for whole numbers.
  static String weightToString(double weight) {
    if (weight <= 0) return "0"; // Handle zero or negative cases
    // Check if the weight is effectively an integer
    if (weight == weight.truncateToDouble()) {
      return weight.toStringAsFixed(0); // Format as integer (e.g., "10")
    } else {
      return weight.toStringAsFixed(1); // Format with one decimal place (e.g., "10.5")
    }
  }
}
// --- End StringHelper Definition ---


// Helper class for enum conversion (can be moved to utils/routine_helpers.dart)
class PartEditPageHelper {
  static SetType radioValueToSetTypeConverter(int radioValue) {
    switch (radioValue) {
      case 0: return SetType.Regular; case 1: return SetType.Drop;
      case 2: return SetType.Super; case 3: return SetType.Tri;
      case 4: return SetType.Giant;
      default: debugPrint("Error: Invalid radio value $radioValue for SetType"); return SetType.Regular;
    }
  }
  static TargetedBodyPart radioValueToTargetedBodyPartConverter(int radioValue) {
    switch (radioValue) {
      case 0: return TargetedBodyPart.Abs; case 1: return TargetedBodyPart.Arm;
      case 2: return TargetedBodyPart.Back; case 3: return TargetedBodyPart.Chest;
      case 4: return TargetedBodyPart.Leg; case 5: return TargetedBodyPart.Shoulder;
      case 6: return TargetedBodyPart.Bicep; case 7: return TargetedBodyPart.Tricep;
      case 8: return TargetedBodyPart.FullBody;
      default: debugPrint("Error: Invalid radio value $radioValue for TargetedBodyPart"); return TargetedBodyPart.Chest;
    }
  }
  static int targetedBodyPartToRadioValue(TargetedBodyPart bodyPart) {
    switch (bodyPart) {
      case TargetedBodyPart.Abs: return 0; case TargetedBodyPart.Arm: return 1;
      case TargetedBodyPart.Back: return 2; case TargetedBodyPart.Chest: return 3;
      case TargetedBodyPart.Leg: return 4; case TargetedBodyPart.Shoulder: return 5;
      case TargetedBodyPart.Bicep: return 6; case TargetedBodyPart.Tricep: return 7;
      case TargetedBodyPart.FullBody: return 8;
    }
  }
  static int setTypeToRadioValue(SetType setType) {
    switch (setType) {
      case SetType.Regular: return 0; case SetType.Drop: return 1;
      case SetType.Super: return 2; case SetType.Tri: return 3;
      case SetType.Giant: return 4;
    }
  }
}

// --- Local State Holder for Editable Exercise Data ---
class _ExerciseEditState {
  final TextEditingController nameController;
  final TextEditingController weightController;
  final TextEditingController setsController;
  final TextEditingController repsController;
  WorkoutType workoutType; // Mutable state within this helper

  _ExerciseEditState({
    required String name,
    required double weight,
    required int sets,
    required String reps,
    required this.workoutType,
  }) : nameController = TextEditingController(text: name),
        weightController = TextEditingController(text: StringHelper.weightToString(weight)), // Use locally defined helper
        setsController = TextEditingController(text: sets > 0 ? sets.toString() : ''),
        repsController = TextEditingController(text: reps);

  factory _ExerciseEditState.fromExercise(Exercise ex) {
    return _ExerciseEditState(
      name: ex.name, weight: ex.weight, sets: ex.sets,
      reps: ex.reps, workoutType: ex.workoutType,
    );
  }
  factory _ExerciseEditState.empty() {
    return _ExerciseEditState(
      name: '', weight: 0, sets: 3, reps: '10', workoutType: WorkoutType.Weight,
    );
  }

  Exercise toExercise() {
    return Exercise(
      name: nameController.text.trim(),
      weight: double.tryParse(weightController.text) ?? 0.0,
      sets: int.tryParse(setsController.text) ?? 0,
      reps: repsController.text.trim(),
      workoutType: workoutType,
      exHistory: {}, // History starts empty or needs original passed if preserving
    );
  }

  void dispose() {
    nameController.dispose(); weightController.dispose();
    setsController.dispose(); repsController.dispose();
  }
}
// --- End Helper Class ---


class PartEditPage extends StatefulWidget {
  final Part originalPart;
  final AddOrEdit addOrEdit;

  const PartEditPage({
    super.key, // Use super(key: key) pattern
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

  // Local state variables
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
    for (int i = 0; i < 4 * 4; i++) { _focusNodes.add(FocusNode()); }
  }

  @override
  void dispose() {
    _additionalNotesController.dispose();
    for (var exState in _exerciseEditStates) { exState.dispose(); }
    for (var node in _focusNodes) { node.dispose(); }
    super.dispose();
  }

  void _updateExercisesForSetType(SetType newSetType) {
    // (Implementation remains the same - updates _exerciseEditStates immutably)
    final currentExerciseData = _exerciseEditStates.map((e) => e.toExercise()).toList();
    final newExerciseCount = setTypeToExerciseCountConverter(newSetType);
    final List<_ExerciseEditState> newStates = [];
    for (int i = 0; i < newExerciseCount; i++) {
      if (i < _exerciseEditStates.length) { newStates.add(_exerciseEditStates[i]); }
      else if (i < currentExerciseData.length) { newStates.add(_ExerciseEditState.fromExercise(currentExerciseData[i]));}
      else { newStates.add(_ExerciseEditState.empty()); }
    }
    for (int i = newExerciseCount; i < _exerciseEditStates.length; i++) { _exerciseEditStates[i].dispose(); }
    setState(() { _selectedSetType = newSetType; _exerciseEditStates = newStates; });
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  void _onDone() {
    // (Implementation remains the same - validates, creates new Part, pops)
    if (!(_formKey.currentState?.validate() ?? false)) { _showSnackBar("Please fill in required exercise details."); return; }
    final List<Exercise> finalExercises = _exerciseEditStates.map((editState) => editState.toExercise()).toList();
    if (finalExercises.isEmpty) { _showSnackBar("Please add at least one exercise."); return;} // Ensure exercises exist

    final Part resultingPart = widget.originalPart.copyWith(
      targetedBodyPart: _selectedTargetedBodyPart, setType: _selectedSetType,
      exercises: finalExercises, additionalNotes: _additionalNotesController.text.trim(),
      partName: widget.originalPart.partName, defaultName: widget.originalPart.defaultName,
    );
    Navigator.pop(context, resultingPart);
  }

  Future<bool> _onWillPop() async {
    // (Implementation remains the same - checks for changes, shows dialog)
    bool hasChanges = false; /* ... Change detection logic ... */
    if (_selectedTargetedBodyPart != widget.originalPart.targetedBodyPart || _selectedSetType != widget.originalPart.setType || _additionalNotesController.text != widget.originalPart.additionalNotes || _exerciseEditStates.length != widget.originalPart.exercises.length) { hasChanges = true; } else { for(int i=0; i < _exerciseEditStates.length; i++) { final stateEx = _exerciseEditStates[i]; final originalEx = widget.originalPart.exercises[i]; if (stateEx.nameController.text != originalEx.name || (double.tryParse(stateEx.weightController.text) ?? 0.0) != originalEx.weight || (int.tryParse(stateEx.setsController.text) ?? 0) != originalEx.sets || stateEx.repsController.text != originalEx.reps || stateEx.workoutType != originalEx.workoutType ) { hasChanges = true; break; } } }
    if (!hasChanges) return true;
    final result = await showDialog<bool>( context: context, barrierDismissible: false, builder: (dialogContext) => AlertDialog( /* ... Discard changes dialog ... */ ), );
    return result ?? false;
  }

  // --- Build Methods ---

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar( /* ... AppBar setup ... */
            title: Text(widget.addOrEdit == AddOrEdit.add ? "Add Part" : "Edit Part"),
            actions: <Widget>[ IconButton( icon: const Icon(Icons.check), tooltip: "Save Part", onPressed: _onDone,) ]
        ),
        body: KeyboardActions( // Use KeyboardActions wrapper
          config: _buildKeyboardActionsConfig(),
          autoScroll: true, // Automatically scroll to focused field
          child: ListView( // Use ListView for scrolling sections
            padding: const EdgeInsets.all(8.0),
            children: [
              _buildSectionCard( title: 'Targeted Muscle Group', icon: Icons.ads_click_rounded, child: _buildTargetedBodyPartRadioList(), ),
              _buildSectionCard( title: 'Set Type', icon: Icons.repeat_rounded, child: _buildSetTypeSegmentedControl(), ),
              // Wrap the exercise details in a single Form widget
              Form(
                key: _formKey,
                child: _buildSectionCard(
                  title: 'Exercise Details',
                  icon: Icons.fitness_center_rounded,
                  child: _buildSetDetailsList(), // Contains TextFormFields
                ),
              ),
              _buildSectionCard( title: 'Additional Notes (Optional)', icon: Icons.notes_rounded, initiallyExpanded: _additionalNotesController.text.isNotEmpty, child: _buildAdditionalNotesField(), ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds a standard card wrapper for sections.
  Widget _buildSectionCard({ required String title, required IconData icon, required Widget child, bool initiallyExpanded = true }) {
    // Removed isFormSection flag, Form is now outside
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ExpansionTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.secondary),
        title: Text(title, style: Theme.of(context).textTheme.titleMedium),
        initiallyExpanded: initiallyExpanded,
        childrenPadding: const EdgeInsets.all(16.0).copyWith(top: 0),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        children: [child],
      ),
    );
  }

  /// Builds RadioListTiles for selecting the targeted body part.
  Widget _buildTargetedBodyPartRadioList() {
    // (Implementation remains the same)
    int currentRadioValue = PartEditPageHelper.targetedBodyPartToRadioValue(_selectedTargetedBodyPart);
    return Column( mainAxisSize: MainAxisSize.min, children: TargetedBodyPart.values.map((bodyPart) { int radioValue = PartEditPageHelper.targetedBodyPartToRadioValue(bodyPart); return RadioListTile<int>( title: Text(targetedBodyPartToStringConverter(bodyPart)), value: radioValue, groupValue: currentRadioValue, onChanged: (newValue) { if (newValue != null) { setState(() { _selectedTargetedBodyPart = PartEditPageHelper.radioValueToTargetedBodyPartConverter(newValue); }); } }, dense: true, visualDensity: VisualDensity.compact, ); }).toList());
  }

  /// Builds CupertinoSegmentedControl for selecting the set type.
  Widget _buildSetTypeSegmentedControl() {
    // (Implementation remains the same)
    const selectedTextStyle = TextStyle(fontSize: 14, fontWeight: FontWeight.bold); const unselectedTextStyle = TextStyle(fontSize: 14);
    final Map<SetType, Widget> children = { for (var type in SetType.values) type: Padding( padding: const EdgeInsets.symmetric(vertical: 8.0), child: Text(setTypeToStringConverter(type).split(' ').first, style: _selectedSetType == type ? selectedTextStyle : unselectedTextStyle ), ) };
    return Padding( padding: const EdgeInsets.symmetric(vertical: 8.0), child: SizedBox( width: double.infinity, child: CupertinoSlidingSegmentedControl<SetType>( children: children, groupValue: _selectedSetType, thumbColor: setTypeToColorConverter(_selectedSetType).withOpacity(0.8), backgroundColor: Colors.grey.shade300, onValueChanged: (newSetType) { if (newSetType != null && newSetType != _selectedSetType) { _updateExercisesForSetType(newSetType); } }, ), ), );
  }

  /// Builds the list of exercise editor widgets (wrapped by Form externally now).
  Widget _buildSetDetailsList() {
    return Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(_exerciseEditStates.length, (index) {
          return _buildSingleExerciseEditor(index);
        }));
  }

  /// Builds the editor fields for a single exercise.
  Widget _buildSingleExerciseEditor(int index) {
    // (Implementation remains the same - uses FilteringTextInputFormatter)
    if (index >= _exerciseEditStates.length) return const SizedBox.shrink();
    final exerciseState = _exerciseEditStates[index]; int focusNodeBaseIndex = index * 4;
    FocusNode? getNode(int offset) { int nodeIndex = focusNodeBaseIndex + offset; return nodeIndex < _focusNodes.length ? _focusNodes[nodeIndex] : null; }
    return Padding( padding: const EdgeInsets.symmetric(vertical: 12.0), child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [ Row( mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ Text('Exercise ${index + 1}', style: Theme.of(context).textTheme.titleSmall), Row( mainAxisSize: MainAxisSize.min, children: [ Text('Weight', style: TextStyle(fontSize: 12, color: exerciseState.workoutType == WorkoutType.Weight ? Theme.of(context).primaryColor : Colors.grey)), Switch( value: exerciseState.workoutType == WorkoutType.Cardio, onChanged: (isCardio) { setState(() { exerciseState.workoutType = isCardio ? WorkoutType.Cardio : WorkoutType.Weight; }); }, activeColor: Colors.lightBlueAccent, inactiveThumbColor: Theme.of(context).primaryColor, inactiveTrackColor: Theme.of(context).primaryColor.withOpacity(0.5), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, ), Text('Time', style: TextStyle(fontSize: 12, color: exerciseState.workoutType == WorkoutType.Cardio ? Colors.lightBlueAccent : Colors.grey)), ], ) ], ), const SizedBox(height: 8), TextFormField( controller: exerciseState.nameController, focusNode: getNode(0), textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Exercise Name *', border: OutlineInputBorder(), isDense: true), validator: (value) => (value == null || value.trim().isEmpty) ? 'Name required' : null, textInputAction: TextInputAction.next, ), const SizedBox(height: 12), Row( crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[ if (exerciseState.workoutType == WorkoutType.Weight) Expanded( flex: 2, child: TextFormField( controller: exerciseState.weightController, focusNode: getNode(1), inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))], keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Wt (kg)', border: OutlineInputBorder(), isDense: true), validator: (value) => (value != null && value.isNotEmpty && double.tryParse(value) == null) ? 'Invalid' : null, textInputAction: TextInputAction.next, ), ) else const Expanded(flex: 2, child: SizedBox()), const SizedBox(width: 8), Expanded( flex: 1, child: TextFormField( controller: exerciseState.setsController, focusNode: getNode(2), inputFormatters: [FilteringTextInputFormatter.digitsOnly], keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Sets *', border: OutlineInputBorder(), isDense: true), validator: (value) => (value == null || value.trim().isEmpty || (int.tryParse(value.trim()) ?? 0) <= 0) ? 'Invalid' : null, textInputAction: TextInputAction.next, ), ), const SizedBox(width: 8), Expanded( flex: 2, child: TextFormField( controller: exerciseState.repsController, focusNode: getNode(3), keyboardType: exerciseState.workoutType == WorkoutType.Weight ? TextInputType.text : TextInputType.number, inputFormatters: exerciseState.workoutType == WorkoutType.Cardio ? [FilteringTextInputFormatter.digitsOnly] : [], decoration: InputDecoration( labelText: exerciseState.workoutType == WorkoutType.Weight ? 'Reps *' : 'Time (sec) *', border: const OutlineInputBorder(), isDense: true ), validator: (value) => (value == null || value.trim().isEmpty) ? 'Required' : null, textInputAction: TextInputAction.done, ), ), ], ), if (index < _exerciseEditStates.length - 1) const Divider(height: 32, thickness: 0.5, indent: 8, endIndent: 8), ], ), );
  }

  /// Builds the field for additional notes.
  Widget _buildAdditionalNotesField() {
    // (Implementation remains the same)
    return Padding( padding: const EdgeInsets.symmetric(vertical: 8.0), child: TextFormField( controller: _additionalNotesController, decoration: const InputDecoration( labelText: 'Notes', hintText: 'Add any specific instructions or tips...', border: OutlineInputBorder(), ), maxLines: 3, textCapitalization: TextCapitalization.sentences, ), );
  }


  /// Configuration for the KeyboardActions toolbar.
  KeyboardActionsConfig _buildKeyboardActionsConfig() {
    // (Implementation remains the same)
    final validFocusNodes = _focusNodes.where((node) => node != null).toList(); return KeyboardActionsConfig( keyboardActionsPlatform: KeyboardActionsPlatform.ALL, keyboardBarColor: Colors.grey[200], nextFocus: true, actions: validFocusNodes.map((node) { return KeyboardActionsItem( focusNode: node, displayDoneButton: true, ); }).toList(), );
  }

} // End of _PartEditPageState