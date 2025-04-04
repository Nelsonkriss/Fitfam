import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:workout_planner/resource/firebase_provider.dart';
import 'package:workout_planner/ui/calender_page.dart';
import 'package:workout_planner/ui/components/chart.dart';
import 'package:workout_planner/bloc/routines_bloc.dart';

const String API_KEY = "AIzaSyAmlHXgh8yL823yam0Cwo060R01L7YDFeU";
const TextStyle defaultTextStyle = TextStyle();

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _StatisticsPageState();
  }
}

class _StatisticsPageState extends State<StatisticsPage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<Routine>>(
        stream: routinesBloc.allRoutines,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final routines = snapshot.data!;
            return CustomScrollView(
              slivers: <Widget>[
                SliverSafeArea(sliver: buildMainLayout(routines)),
                CalenderPage(routines: routines),
              ],
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }

  Widget buildMainLayout(List<Routine> routines) {
    final totalCount = getTotalWorkoutCount(routines);
    final ratio = _getRatio(routines);
    final firstRunDate = firebaseProvider.firstRunDate ?? 'unknown date';

    return SliverGrid.count(
      crossAxisCount: 2,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(4),
          child: Card(
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(8))),
            elevation: 12,
            color: Theme.of(context).primaryColor,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(
                        left: 12, right: 12, top: 4, bottom: 4),
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'You have been using this app since $firstRunDate',
                            style: defaultTextStyle,
                          ),
                          const TextSpan(
                              text: '\n\nIt has been\n',
                              style: defaultTextStyle),
                          TextSpan(
                            text: DateTime.now()
                                .difference(DateTime.parse(firstRunDate))
                                .inDays
                                .toString(),
                            style: const TextStyle(fontSize: 36),
                          ),
                          const TextSpan(text: '\ndays'),
                        ],
                        style: const TextStyle(fontFamily: 'Staa'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(4),
          child: Card(
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(8))),
            elevation: 12,
            color: Theme.of(context).primaryColor,
            child: Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4, left: 8, right: 8),
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  children: [
                    const TextSpan(text: 'Total Completion\n'),
                    TextSpan(
                        text: totalCount.toString(),
                        style: TextStyle(fontSize: getFontSize(totalCount.toString())))
                  ],
                  style: const TextStyle(fontFamily: 'Staa'),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(4),
          child: Card(
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(8))),
            elevation: 12,
            color: Theme.of(context).primaryColor,
            child: Center(
              child: totalCount == 0 ? Container() : DonutAutoLabelChart(routines),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(4),
          child: Card(
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(8))),
            elevation: 12,
            color: Theme.of(context).primaryColor,
            child: Center(
              child: CircularPercentIndicator(
                radius: 120.0,
                lineWidth: 13.0,
                animation: true,
                percent: ratio,
                center: Text(
                  "${(ratio * 100).toStringAsFixed(0)}%",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20.0,
                      color: Colors.white),
                ),
                header: const Text(
                  "Goal of this week",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17.0,
                      color: Colors.white),
                ),
                circularStrokeCap: CircularStrokeCap.round,
                progressColor: Colors.grey,
              ),
            ),
          ),
        ),
      ],
    );
  }

  double _getRatio(List<Routine> routines) {
    int totalShare = 0;
    int share = 0;

    final weekday = DateTime.now().weekday;
    DateTime mondayDate = DateTime.now().subtract(Duration(days: weekday - 1));
    mondayDate = DateTime(mondayDate.year, mondayDate.month, mondayDate.day);

    for (final routine in routines) {
      totalShare += routine.weekdays.length;
    }

    for (final routine in routines.where((r) => r.weekdays.isNotEmpty)) {
      for (final weekday in routine.weekdays) {
        for (final ts in routine.routineHistory) {
          final date = DateTime.fromMillisecondsSinceEpoch(ts).toLocal();
          if (date.weekday == weekday &&
              (date.isAfter(mondayDate) || date.compareTo(mondayDate) == 0)) {
            share++;
            break;
          }
        }
      }
    }
    return totalShare == 0 ? 0 : share / totalShare;
  }

  double getFontSize(String displayText) {
    if (displayText.length <= 2) {
      return 120;
    } else {
      return 72;
    }
  }

  int getTotalWorkoutCount(List<Routine> routines) {
    int total = 0;
    for (var i in routines) {
      total += i.completionCount;
    }
    return total;
  }
}