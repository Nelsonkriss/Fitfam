import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Utility class that recreates Android XML animations in Flutter
/// Based on com.axiommobile.bodybuilding animation system
class AndroidAnimations {
  
  /// Fade in animation (equivalent to abc_fade_in.xml)
  static Animation<double> createFadeIn(AnimationController controller) {
    return Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: Curves.decelerate,
    ));
  }

  /// Fade out animation (equivalent to abc_fade_out.xml)
  static Animation<double> createFadeOut(AnimationController controller) {
    return Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: Curves.decelerate,
    ));
  }

  /// Slide in from bottom animation (equivalent to abc_slide_in_bottom.xml)
  static Animation<Offset> createSlideInBottom(AnimationController controller) {
    return Tween<Offset>(
      begin: const Offset(0.0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: Curves.decelerate,
    ));
  }

  /// Slide out to bottom animation (equivalent to abc_slide_out_bottom.xml)
  static Animation<Offset> createSlideOutBottom(AnimationController controller) {
    return Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0.0, 0.5),
    ).animate(CurvedAnimation(
      parent: controller,
      curve: Curves.decelerate,
    ));
  }

  /// Slide in from top animation (equivalent to abc_slide_in_top.xml)
  static Animation<Offset> createSlideInTop(AnimationController controller) {
    return Tween<Offset>(
      begin: const Offset(0.0, -0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: Curves.decelerate,
    ));
  }

  /// Slide out to top animation (equivalent to abc_slide_out_top.xml)
  static Animation<Offset> createSlideOutTop(AnimationController controller) {
    return Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0.0, -0.5),
    ).animate(CurvedAnimation(
      parent: controller,
      curve: Curves.decelerate,
    ));
  }

  /// Shake error animation (equivalent to shake_error.xml)
  static Animation<double> createShakeError(AnimationController controller) {
    return Tween<double>(
      begin: -0.02,
      end: 0.02,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: const _CycleInterpolator(2.0),
    ));
  }

  /// Grow fade in animation (equivalent to abc_grow_fade_in_from_bottom.xml)
  static AnimationGroup createGrowFadeInFromBottom(AnimationController controller) {
    return AnimationGroup(
      scale: Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.decelerate,
      )),
      opacity: Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.decelerate,
      )),
      translation: Tween<Offset>(
        begin: const Offset(0.0, 0.5),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.decelerate,
      )),
    );
  }

  /// Shrink fade out animation (equivalent to abc_shrink_fade_out_from_bottom.xml)
  static AnimationGroup createShrinkFadeOutFromBottom(AnimationController controller) {
    return AnimationGroup(
      scale: Tween<double>(
        begin: 1.0,
        end: 0.0,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.decelerate,
      )),
      opacity: Tween<double>(
        begin: 1.0,
        end: 0.0,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.decelerate,
      )),
      translation: Tween<Offset>(
        begin: Offset.zero,
        end: const Offset(0.0, 0.5),
      ).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.decelerate,
      )),
    );
  }

  /// Bottom sheet slide in animation (equivalent to design_bottom_sheet_slide_in.xml)
  static Animation<Offset> createBottomSheetSlideIn(AnimationController controller) {
    return Tween<Offset>(
      begin: const Offset(0.0, 1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: Curves.easeOutCubic,
    ));
  }

  /// Bottom sheet slide out animation (equivalent to design_bottom_sheet_slide_out.xml)
  static Animation<Offset> createBottomSheetSlideOut(AnimationController controller) {
    return Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0.0, 1.0),
    ).animate(CurvedAnimation(
      parent: controller,
      curve: Curves.easeInCubic,
    ));
  }

  /// Snackbar in animation (equivalent to design_snackbar_in.xml)
  static AnimationGroup createSnackbarIn(AnimationController controller) {
    return AnimationGroup(
      translation: Tween<Offset>(
        begin: const Offset(0.0, 1.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.easeOutBack,
      )),
      opacity: Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.easeOut,
      )),
    );
  }

  /// Snackbar out animation (equivalent to design_snackbar_out.xml)
  static AnimationGroup createSnackbarOut(AnimationController controller) {
    return AnimationGroup(
      translation: Tween<Offset>(
        begin: Offset.zero,
        end: const Offset(0.0, 1.0),
      ).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.easeInBack,
      )),
      opacity: Tween<double>(
        begin: 1.0,
        end: 0.0,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.easeIn,
      )),
    );
  }

  /// Fast out extra slow in animation (equivalent to fragment_fast_out_extra_slow_in.xml)
  static Animation<Offset> createFastOutExtraSlowIn(AnimationController controller) {
    return Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: const Cubic(0.0, 0.0, 0.2, 1.0), // Fast out extra slow in curve
    ));
  }

  /// Material 3 motion fade enter
  static Animation<double> createM3MotionFadeEnter(AnimationController controller) {
    return Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: const Cubic(0.0, 0.0, 0.2, 1.0), // Material 3 emphasized curve
    ));
  }

  /// Material 3 motion fade exit
  static Animation<double> createM3MotionFadeExit(AnimationController controller) {
    return Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: const Cubic(0.4, 0.0, 1.0, 1.0), // Material 3 emphasized curve
    ));
  }

  /// Material 3 emphasized easing (equivalent to m3_sys_motion_easing_emphasized.xml)
  static Animation<double> createM3EmphasizedEasing(AnimationController controller) {
    return Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: const Cubic(0.2, 0.0, 0.0, 1.0), // Material 3 emphasized
    ));
  }

  /// Material 3 standard easing (equivalent to m3_sys_motion_easing_standard.xml)
  static Animation<double> createM3StandardEasing(AnimationController controller) {
    return Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: const Cubic(0.2, 0.0, 0.0, 1.0), // Material 3 standard
    ));
  }

  /// Material fast out slow in (equivalent to mtrl_fast_out_slow_in.xml)
  static Animation<double> createMaterialFastOutSlowIn(AnimationController controller) {
    return Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: const Cubic(0.4, 0.0, 0.2, 1.0), // Material fast out slow in
    ));
  }

  /// Material linear out slow in (equivalent to mtrl_linear_out_slow_in.xml)
  static Animation<double> createMaterialLinearOutSlowIn(AnimationController controller) {
    return Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: const Cubic(0.0, 0.0, 0.2, 1.0), // Material linear out slow in
    ));
  }

  /// Material fast out linear in (equivalent to mtrl_fast_out_linear_in.xml)
  static Animation<double> createMaterialFastOutLinearIn(AnimationController controller) {
    return Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: const Cubic(0.4, 0.0, 1.0, 1.0), // Material fast out linear in
    ));
  }

  /// Enhanced slide in from bottom with Material 3 curves
  static AnimationGroup createEnhancedSlideInBottom(AnimationController controller) {
    return AnimationGroup(
      translation: Tween<Offset>(
        begin: const Offset(0.0, 1.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: const Cubic(0.2, 0.0, 0.0, 1.0), // Material 3 emphasized
      )),
      opacity: Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: const Cubic(0.0, 0.0, 0.2, 1.0), // Material 3 fade in
      )),
      scale: Tween<double>(
        begin: 0.8,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: const Cubic(0.2, 0.0, 0.0, 1.0), // Material 3 emphasized
      )),
    );
  }

  /// Enhanced slide out to bottom with Material 3 curves
  static AnimationGroup createEnhancedSlideOutBottom(AnimationController controller) {
    return AnimationGroup(
      translation: Tween<Offset>(
        begin: Offset.zero,
        end: const Offset(0.0, 1.0),
      ).animate(CurvedAnimation(
        parent: controller,
        curve: const Cubic(0.4, 0.0, 1.0, 1.0), // Material 3 emphasized exit
      )),
      opacity: Tween<double>(
        begin: 1.0,
        end: 0.0,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: const Cubic(0.4, 0.0, 1.0, 1.0), // Material 3 fade out
      )),
      scale: Tween<double>(
        begin: 1.0,
        end: 0.8,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: const Cubic(0.4, 0.0, 1.0, 1.0), // Material 3 emphasized exit
      )),
    );
  }

  /// Enhanced popup enter animation with Material 3 curves
  static AnimationGroup createEnhancedPopupEnter(AnimationController controller) {
    return AnimationGroup(
      scale: Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: const Cubic(0.05, 0.7, 0.1, 1.0), // Enhanced popup curve
      )),
      opacity: Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: const Cubic(0.0, 0.0, 0.2, 1.0), // Material 3 fade in
      )),
      translation: Tween<Offset>(
        begin: const Offset(0.0, 0.1),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: const Cubic(0.2, 0.0, 0.0, 1.0), // Material 3 emphasized
      )),
    );
  }

  /// Enhanced popup exit animation with Material 3 curves
  static AnimationGroup createEnhancedPopupExit(AnimationController controller) {
    return AnimationGroup(
      scale: Tween<double>(
        begin: 1.0,
        end: 0.0,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: const Cubic(0.3, 0.0, 0.8, 0.15), // Enhanced popup exit curve
      )),
      opacity: Tween<double>(
        begin: 1.0,
        end: 0.0,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: const Cubic(0.4, 0.0, 1.0, 1.0), // Material 3 fade out
      )),
      translation: Tween<Offset>(
        begin: Offset.zero,
        end: const Offset(0.0, -0.1),
      ).animate(CurvedAnimation(
        parent: controller,
        curve: const Cubic(0.4, 0.0, 1.0, 1.0), // Material 3 emphasized exit
      )),
    );
  }

  /// Page transition slide in from right
  static AnimationGroup createPageSlideInFromRight(AnimationController controller) {
    return AnimationGroup(
      translation: Tween<Offset>(
        begin: const Offset(1.0, 0.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: const Cubic(0.2, 0.0, 0.0, 1.0), // Material 3 emphasized
      )),
      opacity: Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: const Cubic(0.0, 0.0, 0.2, 1.0), // Material 3 fade in
      )),
    );
  }

  /// Page transition slide out to left
  static AnimationGroup createPageSlideOutToLeft(AnimationController controller) {
    return AnimationGroup(
      translation: Tween<Offset>(
        begin: Offset.zero,
        end: const Offset(-1.0, 0.0),
      ).animate(CurvedAnimation(
        parent: controller,
        curve: const Cubic(0.4, 0.0, 1.0, 1.0), // Material 3 emphasized exit
      )),
      opacity: Tween<double>(
        begin: 1.0,
        end: 0.0,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: const Cubic(0.4, 0.0, 1.0, 1.0), // Material 3 fade out
      )),
    );
  }

  /// Get standard medium animation duration (equivalent to @android:integer/config_mediumAnimTime)
  static const Duration mediumAnimTime = Duration(milliseconds: 300);

  /// Get standard short animation duration
  static const Duration shortAnimTime = Duration(milliseconds: 150);

  /// Get standard long animation duration
  static const Duration longAnimTime = Duration(milliseconds: 500);

  /// Get extra long animation duration for complex animations
  static const Duration extraLongAnimTime = Duration(milliseconds: 700);

  /// Get Material 3 motion durations
  static const Duration m3ShortDuration = Duration(milliseconds: 200);
  static const Duration m3MediumDuration = Duration(milliseconds: 300);
  static const Duration m3LongDuration = Duration(milliseconds: 400);
  static const Duration m3ExtraLongDuration = Duration(milliseconds: 500);
}

