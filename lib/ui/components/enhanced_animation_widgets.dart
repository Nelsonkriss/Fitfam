import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:workout_planner/models/exercise_animation_data.dart';
import 'package:workout_planner/ui/components/exercise_animation_widget.dart';
import 'package:workout_planner/utils/android_animations.dart';

/// Enhanced rest period animation widget with Android-style animations
class EnhancedRestPeriodAnimationWidget extends StatefulWidget {
  final String exerciseName;
  final Duration restDuration;
  final Duration remainingTime;
  final VoidCallback? onSkipRest;

  const EnhancedRestPeriodAnimationWidget({
    super.key,
    required this.exerciseName,
    required this.restDuration,
    required this.remainingTime,
    this.onSkipRest,
  });

  @override
  State<EnhancedRestPeriodAnimationWidget> createState() => _EnhancedRestPeriodAnimationWidgetState();
}

class _EnhancedRestPeriodAnimationWidgetState extends State<EnhancedRestPeriodAnimationWidget>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _pulseController;
  late AnimationController _progressController;
  
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    // Slide in animation controller
    _slideController = AnimationController(
      duration: AndroidAnimations.mediumAnimTime,
      vsync: this,
    );
    
    // Pulse animation controller
    _pulseController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    
    // Progress animation controller
    _progressController = AnimationController(
      duration: widget.restDuration,
      vsync: this,
    );

    // Create Android-style animations
    _slideAnimation = AndroidAnimations.createSlideInBottom(_slideController);
    _fadeAnimation = AndroidAnimations.createFadeIn(_slideController);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Start animations
    _slideController.forward();
    _pulseController.repeat(reverse: true);
    _progressController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _pulseController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = 1.0 - (widget.remainingTime.inSeconds / widget.restDuration.inSeconds);
    
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.primary.withOpacity(0.1),
                Theme.of(context).colorScheme.primary.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).shadowColor.withOpacity(0.2),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with animated timer icon
              Row(
                children: [
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            Icons.timer,
                            color: Theme.of(context).colorScheme.primary,
                            size: 24,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rest Period',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Review form for next set',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.onSkipRest != null)
                    ElevatedButton.icon(
                      onPressed: widget.onSkipRest,
                      icon: const Icon(Icons.skip_next, size: 18),
                      label: const Text('Skip'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.secondary,
                        foregroundColor: Theme.of(context).colorScheme.onSecondary,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Animated progress bar
              Container(
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                ),
                child: AnimatedBuilder(
                  animation: _progressController,
                  builder: (context, child) {
                    return LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.primary,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    );
                  },
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Exercise animation with enhanced styling
              if (ExerciseAnimationData.hasAnimationForExercise(widget.exerciseName))
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                  child: ExerciseAnimationWidget(
                    exerciseName: widget.exerciseName,
                    width: 250,
                    height: 180,
                    autoPlay: true,
                    showControls: true,
                    showDescription: false,
                  ),
                )
              else
                Container(
                  width: 250,
                  height: 180,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.fitness_center,
                        size: 64,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.exerciseName,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Enhanced set preparation animation widget with Android-style animations
class EnhancedSetPreparationAnimationWidget extends StatefulWidget {
  final String exerciseName;
  final int setNumber;
  final int targetReps;
  final double targetWeight;
  final VoidCallback onReady;
  final VoidCallback onSkip;

  const EnhancedSetPreparationAnimationWidget({
    super.key,
    required this.exerciseName,
    required this.setNumber,
    required this.targetReps,
    required this.targetWeight,
    required this.onReady,
    required this.onSkip,
  });

  @override
  State<EnhancedSetPreparationAnimationWidget> createState() => _EnhancedSetPreparationAnimationWidgetState();
}

class _EnhancedSetPreparationAnimationWidgetState extends State<EnhancedSetPreparationAnimationWidget>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late AnimationController _rotateController;
  
  late AnimationGroup _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();
    
    _slideController = AnimationController(
      duration: AndroidAnimations.mediumAnimTime,
      vsync: this,
    );
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _rotateController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    // Create Android-style animations
    _slideAnimation = AndroidAnimations.createGrowFadeInFromBottom(_slideController);
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );
    _rotateAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _rotateController, curve: Curves.linear),
    );

    // Start animations with staggered timing
    _slideController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _scaleController.forward();
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _rotateController.repeat();
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    _scaleController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation.translation!,
      child: FadeTransition(
        opacity: _slideAnimation.opacity!,
        child: ScaleTransition(
          scale: _slideAnimation.scale!,
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).shadowColor.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with animated icon
                Row(
                  children: [
                    AnimatedBuilder(
                      animation: _rotateAnimation,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle: _rotateAnimation.value * 2 * math.pi,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Theme.of(context).colorScheme.primary,
                                  Theme.of(context).colorScheme.secondary,
                                ],
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.fitness_center,
                              color: Theme.of(context).colorScheme.onPrimary,
                              size: 28,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Set ${widget.setNumber}',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          Text(
                            widget.exerciseName,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Target info with enhanced styling
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
                          Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.5),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildTargetInfo(
                          context,
                          '${widget.targetReps}',
                          'Reps',
                          Icons.repeat,
                          Theme.of(context).colorScheme.primary,
                        ),
                        Container(
                          width: 2,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Theme.of(context).colorScheme.outline.withOpacity(0.2),
                                Theme.of(context).colorScheme.outline,
                                Theme.of(context).colorScheme.outline.withOpacity(0.2),
                              ],
                            ),
                          ),
                        ),
                        _buildTargetInfo(
                          context,
                          '${widget.targetWeight} kg',
                          'Weight',
                          Icons.fitness_center,
                          Theme.of(context).colorScheme.secondary,
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Exercise animation
                if (ExerciseAnimationData.hasAnimationForExercise(widget.exerciseName))
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                      ),
                    ),
                    child: ExerciseAnimationWidget(
                      exerciseName: widget.exerciseName,
                      width: 280,
                      height: 200,
                      autoPlay: true,
                      showControls: false,
                      showDescription: false,
                    ),
                  ),
                
                const SizedBox(height: 24),
                
                // Action buttons with enhanced styling
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: widget.onSkip,
                        icon: const Icon(Icons.skip_next, size: 18),
                        label: const Text('Skip'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.outline,
                            width: 2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: widget.onReady,
                        icon: const Icon(Icons.play_arrow, size: 20),
                        label: const Text('Ready to Start'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTargetInfo(BuildContext context, String value, String label, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Enhanced set completion animation widget with Android-style animations
class EnhancedSetCompletionAnimationWidget extends StatefulWidget {
  final String exerciseName;
  final int completedReps;
  final double completedWeight;
  final bool isPersonalRecord;
  final VoidCallback onContinue;

  const EnhancedSetCompletionAnimationWidget({
    super.key,
    required this.exerciseName,
    required this.completedReps,
    required this.completedWeight,
    required this.isPersonalRecord,
    required this.onContinue,
  });

  @override
  State<EnhancedSetCompletionAnimationWidget> createState() => _EnhancedSetCompletionAnimationWidgetState();
}

class _EnhancedSetCompletionAnimationWidgetState extends State<EnhancedSetCompletionAnimationWidget>
    with TickerProviderStateMixin {
  late AnimationController _bounceController;
  late AnimationController _confettiController;
  late AnimationController _glowController;
  
  late Animation<double> _bounceAnimation;
  late Animation<double> _confettiAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _confettiController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _bounceAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.elasticOut),
    );
    
    _confettiAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _confettiController, curve: Curves.easeOut),
    );
    
    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // Start animations
    _bounceController.forward();
    _glowController.repeat(reverse: true);
    
    if (widget.isPersonalRecord) {
      _confettiController.forward();
    }

    // Auto-dismiss after 2.5 seconds
    Timer(const Duration(milliseconds: 2500), () {
      if (mounted) widget.onContinue();
    });
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _confettiController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = widget.isPersonalRecord ? Colors.amber : Colors.green;
    
    return ScaleTransition(
      scale: _bounceAnimation,
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              primaryColor.withOpacity(0.1),
              primaryColor.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: primaryColor.withOpacity(0.5),
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Success icon with confetti animation
            AnimatedBuilder(
              animation: Listenable.merge([_confettiAnimation, _glowAnimation]),
              builder: (context, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Confetti particles for personal records
                    if (widget.isPersonalRecord)
                      ...List.generate(12, (index) {
                        final angle = (index * 30) * (math.pi / 180);
                        final distance = 60 * _confettiAnimation.value;
                        return Transform.translate(
                          offset: Offset(
                            distance * math.cos(angle),
                            distance * math.sin(angle),
                          ),
                          child: Transform.rotate(
                            angle: angle * _confettiAnimation.value * 2,
                            child: Icon(
                              index.isEven ? Icons.star : Icons.celebration,
                              color: [Colors.amber, Colors.orange, Colors.red, Colors.purple][index % 4]
                                  .withOpacity(1 - _confettiAnimation.value),
                              size: 16 + (8 * (1 - _confettiAnimation.value)),
                            ),
                          ),
                        );
                      }),
                    
                    // Glowing effect
                    AnimatedBuilder(
                      animation: _glowAnimation,
                      builder: (context, child) {
                        return Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withOpacity(0.4 * _glowAnimation.value),
                                blurRadius: 30 * _glowAnimation.value,
                                spreadRadius: 10 * _glowAnimation.value,
                              ),
                            ],
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: widget.isPersonalRecord
                                    ? [Colors.amber, Colors.orange]
                                    : [Colors.green, Colors.lightGreen],
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              widget.isPersonalRecord ? Icons.emoji_events : Icons.check,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
            
            const SizedBox(height: 20),
            
            // Success message
            Text(
              widget.isPersonalRecord ? 'Personal Record!' : 'Set Complete!',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: primaryColor.shade700,
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Completed stats
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: primaryColor.withOpacity(0.3),
                ),
              ),
              child: Text(
                '${widget.completedReps} reps @ ${widget.completedWeight} kg',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: primaryColor.shade700,
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Continue button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: widget.onContinue,
                icon: const Icon(Icons.arrow_forward, size: 20),
                label: const Text('Continue'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Enhanced exercise transition widget with Android-style animations
class EnhancedExerciseTransitionWidget extends StatefulWidget {
  final String currentExercise;
  final String nextExercise;
  final VoidCallback onContinue;

  const EnhancedExerciseTransitionWidget({
    super.key,
    required this.currentExercise,
    required this.nextExercise,
    required this.onContinue,
  });

  @override
  State<EnhancedExerciseTransitionWidget> createState() => _EnhancedExerciseTransitionWidgetState();
}

class _EnhancedExerciseTransitionWidgetState extends State<EnhancedExerciseTransitionWidget>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _progressController;
  
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    
    _slideController = AnimationController(
      duration: AndroidAnimations.longAnimTime,
      vsync: this,
    );
    
    _progressController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _slideAnimation = AndroidAnimations.createFastOutExtraSlowIn(_slideController);
    _fadeAnimation = AndroidAnimations.createM3MotionFadeEnter(_slideController);
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.linear),
    );

    _slideController.forward();
    _progressController.forward();

    // Auto-continue after 3 seconds
    Timer(const Duration(seconds: 3), () {
      if (mounted) widget.onContinue();
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.8),
                Theme.of(context).colorScheme.tertiaryContainer.withOpacity(0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).shadowColor.withOpacity(0.2),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with progress
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.secondary,
                          Theme.of(context).colorScheme.tertiary,
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_forward,
                      color: Theme.of(context).colorScheme.onSecondary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Next Exercise',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                        Text(
                          'Get ready for the next movement',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: widget.onContinue,
                    icon: const Icon(Icons.skip_next, size: 18),
                    label: const Text('Continue'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                      foregroundColor: Theme.of(context).colorScheme.onSecondary,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Auto-progress indicator
              AnimatedBuilder(
                animation: _progressAnimation,
                builder: (context, child) {
                  return LinearProgressIndicator(
                    value: _progressAnimation.value,
                    backgroundColor: Theme.of(context).colorScheme.secondary.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.secondary,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  );
                },
              ),
              
              const SizedBox(height: 20),
              
              // Exercise name with enhanced styling
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
                      Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.5),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                  ),
                ),
                child: Text(
                  widget.nextExercise,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Animation preview with enhanced styling
              if (ExerciseAnimationData.hasAnimationForExercise(widget.nextExercise))
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                  child: ExerciseAnimationWidget(
                    exerciseName: widget.nextExercise,
                    width: 280,
                    height: 200,
                    autoPlay: true,
                    showControls: false,
                    showDescription: true,
                  ),
                )
              else
                Container(
                  width: 280,
                  height: 200,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                        Theme.of(context).colorScheme.surfaceContainer,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.fitness_center,
                        size: 64,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Get ready!',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
