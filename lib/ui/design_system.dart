import 'package:flutter/material.dart';

/// Centralized design tokens for a cohesive visual language.
/// Dark-first palette with vibrant accent and accessible contrast.
class AppColors {
  // Surfaces
  static const Color background = Color(0xFF0E0F12);
  static const Color surface = Color(0xFF14161B);
  static const Color surfaceDim = Color(0xFF0F1114);
  static const Color surfaceBright = Color(0xFF1A1F26);

  // Text
  static const Color onBackground = Colors.white;
  static const Color onSurface = Color(0xE6FFFFFF); // 90%
  static const Color onSurfaceSubtle = Color(0x99FFFFFF); // 60%

  // Accent (teal → purple gradient)
  static const Color accent = Color(0xFF7C5CFF); // purple
  static const Color accentAlt = Color(0xFF1DE9B6); // teal
  static const Gradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentAlt, accent],
  );

  // States
  static const Color success = Color(0xFF2ECC71);
  static const Color warning = Color(0xFFFFC107);
  static const Color danger = Color(0xFFE74C3C);
}

class AppText {
  // 3-tier scale: headline (primary), title (controls), body (secondary)
  static const TextStyle headline = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    color: AppColors.onBackground,
    height: 1.2,
  );

  static const TextStyle title = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.onSurface,
    height: 1.3,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.onSurfaceSubtle,
    height: 1.4,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.onSurfaceSubtle,
  );
}

class AppSpacing {
  static const double xs = 6;
  static const double sm = 10;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

class AppDecorations {
  static BoxDecoration card = BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: Colors.white10),
  );

  static BoxDecoration pill = BoxDecoration(
    color: Colors.white10,
    border: Border.all(color: Colors.white24),
    borderRadius: BorderRadius.circular(999),
  );
}

