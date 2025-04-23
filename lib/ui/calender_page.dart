import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:workout_planner/models/routine.dart';
import 'package:workout_planner/models/workout_session.dart';
import 'package:workout_planner/bloc/workout_session_bloc.dart';
import 'package:workout_planner/ui/components/routine_card.dart';
import 'package:workout_planner/utils/date_time_extension.dart';

class CalenderPage extends StatefulWidget {
  final List<Routine> routines;

  const CalenderPage({Key? key, required this.routines}) : super(key: key);

  @override
  State<StatefulWidget> createState() => CalenderPageState();
}

class CalenderPageState extends State<CalenderPage> {
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController scrollController = ScrollController();
  late Map<String, Routine> dateToRoutineMap;
  List<WorkoutSession> _sessions = [];

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      print("Initializing CalenderPage");
    }
    dateToRoutineMap = getWorkoutDates(widget.routines);
  }

  void showBottomSheet(Routine routine) {
    showCupertinoModalPopup(
        context: context,
        builder: (BuildContext context) {
          return SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                    color: Colors.transparent,
                    width: MediaQuery.of(context).size.width,
                    child: RoutineCard(routine: routine)),
              ));
        });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<WorkoutSession>>(
      stream: workoutSessionBloc.allSessions,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          _sessions = snapshot.data!;
          if (kDebugMode) {
            print("Calendar received ${_sessions.length} sessions");
          }
          dateToRoutineMap = getWorkoutDates(widget.routines);
        }
        
        return SliverGrid.count(
          crossAxisCount: 13,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          children: buildMonthRow(),
        );
      },
    );
  }

  List<Widget> buildMonthRow() {
    List<Widget> widgets = <Widget>[];

    widgets.add(const Text(' '));

    for (int i = 1; i <= 12; i++) {
      widgets.add(Center(
          child: Text(intToMonth(i),
              style: const TextStyle(fontSize: 10, color: Colors.black))));
    }

    widgets.addAll(buildDayRows());

    return widgets;
  }

  List<Widget> buildDayRows() {
    List<Widget> widgets = <Widget>[];

    for (int i = 1; i <= 31; i++) {
      widgets.add(Center(
          child: Text(i.toString(),
              style: const TextStyle(fontSize: 12, color: Colors.black))));
      for (int j = 1; j <= 12; j++) {
        DateTime date = DateTime(DateTime.now().year, j, i);
        String dateStr = date.toSimpleString();
        widgets.add(Material(
          elevation: 4,
          child: Container(
            decoration: BoxDecoration(
                color: isWorkoutDay(j, i) ? Colors.grey : Colors.transparent,
                shape: BoxShape.rectangle,
                border: Border.all(color: Colors.grey.shade500, width: 0.3)),
            child: GestureDetector(onTap: () {
              if (isWorkoutDay(j, i)) {
                Routine? routineForDate = dateToRoutineMap[dateStr];
                if (routineForDate != null) {
                  showBottomSheet(routineForDate);
                }
              }
            }),
          ),
        ));
      }
    }

    for (int i = 1; i <= 31; i++) {
      widgets.add(Container());
      for (int j = 1; j <= 1; j++) {
        widgets.add(Container());
      }
    }

    return widgets;
  }

  bool isWorkoutDay(int month, int day) {
    DateTime date = DateTime(DateTime.now().year, month, day);
    String dateStr = date.toString().split(' ').first;
    return dateToRoutineMap.keys.contains(dateStr);
  }

  String intToMonth(int i) {
    switch (i) {
      case 1: return 'Jan';
      case 2: return 'Feb';
      case 3: return 'Mar';
      case 4: return 'Apr';
      case 5: return 'May';
      case 6: return 'Jun';
      case 7: return 'Jul';
      case 8: return 'Aug';
      case 9: return 'Sep';
      case 10: return 'Oct';
      case 11: return 'Nov';
      case 12: return 'Dec';
      default: throw Exception('Invalid month');
    }
  }

  Map<String, Routine> getWorkoutDates(List<Routine> routines) {
    Map<String, Routine> dates = {};

    // Add routine history dates
    for (var routine in routines) {
      if (routine.routineHistory.isNotEmpty) {
        for (var timestamp in routine.routineHistory) {
          var d = DateTime.fromMillisecondsSinceEpoch(timestamp).toLocal();
          dates[d.toSimpleString()] = routine;
        }
      }
    }

    // Add workout session dates
    for (var session in _sessions) {
      if (session.isCompleted && session.endTime != null) {
        var routine = routines.firstWhere(
          (r) => r.id == session.routine.id,
          orElse: () => session.routine,
        );
        dates[session.endTime!.toSimpleString()] = routine;
      }
    }

    if (kDebugMode) {
      print("Workout dates: $dates");
    }
    return dates;
  }
}