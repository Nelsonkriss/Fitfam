import 'dart:async';

import 'package:confetti/confetti.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:workout_planner/ui/components/custom_snack_bars.dart';
import 'package:workout_planner/utils/routine_helpers.dart';
import 'package:workout_planner/bloc/routines_bloc.dart';
import 'package:workout_planner/resource/shared_prefs_provider.dart';

import 'components/number_ticker.dart';

class RoutineStepPage extends StatefulWidget {
  final Routine routine;
  final VoidCallback? celebrateCallback;
  final VoidCallback? onBackPressed;

  const RoutineStepPage({
    required this.routine,
    this.celebrateCallback,
    this.onBackPressed,
    Key? key,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _RoutineStepPageState();
}

const _kLabelTextStyle = TextStyle(color: Colors.white70);
const _kSmallBoldTextStyle = TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold);

class _RoutineStepPageState extends State<RoutineStepPage> with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ConfettiController _confettiController = ConfettiController(duration: const Duration(seconds: 10));
  final _timerDuration = const Duration(milliseconds: 50);
  final _stepperKey = GlobalKey();

  late List<Exercise> _exercises;
  bool _finished = false;

  late Routine _routine;
  late String _title;

  Timer? _incrementTimer;
  Timer? _decrementTimer;

  final List<int> _setsLeft = [];
  final List<int> _currentPartIndexes = [];
  final List<int> _stepperIndexes = [];
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    _routine = Routine.deepCopy(widget.routine);

    final tempDateStr = dateTimeToStringConverter(DateTime.now());
    for (final part in _routine.parts) {
      for (final ex in part.exercises) {
        ex.exHistory.remove(tempDateStr);
      }
    }

