import 'package:flutter/material.dart';
// For min/max

// --- Controller ---
/// Controls the numeric value displayed by a NumberTicker.
class NumberTickerController extends ValueNotifier<double> {
  /// The step value used for incrementing/decrementing (if applicable).
  final double step;
  /// The minimum value the ticker can display.
  final double minValue;
  /// The maximum value the ticker can display (optional).
  final double? maxValue;

  NumberTickerController({
    double initial = 0,
    this.step = 1.0, // Default step
    this.minValue = 0.0, // Default min value
    this.maxValue,   // No default max value
  }) : super(initial.clamp(minValue, maxValue ?? double.infinity)); // Clamp initial value

  /// Gets the current numeric value.
  double get number => value;

  /// Sets the numeric value, clamping it within minValue and maxValue.
  set number(double newValue) {
    value = newValue.clamp(minValue, maxValue ?? double.infinity);
  }

  /// Increments the number by the step value.
  void increment() {
    number += step;
  }

  /// Decrements the number by the step value.
  void decrement() {
    number -= step;
  }
}


// --- Main Ticker Widget ---
class NumberTicker extends StatefulWidget {
  final NumberTickerController controller;
  final TextStyle textStyle;
  final BoxDecoration? decoration; // Use BoxDecoration for background, border etc.
  final Curve curve;
  final int fractionDigits;
  final Duration duration;
  final MainAxisAlignment mainAxisAlignment; // Allow alignment control
  final String? prefix; // Optional text before the number
  final String? suffix; // Optional text after the number

  const NumberTicker({
    required this.controller,
    this.textStyle = const TextStyle(fontSize: 24, color: Colors.black),
    this.decoration,
    this.curve = Curves.linear, // Linear often looks better for number ticks
    this.fractionDigits = 0,
    this.duration = const Duration(milliseconds: 300),
    this.mainAxisAlignment = MainAxisAlignment.center,
    this.prefix,
    this.suffix,
    super.key,
  });

  @override
  State<NumberTicker> createState() => _NumberTickerState();
}

class _NumberTickerState extends State<NumberTicker> {
  late double _currentValue; // Store the numeric value
  late String _currentStringValue; // Store the formatted string

  @override
  void initState() {
    super.initState();
    _currentValue = widget.controller.number;
    _currentStringValue = _formatValue(_currentValue);
    widget.controller.addListener(_onControllerUpdate);
  }

  @override
  void didUpdateWidget(covariant NumberTicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If controller changes, remove old listener and add new one
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller.removeListener(_onControllerUpdate);
      _currentValue = widget.controller.number; // Update value from new controller
      _currentStringValue = _formatValue(_currentValue);
      widget.controller.addListener(_onControllerUpdate);
    }
    // Update formatted string if fractionDigits changes
    if (widget.fractionDigits != oldWidget.fractionDigits) {
      _currentStringValue = _formatValue(_currentValue);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerUpdate);
    super.dispose();
  }

  /// Formats the numeric value to a string based on fractionDigits.
  String _formatValue(double value) {
    return value.toStringAsFixed(widget.fractionDigits);
  }

  /// Called when the controller's value changes.
  void _onControllerUpdate() {
    final newValue = widget.controller.number;
    final newStringValue = _formatValue(newValue);

    // Only update state if the formatted string value actually changes
    // This prevents unnecessary rebuilds if clamping keeps the value the same
    if (newStringValue != _currentStringValue) {
      setState(() {
        _currentValue = newValue;
        _currentStringValue = newStringValue;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine if the number increased or decreased for animation direction
    // Note: We compare numeric values here, not strings, for correct direction.
    final previousValue = widget.controller.value; // Get latest actual value
    final bool increasing = _currentValue >= previousValue;

    return Container(
      decoration: widget.decoration, // Apply background/border decoration
      child: Row(
        mainAxisSize: MainAxisSize.min, // Take minimum horizontal space
        mainAxisAlignment: widget.mainAxisAlignment,
        children: [
          // Optional Prefix
          if (widget.prefix != null && widget.prefix!.isNotEmpty)
            Text(widget.prefix!, style: widget.textStyle),

          // Animated Digits
          // Use ClipRect to prevent overflow during animation
          ClipRect(
            child: TweenAnimationBuilder(
              // Use the string value as the key to trigger animation on change
              key: ValueKey(_currentStringValue),
              duration: widget.duration,
              curve: widget.curve,
              // Tween from previous numeric value to current numeric value
              tween: Tween<double>(begin: previousValue, end: _currentValue),
              builder: (context, double animatedValue, child) {
                // Render the digits based on the *target* string (_currentStringValue)
                // The animation effect comes from AnimatedSwitcher/SlideTransition inside _SingleDigit
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: _buildDigitWidgets(_currentStringValue, increasing),
                );
              },
            ),
          ),

          // Optional Suffix
          if (widget.suffix != null && widget.suffix!.isNotEmpty)
            Padding( // Add padding if both prefix/suffix and number exist
                padding: EdgeInsets.only(left: (widget.textStyle.fontSize ?? 24) * 0.1),
                child: Text(widget.suffix!, style: widget.textStyle)
            ),
        ],
      ),
    );
  }

  /// Builds the list of individual digit widgets.
  List<Widget> _buildDigitWidgets(String stringValue, bool increasing) {
    final List<Widget> widgets = [];
    for (int i = 0; i < stringValue.length; i++) {
      final char = stringValue[i];
      widgets.add(
        _SingleDigit(
          key: ValueKey('$char-$i'), // Key helps AnimatedSwitcher
          character: char,
          textStyle: widget.textStyle,
          duration: widget.duration,
          curve: widget.curve,
          slideUp: increasing, // Direction of animation
        ),
      );
    }
    return widgets;
  }
}


// --- Single Digit/Character Widget ---
/// Displays a single character (digit or decimal point) with slide animation.
class _SingleDigit extends StatelessWidget {
  final String character;
  final TextStyle textStyle;
  final Duration duration;
  final Curve curve;
  final bool slideUp; // True if number increased, false if decreased

  const _SingleDigit({
    required Key key,
    required this.character,
    required this.textStyle,
    required this.duration,
    required this.curve,
    required this.slideUp,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Use AnimatedSwitcher for smooth transition between characters
    return AnimatedSwitcher(
      duration: duration,
      // Define the transition: slide vertically
      transitionBuilder: (Widget child, Animation<double> animation) {
        final offsetAnimation = Tween<Offset>(
          begin: Offset(0.0, slideUp ? 1.0 : -1.0), // Slide in from bottom if increasing, top if decreasing
          end: Offset.zero,
        ).chain(CurveTween(curve: curve)) // Apply curve here
            .animate(animation);

        return SlideTransition(
          position: offsetAnimation,
          child: child,
        );
      },
      // Define layout behavior during animation (optional)
      // layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
      //   return Stack(
      //     alignment: Alignment.center,
      //     children: <Widget>[
      //       ...previousChildren,
      //       if (currentChild != null) currentChild,
      //     ],
      //   );
      // },
      child: Text(
        // Use character directly, key on AnimatedSwitcher handles changes
        character,
        key: ValueKey(character), // Ensure switcher recognizes change
        style: textStyle,
      ),
    );
  }
}