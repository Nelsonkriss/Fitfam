import 'dart:convert';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:workout_planner/resource/firebase_provider.dart';
import 'package:workout_planner/utils/routine_helpers.dart';
import 'package:workout_planner/ui/components/part_card.dart';
import 'package:workout_planner/ui/part_history_page.dart';
import 'package:workout_planner/ui/routine_edit_page.dart';
import 'package:workout_planner/ui/routine_step_page.dart';
import 'package:workout_planner/ui/components/custom_snack_bars.dart';
import 'package:workout_planner/bloc/routines_bloc.dart';

class RoutineDetailPage extends StatefulWidget {
  final bool isRecRoutine;

  const RoutineDetailPage({Key? key, this.isRecRoutine = false}) : super(key: key);

  @override
  State<RoutineDetailPage> createState() => _RoutineDetailPageState();
}

class _RoutineDetailPageState extends State<RoutineDetailPage> {
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController scrollController = ScrollController();
  final GlobalKey globalKey = GlobalKey();

  late String dataString;
  Routine? routine;

  @override
  void initState() {
    super.initState();
    dataString = '-r${FirebaseProvider.generateId()}';
    routinesBloc.fetchAllRoutines();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Routine?>(
      stream: routinesBloc.currentRoutine,
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          routine = snapshot.data!;
          return Scaffold(
            key: scaffoldKey,
            appBar: AppBar(
              centerTitle: true,
              title: Text(mainTargetedBodyPartToStringConverter(routine!.mainTargetedBodyPart)),
              actions: _buildAppBarActions(),
            ),
            body: ListView(children: _buildColumn()),
          );
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }

  List<Widget> _buildAppBarActions() {
    return [
      if (!widget.isRecRoutine) ...[
        IconButton(
          icon: const Icon(Icons.calendar_view_day),
          onPressed: _showWeekdaySelector,
        ),
        IconButton(
          icon: const Icon(Icons.edit),
          onPressed: _navigateToEditPage,
        ),
        IconButton(
          icon: const Icon(Icons.play_arrow),
          onPressed: _startRoutine,
        ),
      ],
      if (widget.isRecRoutine)
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: onAddRecPressed,
        ),
    ];
  }

  void _showWeekdaySelector() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 600,
        child: WeekdayModalBottomSheet(
          routine!.weekdays,
          checkedCallback: updateWorkWeekdays,
        ),
      ),
    );
  }

  void _navigateToEditPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RoutineEditPage(
          addOrEdit: AddOrEdit.edit,
          mainTargetedBodyPart: routine!.mainTargetedBodyPart,
        ),
      ),
    );
  }

  void _startRoutine() {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => RoutineStepPage(
          routine: routine!,
          onBackPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void onAddRecPressed() {
    showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add to your routines?'),
        actions: [
          TextButton(
            child: const Text('No'),
            onPressed: () => Navigator.pop(context, false),
          ),
          TextButton(
            child: const Text('Yes'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    ).then((value) {
      if (value ?? false) {
        routinesBloc.addRoutine(routine!);
        Navigator.pop(context);
      }
    });
  }

  Future<void> onSharePressed() async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) {
      ScaffoldMessenger.of(context).showSnackBar(noNetworkSnackBar);
      return;
    }

    final docId = dataString.replaceFirst("-r", "");
    await FirebaseFirestore.instance
        .collection("userShares")
        .doc(docId)
        .set({
      "id": docId,
      "routine": jsonEncode(Routine.deepCopy(routine!)..routineHistory.clear()),
    });

    _showQRDialog();
  }

  void _showQRDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RepaintBoundary(
                key: globalKey,
                child: QrImageView(
                  data: dataString,
                  size: 300,
                  version: QrVersions.auto,
                  errorCorrectionLevel: QrErrorCorrectLevel.H, // Corrected here
                ),
              ),
              const SizedBox(height: 16),
              ButtonBar(
                children: [
                  ElevatedButton(
                    child: const Text('Save'),
                    onPressed: _saveQrToGallery,
                  ),
                  ElevatedButton(
                    child: const Text('Share'),
                    onPressed: () => Share.share("Check out my routine: ${dataString.replaceFirst("-r", "")}"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  Future<void> _saveQrToGallery() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Image saving is currently unavailable')),
    );
  }
  void updateWorkWeekdays(List<int> checkedWeekdays) {
    setState(() {
      routine!.weekdays = checkedWeekdays;
      routinesBloc.updateRoutine(routine!);
    });
  }

  List<Widget> _buildColumn() {
    return [
      _buildHeaderCard(),
      ...routine!.parts.map((part) => PartCard(
        onDelete: () {},
        onPartTap: widget.isRecRoutine ? null : () => _navigateToPartHistory(part),
        part: part,
      )),
      const SizedBox(height: 60),
    ];
  }

  Widget _buildHeaderCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        elevation: 12,
        color: Theme.of(context).primaryColor,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                routine!.routineName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Staa',
                  fontSize: 26,
                  color: Colors.white,
                ),
              ),
            ),
            if (!widget.isRecRoutine) ...[
              const Text(
                'You have done this workout',
                style: TextStyle(fontSize: 14, color: Colors.white54),
              ),
              Text(
                routine!.completionCount.toString(),
                style: const TextStyle(fontSize: 36, color: Colors.white),
              ),
              const Text('times', style: TextStyle(fontSize: 14, color: Colors.white54)),
              const Text('since', style: TextStyle(fontSize: 14, color: Colors.white54)),
              Text(
                routine!.createdDate.toString().split(' ').first,
                style: const TextStyle(fontSize: 14, color: Colors.white),
              ),
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _navigateToPartHistory(Part part) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PartHistoryPage(part)),
    );
  }
}

typedef WeekdaysCheckedCallback = void Function(List<int> selectedWeekdays);

class WeekdayModalBottomSheet extends StatefulWidget {
  final List<int> checkedWeekDays;
  final WeekdaysCheckedCallback? checkedCallback;

  const WeekdayModalBottomSheet(this.checkedWeekDays, {this.checkedCallback});

  @override
  State<WeekdayModalBottomSheet> createState() => _WeekdayModalBottomSheetState();
}

class _WeekdayModalBottomSheetState extends State<WeekdayModalBottomSheet> {
  final List<String> weekDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  final List<IconData> weekDayIcons = [
    Icons.looks_one,
    Icons.looks_two,
    Icons.looks_3,
    Icons.looks_4,
    Icons.looks_5,
    Icons.looks_6,
    Icons.looks
  ];
  late List<bool> isCheckedList;

  @override
  void initState() {
    super.initState();
    isCheckedList = List.generate(7, (index) => widget.checkedWeekDays.contains(index + 1));
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Choose weekday(s) for this routine'),
          ),
          ...List.generate(7, (index) => _buildWeekdayTile(index)),
        ],
      ),
    );
  }

  Widget _buildWeekdayTile(int index) {
    return CheckboxListTile(
      checkColor: Colors.white,
      activeColor: Colors.grey,
      title: Text(weekDays[index]),
      value: isCheckedList[index],
      onChanged: (value) => _updateWeekdaySelection(index, value),
      secondary: Icon(weekDayIcons[index]),
    );
  }

  void _updateWeekdaySelection(int index, bool? value) {
    if (value == null) return;

    setState(() {
      isCheckedList[index] = value;
      _notifyParent();
    });
  }

  void _notifyParent() {
    final selectedWeekdays = <int>[];
    for (int i = 0; i < isCheckedList.length; i++) {
      if (isCheckedList[i]) selectedWeekdays.add(i + 1);
    }
    widget.checkedCallback?.call(selectedWeekdays);
  }
}