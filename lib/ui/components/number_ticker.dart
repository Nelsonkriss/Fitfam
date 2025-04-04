import 'package:flutter/material.dart';

class NumberTickerController extends ValueNotifier<double> {
  NumberTickerController({double initial = 0}) : super(initial);

  double get number => value;
  set number(double num) => value = num >= 0 ? num : 0;
}

class NumberTicker extends StatefulWidget {
  final NumberTickerController controller;
  final TextStyle textStyle;
  final Color backgroundColor;
  final Curve curve;
  final int fractionDigits;
  final Duration duration;

  const NumberTicker({
    required this.controller,
    this.textStyle = const TextStyle(fontSize: 24, color: Colors.black),
    this.backgroundColor = Colors.transparent,
    this.curve = Curves.easeOut,
    this.fractionDigits = 0,
    this.duration = const Duration(milliseconds: 300),
    Key? key,
  }) : super(key: key);

  @override
  _NumberTickerState createState() => _NumberTickerState();
}

class _NumberTickerState extends State<NumberTicker> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late String _currentValue;
  late List<_SingleDigitController> _digitControllers;
  late List<GlobalKey> _digitKeys;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.controller.number.toStringAsFixed(widget.fractionDigits);
    _digitControllers = _createDigitControllers(_currentValue);
    _digitKeys = List.generate(_digitControllers.length, (i) => GlobalKey());
    _animationController = AnimationController(vsync: this, duration: widget.duration);
    widget.controller.addListener(_updateNumber);
  }

  @override
  void dispose() {
    _animationController.dispose();
    widget.controller.removeListener(_updateNumber);
    super.dispose();
  }

  List<_SingleDigitController> _createDigitControllers(String value) {
    return value.split('').map((char) {
      return char == '.'
          ? _SingleDigitController(isDecimal: true)
          : _SingleDigitController(digit: int.parse(char));
    }).toList();
  }

  void _updateNumber() {
    final newValue = widget.controller.number.toStringAsFixed(widget.fractionDigits);
    if (newValue == _currentValue) return;

    final oldDigits = _currentValue.split('');
    final newDigits = newValue.split('');

    setState(() {
      _currentValue = newValue;
      _digitControllers = _createDigitControllers(newValue);
      _animateDigits(oldDigits, newDigits);
    });
  }

  void _animateDigits(List<String> oldDigits, List<String> newDigits) {
    // Add animation logic here
  }

  @override
  Widget build(BuildContext context) {
    if (_digitControllers.isEmpty || _digitKeys.isEmpty) {
      return Container(); // Return empty container if no digits
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(_digitControllers.length, (index) {
        if (index >= _digitKeys.length || index >= _digitControllers.length) {
          return Container(); // Skip invalid indices
        }
        return _SingleDigitTicker(
          key: _digitKeys[index],
          controller: _digitControllers[index],
          textStyle: widget.textStyle,
          backgroundColor: widget.backgroundColor,
          duration: widget.duration,
          curve: widget.curve,
        );
      }),
    );
  }
}

class _SingleDigitController extends ValueNotifier<int> {
  final bool isDecimal;

  _SingleDigitController({
    int digit = 0,
    this.isDecimal = false,
  }) : super(digit) {
    assert(digit >= 0 && digit <= 9, 'Digit must be between 0-9');
  }
}

class _SingleDigitTicker extends StatelessWidget {
  final _SingleDigitController controller;
  final TextStyle textStyle;
  final Color backgroundColor;
  final Duration duration;
  final Curve curve;

  const _SingleDigitTicker({
    required this.controller,
    required this.textStyle,
    required this.backgroundColor,
    required this.duration,
    required this.curve,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final fontSize = textStyle.fontSize ?? 24;
    return Container(
      width: fontSize * 0.7,
      height: fontSize * 1.4,
      color: backgroundColor,
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        controller: ScrollController(
          initialScrollOffset: controller.value * fontSize * 1.4,
        ),
        children: List.generate(10, (index) => Center(
          child: Text(
            controller.isDecimal ? '.' : '$index',
            style: textStyle,
          ),
        )),
      ),
    );
  }
}