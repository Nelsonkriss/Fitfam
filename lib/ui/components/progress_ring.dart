import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../design_system.dart';

class ProgressRing extends StatelessWidget {
  final double size; // square size
  final double progress; // 0.0 - 1.0
  final String? centerText;
  final String? subtitle;
  final Color trackColor;
  final Color progressColor;

  const ProgressRing({
    super.key,
    required this.size,
    required this.progress,
    this.centerText,
    this.subtitle,
    this.trackColor = const Color(0x22FFFFFF),
    this.progressColor = AppColors.accent,
  });

  @override
  Widget build(BuildContext context) {
    final p = progress.clamp(0.0, 1.0);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _RingPainter(p, trackColor, progressColor),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (centerText != null)
                Text(centerText!, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white)),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(subtitle!, style: AppText.caption, textAlign: TextAlign.center),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double p;
  final Color track;
  final Color value;
  _RingPainter(this.p, this.track, this.value);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.07;
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = math.min(size.width, size.height) / 2 - stroke;
    final bgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track
      ..strokeCap = StrokeCap.round;
    final fgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..shader = const LinearGradient(colors: [AppColors.accentAlt, AppColors.accent]).createShader(rect)
      ..strokeCap = StrokeCap.round;

    // background circle
    canvas.drawCircle(center, radius, bgPaint);

    // progress arc (start at -90 degrees)
    final start = -math.pi / 2;
    final sweep = 2 * math.pi * p;
    final rectArc = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(rectArc, start, sweep, false, fgPaint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) => oldDelegate.p != p;
}