/// Custom cycle interpolator that mimics Android's cycleInterpolator
class _CycleInterpolator extends Curve {
  const _CycleInterpolator(this.cycles);

  final double cycles;

  @override
  double transformInternal(double t) {
    return math.sin(2 * math.pi * cycles * t);
  }
}

/// Animation group that holds multiple related animations
class AnimationGroup {
  final Animation<double>? scale;
  final Animation<double>? opacity;
  final Animation<Offset>? translation;
  final Animation<double>? rotation;

  const AnimationGroup({
    this.scale,
    this.opacity,
    this.translation,
    this.rotation,
  });
}

/// Extension to add Android-style animation methods to AnimationController
extension AndroidAnimationController on AnimationController {
  
  /// Play fade in animation
  Future<void> fadeIn() async {
    duration = AndroidAnimations.mediumAnimTime;
    await forward();
  }

  /// Play fade out animation
  Future<void> fadeOut() async {
    duration = AndroidAnimations.mediumAnimTime;
    await reverse();
  }

  /// Play slide in from bottom animation
  Future<void> slideInFromBottom() async {
    duration = AndroidAnimations.mediumAnimTime;
    await forward();
  }

  /// Play slide out to bottom animation
  Future<void> slideOutToBottom() async {
    duration = AndroidAnimations.mediumAnimTime;
    await reverse();
  }

  /// Play shake error animation
  Future<void> shakeError() async {
    duration = const Duration(milliseconds: 300);
    await forward();
    await reverse();
  }

  /// Play grow fade in animation
  Future<void> growFadeIn() async {
    duration = AndroidAnimations.mediumAnimTime;
    await forward();
  }

  /// Play shrink fade out animation
  Future<void> shrinkFadeOut() async {
    duration = AndroidAnimations.mediumAnimTime;
    await reverse();
  }

  /// Play enhanced popup enter animation
  Future<void> enhancedPopupEnter() async {
    duration = AndroidAnimations.m3MediumDuration;
    await forward();
  }

  /// Play enhanced popup exit animation
  Future<void> enhancedPopupExit() async {
    duration = AndroidAnimations.m3MediumDuration;
    await reverse();
  }

  /// Play page transition animation
  Future<void> pageTransitionIn() async {
    duration = AndroidAnimations.m3LongDuration;
    await forward();
  }

  /// Play page transition out animation
  Future<void> pageTransitionOut() async {
    duration = AndroidAnimations.m3LongDuration;
    await reverse();
  }
}
