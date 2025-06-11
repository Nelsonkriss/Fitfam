import 'dart:async';
import 'package:flutter/material.dart';
import 'package:workout_planner/models/exercise_animation_data.dart';
import 'package:workout_planner/ui/components/exercise_animation_widget.dart';

/// Rest period animation widget that shows exercise form during rest
class RestPeriodAnimationWidget extends StatefulWidget {
  final String exerciseName;
  final Duration restDuration;
  final Duration remainingTime;
  final VoidCallback? onSkipRest;

  const RestPeriodAnimationWidget({
    super.key,
    required this.exerciseName,
    required this.restDuration,
    required this.remainingTime,
    this.onSkipRest,
  });

  @override
  State<RestPeriodAnimationWidget> createState() => _RestPeriodAnimationWidgetState();
}

class _RestPeriodAnimationWidgetState extends State<RestPeriodAnimationWidget>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = 1.0 - (widget.remainingTime.inSeconds / widget.restDuration.inSeconds);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.withOpacity(0.1),
            Colors.blue.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.blue.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.timer,
                        color: Colors.blue,
                        size: 20,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rest Period',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.blue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Review form for next set',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.onSkipRest != null)
                TextButton(
                  onPressed: widget.onSkipRest,
                  child: const Text('Skip'),
                ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Progress bar
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.blue.withOpacity(0.2),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
          
          const SizedBox(height: 16),
          
          // Animation
          if (ExerciseAnimationData.hasAnimationForExercise(widget.exerciseName))
            ExerciseAnimationWidget(
              exerciseName: widget.exerciseName,
              width: 200,
              height: 150,
              autoPlay: true,
              showControls: true,
              showDescription: false,
            )
          else
            Container(
              width: 200,
              height: 150,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.fitness_center,
                    size: 48,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.exerciseName,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Quick form reminder widget shown before starting a set
class SetPreparationAnimationWidget extends StatefulWidget {
  final String exerciseName;
  final int setNumber;
  final int targetReps;
  final double targetWeight;
  final VoidCallback onReady;
  final VoidCallback onSkip;

  const SetPreparationAnimationWidget({
    super.key,
    required this.exerciseName,
    required this.setNumber,
    required this.targetReps,
    required this.targetWeight,
    required this.onReady,
    required this.onSkip,
  });

  @override
  State<SetPreparationAnimationWidget> createState() => _SetPreparationAnimationWidgetState();
}

class _SetPreparationAnimationWidgetState extends State<SetPreparationAnimationWidget>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    ));

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _slideController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _scaleController.forward();
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
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
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.fitness_center,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Set ${widget.setNumber}',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.exerciseName,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Target info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text(
                          '${widget.targetReps}',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        Text(
                          'Reps',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    Column(
                      children: [
                        Text(
                          '${widget.targetWeight} kg',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                        Text(
                          'Weight',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Animation
              if (ExerciseAnimationData.hasAnimationForExercise(widget.exerciseName))
                ExerciseAnimationWidget(
                  exerciseName: widget.exerciseName,
                  width: 250,
                  height: 180,
                  autoPlay: true,
                  showControls: false,
                  showDescription: false,
                ),
              
              const SizedBox(height: 20),
              
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onSkip,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Skip'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: widget.onReady,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      ),
                      child: const Text('Ready to Start'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Animated feedback widget for set completion
class SetCompletionAnimationWidget extends StatefulWidget {
  final String exerciseName;
  final int completedReps;
  final double completedWeight;
  final bool isPersonalRecord;
  final VoidCallback onContinue;

  const SetCompletionAnimationWidget({
    super.key,
    required this.exerciseName,
    required this.completedReps,
    required this.completedWeight,
    required this.isPersonalRecord,
    required this.onContinue,
  });

  @override
  State<SetCompletionAnimationWidget> createState() => _SetCompletionAnimationWidgetState();
}

class _SetCompletionAnimationWidgetState extends State<SetCompletionAnimationWidget>
    with TickerProviderStateMixin {
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;
  late AnimationController _confettiController;
  late Animation<double> _confettiAnimation;

  @override
  void initState() {
    super.initState();
    
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _bounceAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.elasticOut),
    );

    _confettiController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _confettiAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _confettiController, curve: Curves.easeOut),
    );

    _bounceController.forward();
    if (widget.isPersonalRecord) {
      _confettiController.forward();
    }

    // Auto-dismiss after 2 seconds
    Timer(const Duration(seconds: 2), () {
      if (mounted) widget.onContinue();
    });
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _bounceAnimation,
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: widget.isPersonalRecord 
              ? Colors.amber.withOpacity(0.1)
              : Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: widget.isPersonalRecord 
                ? Colors.amber.withOpacity(0.5)
                : Colors.green.withOpacity(0.5),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Success icon with animation
            AnimatedBuilder(
              animation: _confettiAnimation,
              builder: (context, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    if (widget.isPersonalRecord)
                      ...List.generate(8, (index) {
                        final angle = (index * 45) * (3.14159 / 180);
                        return Transform.translate(
                          offset: Offset(
                            30 * _confettiAnimation.value * (index.isEven ? 1 : -1),
                            30 * _confettiAnimation.value * (index < 4 ? -1 : 1),
                          ),
                          child: Transform.rotate(
                            angle: angle * _confettiAnimation.value,
                            child: Icon(
                              Icons.star,
                              color: Colors.amber.withOpacity(1 - _confettiAnimation.value),
                              size: 16,
                            ),
                          ),
                        );
                      }),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: widget.isPersonalRecord ? Colors.amber : Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.isPersonalRecord ? Icons.emoji_events : Icons.check,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ],
                );
              },
            ),
            
            const SizedBox(height: 16),
            
            // Success message
            Text(
              widget.isPersonalRecord ? 'Personal Record!' : 'Set Complete!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: widget.isPersonalRecord ? Colors.amber[700] : Colors.green[700],
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Completed stats
            Text(
              '${widget.completedReps} reps @ ${widget.completedWeight} kg',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Continue button
            ElevatedButton(
              onPressed: widget.onContinue,
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.isPersonalRecord ? Colors.amber : Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Exercise transition widget that shows next exercise animation
class ExerciseTransitionWidget extends StatefulWidget {
  final String currentExercise;
  final String nextExercise;
  final VoidCallback onContinue;

  const ExerciseTransitionWidget({
    super.key,
    required this.currentExercise,
    required this.nextExercise,
    required this.onContinue,
  });

  @override
  State<ExerciseTransitionWidget> createState() => _ExerciseTransitionWidgetState();
}

class _ExerciseTransitionWidgetState extends State<ExerciseTransitionWidget>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _slideController.forward();

    // Auto-continue after 3 seconds
    Timer(const Duration(seconds: 3), () {
      if (mounted) widget.onContinue();
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
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
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_forward,
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Next Exercise',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Get ready for the next movement',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: widget.onContinue,
                  child: const Text('Continue'),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Exercise name
            Text(
              widget.nextExercise,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 16),
            
            // Animation preview
            if (ExerciseAnimationData.hasAnimationForExercise(widget.nextExercise))
              ExerciseAnimationWidget(
                exerciseName: widget.nextExercise,
                width: 250,
                height: 180,
                autoPlay: true,
                showControls: false,
                showDescription: true,
              )
            else
              Container(
                width: 250,
                height: 180,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.fitness_center,
                      size: 48,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Get ready!',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