    _exercises = _routine.parts.expand((p) => p.exercises).toList();
    _generateStepperIndexes();
  }

  @override
  void dispose() {
    _incrementTimer?.cancel();
    _decrementTimer?.cancel();
    _confettiController.dispose();
    super.dispose();
  }

  void _generateStepperIndexes() {
    final parts = widget.routine.parts;
    _stepperIndexes.clear();
    _currentPartIndexes.clear();
    _setsLeft.clear();
    
    debugPrint('Generating stepper indexes for routine with ${parts.length} parts');
    
    for (int i = 0, k = 0; k < parts.length; k++) {
      final part = parts[k];
      debugPrint('Processing part $k (${part.setType}) with ${part.exercises.length} exercises');
      
      final ex = _exercises[i];
      final sets = ex.sets;
      debugPrint('Exercise $i: ${ex.name} with $sets sets');

      switch (part.setType) {
        case SetType.Drop:
        case SetType.Regular:
          for (var j = 0; j < sets; j++) {
            _stepperIndexes.add(i);
            _currentPartIndexes.add(k);
            _setsLeft.add(sets - j - 1);
          }
          i += 1;
          break;
        case SetType.Super:
          for (var j = 0; j < sets; j++) {
            _stepperIndexes.addAll([i, i + 1]);
            _currentPartIndexes.addAll([k, k]);
            _setsLeft.addAll([sets - j - 1, sets - j - 1]);
          }
          i += 2;
          break;
        case SetType.Tri:
          for (var j = 0; j < sets; j++) {
            _stepperIndexes.addAll([i, i + 1, i + 2]);
            _currentPartIndexes.addAll([k, k, k]);
            _setsLeft.addAll([sets - j - 1, sets - j - 1, sets - j - 1]);
          }
          i += 3;
          break;
        case SetType.Giant:
          for (var j = 0; j < sets; j++) {
            _stepperIndexes.addAll([i, i + 1, i + 2, i + 3]);
            _currentPartIndexes.addAll([k, k, k, k]);
            _setsLeft.addAll(List.filled(4, sets - j - 1));
          }
          i += 4;
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    _title = _currentStep < _stepperIndexes.length
        ? '${targetedBodyPartToStringConverter(_routine.parts[_currentPartIndexes[_currentStep]].targetedBodyPart)} - '
        '${setTypeToStringConverter(_routine.parts[_currentPartIndexes[_currentStep]].setType)}'
        : 'Finished!';

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: Text(_title, style: const TextStyle(color: Colors.white54)),
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(12),
            child: LinearProgressIndicator(),
          ),
          backgroundColor: Theme.of(context).primaryColor,
        ),
        backgroundColor: Theme.of(context).primaryColor,
        body: _buildMainLayout(),
      ),
    );
  }

  Widget _buildMainLayout() {
    if (!_finished) return _buildStepper(_exercises);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
        ),
      ),
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Workout Complete! 🎉',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                const Icon(Icons.check_circle, size: 80, color: Colors.white),
                const SizedBox(height: 40),
              ],
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              maxBlastForce: 8,
              minBlastForce: 4,
              emissionFrequency: 0.05,
              colors: const [Colors.green, Colors.blue, Colors.pink, Colors.orange, Colors.purple],
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  backgroundColor: const Color(0xFF00C9FF),
                ),
                child: const Text(
                  'DONE',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepper(List<Exercise> exs) {
    return SingleChildScrollView(
      child: Stepper(
        key: _stepperKey,
        physics: const NeverScrollableScrollPhysics(),
        controlsBuilder: (BuildContext context, ControlsDetails details) {
          return ButtonBar(
            alignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: details.onStepContinue,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 48, vertical: 12),
                  child: Text('Next', style: TextStyle(fontSize: 20)),
                ),
              )
            ],
          );
        },
        currentStep: _stepperIndexes[_currentStep],
        onStepContinue: _handleStepContinue,
        steps: List.generate(exs.length, (index) => index).map((i) {
          final isCurrent = i == _stepperIndexes[_currentStep];
          final isNext = _currentStep < _stepperIndexes.length - 1 && i == _stepperIndexes[_currentStep + 1];
          final isPast = !_stepperIndexes.sublist(_currentStep).contains(i);

          return Step(
            title: Text(
              exs[i].name,
              style: TextStyle(
                fontSize: _getTitleFontSize(isCurrent, isNext),
                fontWeight: FontWeight.w300,
                color: _getTitleColor(isCurrent, isNext),
                decoration: isPast ? TextDecoration.lineThrough : null,
              ),
            ),
            content: _buildStep(exs[i]),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStep(Exercise ex) {
    final partIndex = _currentPartIndexes[_currentStep];
    final exIndex = _routine.parts[partIndex].exercises.indexWhere((e) => e.name == ex.name);

    if (exIndex == -1) return const SizedBox.shrink();

    final exercise = _routine.parts[partIndex].exercises[exIndex];
    // Fix 2: Add required initialNumber parameter
    final tickerController = NumberTickerController(initial: exercise.weight.toDouble());
    return ListTile(
      title: Row(
        children: [
          Expanded(
            child: IconButton(
              icon: const Icon(Icons.info, color: Colors.white),
              onPressed: () => _launchURL(ex.name),
            ),
          ),
        ],
      ),
      subtitle: Column(
        children: [
          _buildMetricRow('Weight:', 'Sets left:'),
          _buildControlRow(tickerController, exercise),
          _buildMetricRow('Sets left:', 'Reps:'),
          _buildValueRow(_setsLeft[_currentStep].toString(), exercise.reps),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String left, String right) => Row(
    children: [
      Expanded(child: Center(child: Text(left, style: _kLabelTextStyle))),
      Expanded(child: Center(child: Text(right, style: _kLabelTextStyle))),
    ],
  );

  Widget _buildControlRow(NumberTickerController controller, Exercise ex) => Row(
    children: [
      _buildWeightButton('-', () => _decreaseWeight(controller, ex)),
      Expanded(
        child: NumberTicker(
          controller: controller,
          textStyle: const TextStyle(
              color: Colors.white,
              fontSize: 64,
              fontWeight: FontWeight.bold
          ),
        ),
      ),
      _buildWeightButton('+', () => _increaseWeight(controller, ex)),
    ],
  );

  Widget _buildValueRow(String left, String right) => Row(
    children: [
      Expanded(child: Center(child: Text(left, style: _kSmallBoldTextStyle))),
      Expanded(child: Center(child: Text(right, style: _kSmallBoldTextStyle))),
    ],
  );

  Widget _buildWeightButton(String symbol, VoidCallback action) => Expanded(
    flex: 2,
    child: GestureDetector(
      onLongPress: action,
      onLongPressUp: () => _cancelTimers(),
      child: ElevatedButton(
        onPressed: () => action(),
        child: Text(symbol, style: const TextStyle(fontSize: 28)),
        style: OutlinedButton.styleFrom(shape: const CircleBorder()),
      ),
    ),
  );

  void _handleStepContinue() {
    if (_stepperIndexes.isEmpty || _currentPartIndexes.isEmpty) {
      // Reset stepper if indexes are invalid
      _generateStepperIndexes();
      _currentStep = 0;
      setState(() {});
      return;
    }

    debugPrint('Current step: $_currentStep, Total steps: ${_stepperIndexes.length}');
    debugPrint('Current exercise: ${_exercises[_stepperIndexes[_currentStep]].name}');

    _updateExHistory();
    setState(() {
      if (_currentStep < _stepperIndexes.length - 1) {
        _currentStep++;
        debugPrint('Advanced to step: $_currentStep');
        debugPrint('Next exercise: ${_exercises[_stepperIndexes[_currentStep]].name}');
      } else {
        _finished = true;
        _confettiController.play();
        _routine.completionCount++;
        if (!_routine.routineHistory.contains(getTimestampNow())) {
          _routine.routineHistory.add(getTimestampNow());
        }
        debugPrint('Routine completed! Saving...');
        routinesBloc.updateRoutine(_routine);
      }
    });
  }

  void _updateExHistory() {
    final tempDateStr = dateTimeToStringConverter(DateTime.now());
    final partIndex = _currentPartIndexes[_currentStep];
    final exIndex = _stepperIndexes[_currentStep];

    final exercise = _routine.parts[partIndex].exercises.firstWhere(
          (e) => e.name == _exercises[exIndex].name,
      orElse: () => _exercises[exIndex],
    );

    exercise.exHistory.update(
      tempDateStr,
          (value) => '$value/${exercise.weight}',
      ifAbsent: () => exercise.weight.toString(),
    );
  }

  Future<bool> _onWillPop() async {
    if (_finished) return true;
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        content: SizedBox(
          height: 200,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                color: Theme.of(context).primaryColor,
                child: const Column(
                  children: [
                    Text('Too soon to quit.😑', style: TextStyle(color: Colors.white)),
                    Text('Your progress will not be saved.', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text('Stay', style: TextStyle(color: Theme.of(context).primaryColor)),
                  ),
                  const SizedBox(width: 20),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text('Quit', style: TextStyle(color: Theme.of(context).primaryColor)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ) ?? false;
  }

  Future<void> _launchURL(String ex) async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) {
      ScaffoldMessenger.of(context).showSnackBar(noNetworkSnackBar);
      return;
    }

    final url = Uri.parse('https://www.bodybuilding.com/exercises/search?query=${Uri.encodeComponent(ex)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.inAppWebView);
    }
  }

  void _increaseWeight(NumberTickerController controller, Exercise ex) {
    _incrementTimer = Timer.periodic(_timerDuration, (_) {
      controller.number++;
      ex.weight = controller.number;
    });
  }

  void _decreaseWeight(NumberTickerController controller, Exercise ex) {
    _decrementTimer = Timer.periodic(_timerDuration, (_) {
      controller.number--;
      ex.weight = controller.number;
    });
  }

  void _cancelTimers() {
    _incrementTimer?.cancel();
    _decrementTimer?.cancel();
  }

  Color _getTitleColor(bool isCurrent, bool isNext) => isCurrent
      ? Colors.white
      : isNext
      ? Colors.white60
      : Colors.black;

  double _getTitleFontSize(bool isCurrent, bool isNext) => isCurrent
      ? 24
      : isNext
      ? 20
      : 16;
}