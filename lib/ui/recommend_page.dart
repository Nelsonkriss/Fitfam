import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:workout_planner/bloc/routines_bloc.dart';
import 'package:workout_planner/models/main_targeted_body_part.dart';
import 'package:workout_planner/utils/routine_helpers.dart';

import 'components/routine_card.dart';

class RecommendPage extends StatefulWidget {
  const RecommendPage({Key? key}) : super(key: key);

  @override
  _RecommendPageState createState() => _RecommendPageState();
}

class _RecommendPageState extends State<RecommendPage> {
  final scrollController = ScrollController();
  bool showShadow = false;

  @override
  void initState() {
    scrollController.addListener(() {
      if (mounted) {
        if (scrollController.offset <= 0) {
          setState(() {
            showShadow = false;
          });
        } else if (showShadow == false) {
          setState(() {
            showShadow = true;
          });
        }
      }
    });

    super.initState();
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text("Dev's Favorite"),
          elevation: showShadow ? 8 : 0,
        ),
        body: SizedBox(
          height: MediaQuery.of(context).size.height,
          child: StreamBuilder<List<Routine>>(
            stream: routinesBloc.allRecRoutines,
            builder: (_, AsyncSnapshot<List<Routine>> snapshot) {
              if (snapshot.hasData) {
                final routines = snapshot.data!;
                return ListView(
                  controller: scrollController,
                  children: buildChildren(routines),
                );
              }
              return const Center(child: CircularProgressIndicator());
            },
          ),
        ));
  }

  List<Widget> buildChildren(List<Routine> routines) {
    final map = Map<MainTargetedBodyPart, List<Routine>>.fromIterable(
      MainTargetedBodyPart.values,
      value: (v) => <Routine>[],
    );
    final children = <Widget>[];

    const textColor = Colors.black;
    const style = TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: textColor);

    for (final routine in routines) {
      if (map.containsKey(routine.mainTargetedBodyPart) == false) {
        map[routine.mainTargetedBodyPart] = [];
      }
      map[routine.mainTargetedBodyPart]!.add(routine);
    }

    // Only show body parts that have routines
    for (final bodyPart in map.keys.where((bp) => map[bp]!.isNotEmpty)) {
      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            mainTargetedBodyPartToStringConverter(bodyPart),
            style: style
          ),
        ),
      );
      children.addAll(
        map[bodyPart]!.map((r) => RoutineCard(routine: r, isRecRoutine: true))
      );
    }

    return children;
  }
}