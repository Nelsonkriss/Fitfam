import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:workout_planner/utils/routine_helpers.dart';
import 'package:workout_planner/ui/part_edit_page.dart';
import 'package:workout_planner/models/routine.dart';

typedef StringCallback = void Function(String val);

class PartEditCard extends StatefulWidget {
  final VoidCallback onDelete;
  final StringCallback? onTextEdited;
  final Part part;
  final Routine curRoutine; // Added required parameter

  const PartEditCard({
    Key? key,
    required this.onDelete,
    this.onTextEdited,
    required this.part,
    required this.curRoutine, // Added here
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => PartEditCardState();
}

class PartEditCardState extends State<PartEditCard> {
  final defaultTextStyle = const TextStyle(fontFamily: 'Staa');
  final textController = TextEditingController();
  final textSetController = TextEditingController();
  final textRepController = TextEditingController();
  late Part part;

  @override
  void initState() {
    super.initState();
    part = widget.part;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 2, left: 8, right: 8),
      child: Card(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4))),
        elevation: 12,
        color: Theme.of(context).primaryColor,
        child: Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 4, left: 8, right: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: targetedBodyPartToImageConverter(part.targetedBodyPart ?? TargetedBodyPart.Arm),
                title: Text(
                  part.setType == null ? 'To be edited' : setTypeToStringConverter(part.setType!),
                  style: const TextStyle(color: Colors.white70),
                ),
                subtitle: Text(
                  part.targetedBodyPart == null ? 'To be edited' : targetedBodyPartToStringConverter(part.targetedBodyPart!),
                  style: const TextStyle(color: Colors.white54),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 12, right: 12, top: 0, bottom: 0),
                child: _buildExerciseListView(part),
              ),
              Row(
                children: <Widget>[
                  const Spacer(),
                  TextButton(
                    child: const Text(
                      'EDIT',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PartEditPage(
                            addOrEdit: AddOrEdit.edit,
                            part: part,
                            curRoutine: widget.curRoutine, // Added parameter here
                          ),
                        ),
                      ).then((value) {
                        setState(() {
                          if (value != null) this.part = value as Part;
                        });
                      });
                    },
                  ),
                  TextButton(
                    child: const Text(
                      'DELETE',
                      style: TextStyle(color: Colors.red, fontSize: 16),
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete this part of routine?'),
                          content: const Text('You cannot undo this.'),
                          actions: <Widget>[
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('No'),
                            ),
                            TextButton(
                              onPressed: () {
                                widget.onDelete();
                                Navigator.of(context).pop(true);
                              },
                              child: const Text('Yes'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExerciseListView(Part part) {
    var children = <Widget>[];

    children.add(Row(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        const Expanded(
          flex: 22,
          child: Text(
            "",
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: TextStyle(color: Colors.white),
          ),
        ),
        Expanded(
            flex: 5,
            child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(style: defaultTextStyle, children: const [
                  TextSpan(text: 'sets', style: TextStyle(color: Colors.white54, fontSize: 14)),
                ]))),
        Expanded(
            flex: 1,
            child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(style: defaultTextStyle, children: const [
                  TextSpan(text: ' ', style: TextStyle(color: Colors.white54, fontSize: 12)),
                ]))),
        Expanded(
            flex: 5,
            child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(style: defaultTextStyle, children: const [
                  TextSpan(text: 'reps', style: TextStyle(color: Colors.white54, fontSize: 14)),
                ]))),
      ],
    ));

    for (var ex in part.exercises) {
      children.add(Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            flex: 22,
            child: Text(
              ex.name,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: const TextStyle(color: Colors.white),
            ),
          ),
          Expanded(
              flex: 5,
              child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(style: defaultTextStyle, children: [
                    TextSpan(text: ex.sets.toString(), style: const TextStyle(color: Colors.white, fontSize: 18)),
                  ]))),
          Expanded(
              flex: 1,
              child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(style: defaultTextStyle, children: const [
                    TextSpan(text: 'x', style: TextStyle(color: Colors.white70, fontSize: 16)),
                  ]))),
          Expanded(
              flex: 5,
              child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(style: defaultTextStyle, children: [
                    TextSpan(text: ex.reps, style: const TextStyle(color: Colors.white, fontSize: 18)),
                  ]))),
        ],
      ));
      children.add(const Divider(color: Colors.white38));
    }

    return Column(children: children);
  }
}