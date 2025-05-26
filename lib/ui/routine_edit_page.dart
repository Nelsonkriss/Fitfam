import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Import BLoC, Models, Utils
import 'package:workout_planner/bloc/routines_bloc.dart';
import 'package:workout_planner/models/main_targeted_body_part.dart';
import 'package:workout_planner/ui/components/part_edit_card.dart';
import 'package:workout_planner/ui/part_edit_page.dart';
import 'package:workout_planner/utils/routine_helpers.dart';

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

  factory RoutineEditPage.edit({
    Key? key,
    required Routine routine,
  }) {
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
  late Routine _routineEditState;
  bool _isDirty = false;
  late List<bool> _selectedWeekdaysBool;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _initializeRoutineState();
    _nameEditingController.addListener(_markDirtyOnNameChange);
  }

  void _markDirtyOnNameChange() {
    if (!_isDirty && _nameEditingController.text != _routineEditState.routineName) {
      setState(() { _isDirty = true; });
    }
  }

  void _initializeRoutineState() {
    if (widget.addOrEdit == AddOrEdit.edit && widget.initialRoutine != null) {
      final initial = widget.initialRoutine!;
      _routineEditState = initial.copyWith(
        parts: initial.parts.map((p) => p.copyWith(
          exercises: p.exercises.map((e) => e.copyWith()).toList(),
        )).toList(),
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
    _selectedWeekdaysBool = List.generate(7, (index) => _routineEditState.weekdays.contains(index + 1));
    _isDirty = false;
  }

  @override
  void dispose() {
    _scrollController.dispose();
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

  void _onAddPartPressed() async {
    final newPart = Part(
      setType: SetType.Regular,
      targetedBodyPart: TargetedBodyPart.Chest,
      exercises: [],
    );

    try {
      final Part? editedPart = await Navigator.push<Part?>(
        context,
        MaterialPageRoute(
          builder: (context) => PartEditPage(
            addOrEdit: AddOrEdit.add,
            part: newPart,
          ),
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
          builder: (context) => PartEditPage(
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

    final finalRoutineName = _nameEditingController.text.trim().isEmpty
        ? '${mainTargetedBodyPartToStringConverter(_routineEditState.mainTargetedBodyPart)} Workout'
        : _nameEditingController.text.trim();

    Routine finalRoutineToSave = _routineEditState.copyWith(
      routineName: finalRoutineName
    );

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
          routinesBlocInstance.addRoutine(finalRoutineToSave.copyWith(id: null));
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
        parts: _routineEditState.parts.where((p) => p != partToDelete).toList()
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
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('Your edits will not be saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Discard', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return shouldPop ?? false;
  }

  void _showDeleteDialog() {
    final routinesBlocInstance = context.read<RoutinesBloc>();
    final routineIdToDelete = (widget.addOrEdit == AddOrEdit.edit) ? _routineEditState.id : null;
    if (routineIdToDelete == null) {
      _showSnackBar("Cannot delete unsaved routine.");
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Routine?'),
        content: Text('Permanently delete "${_routineEditState.routineName}"?'),
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
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: Text(widget.addOrEdit == AddOrEdit.add ? 'Create Routine' : 'Edit Routine'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back',
            onPressed: () async {
              if (await _onWillPop()) {
                if (mounted) Navigator.pop(context);
              }
            },
          ),
          actions: [
            if (widget.addOrEdit == AddOrEdit.edit && _routineEditState.id != null)
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
        body: Column(
          children: [
            _buildRoutineNameCard(),
            _buildWeekdaySelectorCard(),
            Expanded(
              child: ReorderableListView(
                scrollController: _scrollController,
                onReorder: _onReorder,
                padding: const EdgeInsets.only(bottom: 96),
                children: _buildPartEditCards(),
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          icon: const Icon(Icons.add),
          label: const Text('ADD PART'),
          onPressed: _onAddPartPressed,
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

  Widget _buildRoutineNameCard() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Form(
            key: _formKey,
            child: TextFormField(
              controller: _nameEditingController,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                labelText: 'Routine Title *',
                hintText: 'e.g., Push Day',
                border: InputBorder.none,
                isDense: true,
                labelStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                hintStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                ),
              ),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Please enter a routine title' : null,
              textInputAction: TextInputAction.done,
              onChanged: (_) => _markDirtyOnNameChange(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWeekdaySelectorCard() {
    final List<String> dayAbbreviations = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Card(
        elevation: 2,
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
                    selectedColor: Theme.of(context).colorScheme.primaryContainer,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(context).colorScheme.outline.withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    showCheckmark: false,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
