import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:workout_planner/utils/routine_helpers.dart';
import 'package:workout_planner/ui/components/part_edit_card.dart';
import 'package:workout_planner/ui/part_edit_page.dart';
import 'package:workout_planner/bloc/routines_bloc.dart';
import 'package:workout_planner/models/routine.dart';
import 'package:workout_planner/models/main_targeted_body_part.dart';
import 'package:workout_planner/models/part.dart';
import 'components/spring_curve.dart';

class RoutineEditPage extends StatefulWidget {
  final AddOrEdit addOrEdit;
  final MainTargetedBodyPart? mainTargetedBodyPart;

  const RoutineEditPage({
    Key? key,
    required this.addOrEdit,
    this.mainTargetedBodyPart,
  }) : super(key: key);

  @override
  _RoutineEditPageState createState() => _RoutineEditPageState();
}

class _RoutineEditPageState extends State<RoutineEditPage> {
  final scaffoldKey = GlobalKey<ScaffoldState>();
  final formKey = GlobalKey<FormState>();
  final TextEditingController textEditingController = TextEditingController();
  late ScrollController scrollController;

  bool _initialized = false;
  late Routine routineCopy;
  Routine? routine;

  @override
  void initState() {
    super.initState();
    scrollController = ScrollController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 500),
          curve: SpringCurve.underDamped,
        );
      }
    });
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: StreamBuilder<Routine?>(
        stream: routinesBloc.currentRoutine,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            routine = snapshot.data;

            if (!_initialized) {
              routineCopy = Routine.deepCopy(routine!);
              textEditingController.text = routineCopy.routineName;
              _initialized = true;
            }

            return Scaffold(
              key: scaffoldKey,
              appBar: AppBar(
                title: Text(widget.addOrEdit == AddOrEdit.add
                    ? 'New Routine'
                    : 'Edit Routine'),
                actions: [
                  if (widget.addOrEdit == AddOrEdit.edit)
                    IconButton(
                      icon: const Icon(Icons.delete_forever),
                      onPressed: _showDeleteDialog,
                    ),
                  IconButton(
                    icon: const Icon(Icons.done),
                    onPressed: onDonePressed,
                  ),
                ],
              ),
              body: ReorderableListView(
                scrollController: scrollController,
                onReorder: onReorder,
                children: [
                  _routineDescriptionEditCard(key: ValueKey('description_card')),
                  ...buildExerciseDetails().map((widget) =>
                    widget.key != null ? widget : KeyedSubtree(
                      key: ValueKey('exercise_${widget.hashCode}'),
                      child: widget
                    )
                  ),
                ],
                padding: const EdgeInsets.only(bottom: 128),
              ),
              floatingActionButton: FloatingActionButton.extended(
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('ADD', style: TextStyle(color: Colors.white)),
                backgroundColor: Theme.of(context).primaryColor,
                onPressed: onAddExercisePressed,
              ),
            );
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }

  void onAddExercisePressed() {
    setState(() {
      routineCopy.parts.add(Part(
        setType: SetType.Regular, // Use valid SetType value
        targetedBodyPart: TargetedBodyPart.Chest, // Provide default value
        exercises: [],
      ));
      _startTimeout(300);
    });
  }

  void onDonePressed() {
    if (widget.addOrEdit == AddOrEdit.add && routineCopy.parts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Routine is empty')),
      );
      return;
    }

    if (formKey.currentState!.validate()) {
      formKey.currentState!.save();

      if (widget.addOrEdit == AddOrEdit.add) {
        routineCopy.mainTargetedBodyPart = widget.mainTargetedBodyPart!;
        routinesBloc.addRoutine(routineCopy);
      } else {
        routinesBloc.updateRoutine(routineCopy);
      }
      Navigator.pop(context);
    }
  }

  void onReorder(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) newIndex -= 1;
    final part = routineCopy.parts.removeAt(oldIndex);
    setState(() => routineCopy.parts.insert(newIndex, part));
  }

  List<Widget> buildExerciseDetails() {
    return routineCopy.parts.map((part) => PartEditCard(
      key: ObjectKey(part),
      onDelete: () => setState(() => routineCopy.parts.remove(part)),
      part: part,
      curRoutine: routineCopy, // Added the required parameter
    )).toList();
  }

  Widget _routineDescriptionEditCard({Key? key}) {
    return Padding(
      key: key,
      padding: const EdgeInsets.all(8.0),
      child: Card(
        key: ObjectKey(routineCopy.routineName),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        elevation: 12,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Form(
            key: formKey,
            child: TextFormField(
              controller: textEditingController,
              style: const TextStyle(fontSize: 22),
              decoration: const InputDecoration(
                labelText: 'Routine Title',
                border: InputBorder.none,
              ),
              validator: (value) => value?.isEmpty ?? true
                  ? 'Please enter a title'
                  : null,
              onSaved: (value) => routineCopy.routineName = value!.isEmpty
                  ? '${mainTargetedBodyPartToStringConverter(routineCopy.mainTargetedBodyPart)} Workout'
                  : value,
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _onWillPop() async {
    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('Your edits will not be saved'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return shouldPop ?? false;
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Routine'),
        content: const Text('This action cannot be undone'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              routinesBloc.deleteRoutine(routine: routineCopy);
              Navigator.popUntil(context, (route) => route.isFirst);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _startTimeout([int milliseconds = 300]) {
    Timer(Duration(milliseconds: milliseconds), () {
      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PartEditPage(
            addOrEdit: AddOrEdit.add,
            part: routineCopy.parts.last,
            curRoutine: routineCopy,
          ),
        ),
      ).then((value) {
        if (value != null && mounted) {
          setState(() => routineCopy.parts.last = value);
        }
      });
    });
  }
}