import 'package:flutter/material.dart';
import '../design_system.dart';
import 'number_ticker.dart';

/// Large, thumb-friendly slider tied to a NumberTickerController.
class ValueSlider extends StatelessWidget {
  final String label;
  final NumberTickerController controller;
  final double min;
  final double max;
  final int? divisions; // optional, null -> continuous
  final String? suffix;

  const ValueSlider({
    super.key,
    required this.label,
    required this.controller,
    required this.min,
    required this.max,
    this.divisions,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final value = controller.number.clamp(min, max);
    return Container(
      decoration: AppDecorations.card,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: AppText.title)),
              Text("${value.toStringAsFixed(0)}${suffix ?? ''}", style: AppText.title.copyWith(color: AppColors.onBackground)),
            ],
          ),
          const SizedBox(height: 4),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.accent,
              inactiveTrackColor: Colors.white24,
              thumbColor: AppColors.accentAlt,
              overlayColor: AppColors.accentAlt.withOpacity(0.2),
              trackHeight: 6,
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: (v) => controller.number = v,
            ),
          ),
        ],
      ),
    );
  }
}

