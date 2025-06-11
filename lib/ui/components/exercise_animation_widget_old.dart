import 'dart:async';
import 'package:flutter/material.dart';
import 'package:workout_planner/models/exercise_animation_data.dart';

/// Widget that displays animated exercise demonstrations
class ExerciseAnimationWidget extends StatefulWidget {
  final String exerciseName;
  final double? width;
  final double? height;
  final bool autoPlay;
  final bool showControls;
  final bool showDescription;
  final VoidCallback? onAnimationComplete;

  const ExerciseAnimationWidget({
    super.key,
    required this.exerciseName,
    this.width,
    this.height,
    this.autoPlay = true,
    this.showControls = true,
    this.showDescription = true,
    this.onAnimationComplete,
  });

  @override
  State<ExerciseAnimationWidget> createState() => _ExerciseAnimationWidgetState();
}

class _ExerciseAnimationWidgetState extends State<ExerciseAnimationWidget>
    with TickerProviderStateMixin {
  ExerciseAnimationData? _animationData;
  int _currentImageIndex = 0;
  Timer? _animationTimer;
  bool _isPlaying = false;
  bool _isLoading = true;
  String? _errorMessage;
  
  // Enhanced animation controllers inspired by Material Design
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;
  
  // Smooth interpolation curves based on com.axiommobile implementation
  static const Curve _fastOutSlowIn = Cubic(0.4, 0.0, 0.2, 1.0);
  static const Curve _emphasizedEasing = Cubic(0.2, 0.0, 0.0, 1.0);
  static const Curve _standardEasing = Cubic(0.2, 0.0, 0.2, 1.0);

  @override
  void initState() {
    super.initState();
    _initializeAnimationControllers();
    _loadAnimation();
  }
  
  void _initializeAnimationControllers() {
    // Fade animation for smooth transitions between frames
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: _fastOutSlowIn),
    );
    
    // Scale animation for smooth entry and emphasis
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: _emphasizedEasing),
    );
    
    // Slide animation for frame transitions
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.3, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController, 
      curve: _standardEasing,
    ));
  }

  @override
  void didUpdateWidget(ExerciseAnimationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exerciseName != widget.exerciseName) {
      _loadAnimation();
    }
  }

  @override
  void dispose() {
    _animationTimer?.cancel();
    _fadeController.dispose();
    _scaleController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _loadAnimation() {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Debug logging
    print('[ExerciseAnimationWidget] Loading animation for: "${widget.exerciseName}"');
    
    _animationData = ExerciseAnimationData.getExerciseAnimation(widget.exerciseName);
    
    if (_animationData == null) {
      print('[ExerciseAnimationWidget] No animation found for: "${widget.exerciseName}"');
      print('[ExerciseAnimationWidget] Available exercises: ${ExerciseAnimationData.getAllExerciseNames()}');
      setState(() {
        _isLoading = false;
        _errorMessage = 'No animation available for this exercise';
      });
      return;
    }

    print('[ExerciseAnimationWidget] Animation found! Images: ${_animationData!.imagePaths}');
    
    setState(() {
      _isLoading = false;
      _currentImageIndex = 0;
    });

    // Start entrance animations with staggered timing for smooth effect
    _scaleController.forward();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _fadeController.forward();
        _slideController.forward();
      }
    });

    if (widget.autoPlay) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _startAnimation();
      });
    }
  }

  void _startAnimation() {
    if (_animationData == null || _isPlaying) return;

    setState(() {
      _isPlaying = true;
    });

    _animationTimer = Timer.periodic(_animationData!.frameDuration, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _currentImageIndex = (_currentImageIndex + 1) % _animationData!.imagePaths.length;
      });

      // If we've completed one full cycle, call completion callback
      if (_currentImageIndex == 0) {
        widget.onAnimationComplete?.call();
      }
    });
  }

  void _stopAnimation() {
    _animationTimer?.cancel();
    setState(() {
      _isPlaying = false;
    });
  }

  void _toggleAnimation() {
    if (_isPlaying) {
      _stopAnimation();
    } else {
      _startAnimation();
    }
  }

  void _resetAnimation() {
    _stopAnimation();
    setState(() {
      _currentImageIndex = 0;
    });
  }

  void _nextStep() {
    if (_animationData == null) return;
    setState(() {
      _currentImageIndex = (_currentImageIndex + 1) % _animationData!.imagePaths.length;
    });
  }

  void _previousStep() {
    if (_animationData == null) return;
    setState(() {
      _currentImageIndex = _currentImageIndex == 0 
          ? _animationData!.imagePaths.length - 1 
          : _currentImageIndex - 1;
    });
  }

  Widget _buildAnimationDisplay() {
    if (_isLoading) {
      return Container(
        width: widget.width ?? 300,
        height: widget.height ?? 200,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Container(
        width: widget.width ?? 300,
        height: widget.height ?? 200,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
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
                _errorMessage!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ScaleTransition(
      scale: _scaleAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Container(
            width: widget.width ?? 300,
            height: widget.height ?? 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).shadowColor.withOpacity(0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: Theme.of(context).shadowColor.withOpacity(0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.1, 0),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(
                            parent: animation,
                            curve: _fastOutSlowIn,
                          )),
                          child: child,
                        ),
                      );
                    },
                    child: Image.asset(
                      _animationData!.imagePaths[_currentImageIndex],
                      key: ValueKey(_currentImageIndex),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.broken_image,
                                  size: 48,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Image not found',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Enhanced step indicator with animation
                  Positioned(
                    top: 8,
                    right: 8,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '${_currentImageIndex + 1}/${_animationData!.imagePaths.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  // Enhanced play/pause overlay with smooth animations
                  if (!_isPlaying && widget.showControls)
                    Positioned.fill(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        color: Colors.black.withValues(alpha: 0.4),
                        child: Center(
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.8, end: 1.0),
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.elasticOut,
                            builder: (context, scale, child) {
                              return Transform.scale(
                                scale: scale,
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.95),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                                        blurRadius: 12,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.play_arrow,
                                    size: 32,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControls() {
    if (!widget.showControls || _animationData == null) {
      return const SizedBox.shrink();
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: _emphasizedEasing,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).shadowColor.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildControlButton(
                    onPressed: _previousStep,
                    icon: Icons.skip_previous,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  _buildControlButton(
                    onPressed: _toggleAnimation,
                    icon: _isPlaying ? Icons.pause : Icons.play_arrow,
                    size: 24,
                    isPrimary: true,
                  ),
                  const SizedBox(width: 8),
                  _buildControlButton(
                    onPressed: _nextStep,
                    icon: Icons.skip_next,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  _buildControlButton(
                    onPressed: _resetAnimation,
                    icon: Icons.replay,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildControlButton({
    required VoidCallback onPressed,
    required IconData icon,
    required double size,
    bool isPrimary = false,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isPrimary 
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, animation) {
            return ScaleTransition(
              scale: animation,
              child: child,
            );
          },
          child: Icon(
            icon,
            key: ValueKey(icon),
            color: isPrimary 
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        iconSize: size,
        constraints: BoxConstraints(
          minWidth: isPrimary ? 36 : 32,
          minHeight: isPrimary ? 36 : 32,
        ),
      ),
    );
  }

  Widget _buildDescription() {
    if (!widget.showDescription || _animationData?.description == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _animationData!.description,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: widget.showControls ? _toggleAnimation : null,
          child: _buildAnimationDisplay(),
        ),
        _buildControls(),
        _buildDescription(),
      ],
    );
  }
}

/// Compact version of the exercise animation widget for smaller spaces
class CompactExerciseAnimationWidget extends StatefulWidget {
  final String exerciseName;
  final double size;
  final bool autoPlay;

  const CompactExerciseAnimationWidget({
    super.key,
    required this.exerciseName,
    this.size = 80,
    this.autoPlay = true,
  });

  @override
  State<CompactExerciseAnimationWidget> createState() => _CompactExerciseAnimationWidgetState();
}

class _CompactExerciseAnimationWidgetState extends State<CompactExerciseAnimationWidget> {
  ExerciseAnimationData? _animationData;
  int _currentImageIndex = 0;
  Timer? _animationTimer;
  bool _isPlaying = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAnimation();
  }

  @override
  void didUpdateWidget(CompactExerciseAnimationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exerciseName != widget.exerciseName) {
      _loadAnimation();
    }
  }

  @override
  void dispose() {
    _animationTimer?.cancel();
    super.dispose();
  }

  void _loadAnimation() {
    setState(() {
      _isLoading = true;
    });

    _animationData = ExerciseAnimationData.getExerciseAnimation(widget.exerciseName);
    
    setState(() {
      _isLoading = false;
      _currentImageIndex = 0;
    });

    // Start animation immediately if autoPlay is enabled and we have animation data
    if (widget.autoPlay && _animationData != null && mounted) {
      // Small delay to ensure widget is fully built
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _startAnimation();
      });
    }
  }

  void _startAnimation() {
    if (_animationData == null || _isPlaying || !mounted) return;

    setState(() {
      _isPlaying = true;
    });

    _animationTimer = Timer.periodic(_animationData!.frameDuration, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _currentImageIndex = (_currentImageIndex + 1) % _animationData!.imagePaths.length;
      });
    });
  }

  void _stopAnimation() {
    _animationTimer?.cancel();
    if (mounted) {
      setState(() {
        _isPlaying = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_animationData == null) {
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.fitness_center,
              size: widget.size * 0.3,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 4),
            Text(
              'No Anim',
              style: TextStyle(
                fontSize: widget.size * 0.12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              _animationData!.imagePaths[_currentImageIndex],
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Center(
                    child: Icon(
                      Icons.broken_image,
                      size: widget.size * 0.3,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              },
            ),
            // Simple step indicator
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_currentImageIndex + 1}/${_animationData!.imagePaths.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            // Play indicator when not playing
            if (!_isPlaying && widget.autoPlay)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.3),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.play_arrow,
                        size: widget.size * 0.2,
                        color: Theme.of(context).colorScheme.primary,
                      ),
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
