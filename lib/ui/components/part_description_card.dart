import 'package:flutter/material.dart';

import 'package:workout_planner/models/routine.dart';

class RoutineDescriptionCard extends StatefulWidget {
  final Routine routine;

  const RoutineDescriptionCard({super.key, required this.routine});

  @override
  RoutineDescriptionCardState createState() => RoutineDescriptionCardState();
}

class RoutineDescriptionCardState extends State<RoutineDescriptionCard> {
  @override
  Widget build(BuildContext context) {
    final Routine routine = widget.routine;
    // TODO: implement build
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 6, left: 8, right: 8),
      child: Card(
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4))),
          elevation: 12,
          color: Colors.grey[700],
          child: Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4, left: 8, right: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  routine.routineName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, color: Colors.white),
                ),
                const Text(
                  'You have done this workout',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.white),
                ),
                Text(
                  routine.completionCount.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 36, color: Colors.white),
                ),
                const Text(
                  'times',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.white),
                ),
                const Text(
                  'since',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.white),
                ),
                Text(
                  '${routine.createdDate.month}/${routine.createdDate.day}/${routine.createdDate.year}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Colors.white),
                ),
              ],
            ),
          )),
    );
  }
}