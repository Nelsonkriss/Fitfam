import 'package:flutter/material.dart';

import 'package:workout_planner/utils/routine_helpers.dart';

import 'package:workout_planner/models/routine.dart';

typedef PartTapCallback = void Function(Part part);
typedef StringCallback = void Function(String val);

class PartCard extends StatefulWidget {
  final VoidCallback onDelete;
  final VoidCallback? onPartTap;
  final StringCallback? onTextEdited;
  final bool isEmptyMove = true;
  final Part part;

  @override
  PartCardState createState() => PartCardState();

  const PartCard({
    Key? key,
    required this.onDelete,
    this.onPartTap,
    this.onTextEdited,
    required this.part
  }) : super(key: key);
}

class PartCardState extends State<PartCard> {
  final defaultTextStyle = const TextStyle(fontFamily: 'Staa');
  final textController = TextEditingController();
  final textSetController = TextEditingController();
  final textRepController = TextEditingController();
  late Part _part;

  @override
  void initState() {
    _part = widget.part;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    _part = widget.part;
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 2, left: 8, right: 8),
      child: Card(
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4))),
          elevation: 12,
          color: Theme.of(context).primaryColor,
          child: InkWell(
            onTap: widget.onPartTap,
            splashColor: Colors.grey,
            borderRadius: const BorderRadius.all(Radius.circular(4)),
            child: Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4, left: 8, right: 8),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                children: <Widget>[
                  ListTile(
                    leading: targetedBodyPartToImageConverter(_part.targetedBodyPart ?? TargetedBodyPart.Arm),
                    title: Text(
                      _part.setType == null ? 'To be edited' : setTypeToStringConverter(_part.setType!),
                      style: const TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                    subtitle: Text(
                      _part.targetedBodyPart == null ? 'To be edited' : targetedBodyPartToStringConverter(_part.targetedBodyPart!),
                      style: const TextStyle(color: Colors.white54, fontSize: 16),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 12, right: 12, top: 0, bottom: 4),
                    child: _buildExerciseListView(_part),
                  ),
                  const SizedBox(
                    height: 12,
                  )
                ],
              ),
            ),
          )),
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