import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:workout_planner/bloc/routines_bloc.dart';
import 'package:workout_planner/models/main_targeted_body_part.dart';
import 'package:workout_planner/ui/recommend_page.dart';
import 'package:workout_planner/ui/routine_edit_page.dart';
import 'package:workout_planner/utils/routine_helpers.dart';

import 'components/routine_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>{
  final scrollController = ScrollController();
  bool showShadow = false;

  @override
  void initState() {
    super.initState();

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
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox(
        height: MediaQuery.of(context).size.height,
        child: StreamBuilder<List<Routine>>(
          stream: routinesBloc.allRoutines,
          builder: (_, AsyncSnapshot<List<Routine>> snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasData && snapshot.data!.isNotEmpty) {
              return ListView(
                controller: scrollController,
                children: buildChildren(snapshot.data!),
              );
            }
            
            return const Center(child: Text('No routines found'));
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () {
          showModalBottomSheet(
              context: context,
              builder: (context) {
                return Column(
                  children: [
                    ...MainTargetedBodyPart.values.map((val) {
                      var title = mainTargetedBodyPartToStringConverter(val);
                      return ListTile(
                        title: Text(title),
                        onTap: () {
                          Navigator.pop(context);
                          // Fix: Use DateTime instead of int for createdDate
                          var tempRoutine =
                          Routine(
                              mainTargetedBodyPart: val,
                              routineName: '',
                              parts: <Part>[],
                              createdDate: DateTime.now(), // Fixed: Now passing a DateTime
                              weekdays: [],
                              routineHistory: []
                          );
                          routinesBloc.setCurrentRoutine(tempRoutine);
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => RoutineEditPage(
                                    addOrEdit: AddOrEdit.add,
                                    mainTargetedBodyPart: val,
                                  )));
                        },
                      );
                    }).toList(),
                    ListTile(
                        title: const Text(
                          'Template',
                          style: TextStyle(color: Colors.red),
                        ),
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              // Fix: Removed const constructor if RecommendPage isn't const
                                builder: (context) => RecommendPage()
                            )
                        )
                    )
                  ],
                );
              });
        },
      ),
    );
  }

  List<Widget> buildChildren(List<Routine> routines) {
    var map = Map<MainTargetedBodyPart, List<Routine>>.fromIterable(
      MainTargetedBodyPart.values,
      value: (v) => <Routine>[],
    );
    var todayRoutines = <Routine>[];
    int weekday = DateTime.now().weekday;
    var children = <Widget>[];

    const textColor = Colors.black;
    const todayTextStyle = TextStyle(fontWeight: FontWeight.bold, fontSize: 36, color: Colors.orangeAccent);
    const routineTitleTextStyle = TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: textColor);

    for (var routine in routines) {
      if (routine.weekdays.contains(weekday)) {
        todayRoutines.add(routine);
      }
    }

    children.add(Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Row(
          children: <Widget>[
            Text(['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][weekday - 1],
                style: todayTextStyle),
          ],
        )));
    children.addAll(todayRoutines.map((routine) => RoutineCard(isActive: true, routine: routine)));

    for (var routine in routines) {
      if (!map.containsKey(routine.mainTargetedBodyPart)) {
        map[routine.mainTargetedBodyPart] = [];
      }
      map[routine.mainTargetedBodyPart]!.add(routine);
    }

    // Only show body parts that have routines
    map.keys.where((bodyPart) => map[bodyPart]!.isNotEmpty).forEach((bodyPart) {
      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            mainTargetedBodyPartToStringConverter(bodyPart),
            style: routineTitleTextStyle,
          ),
        ),
      );
      children.addAll(
        map[bodyPart]!.map((routine) => RoutineCard(routine: routine)),
      );
    });

    return children;
  }
}