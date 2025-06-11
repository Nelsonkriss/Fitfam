import 'dart:async';
import 'package:flutter/material.dart';
import 'package:workout_planner/models/exercise_animation_data.dart';

/// Enhanced Exercise Animation Widget with smooth automatic animations
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
  
  // Enhanced animation controllers
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimationControllers();
    _loadAnimation();
  }
  
  void _initializeAnimationControllers() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );
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
    super.dispose();
  }

  void _loadAnimation() {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    print('[ExerciseAnimationWidget] Loading animation for: "${widget.exerciseName}"');
    
    _animationData = ExerciseAnimationData.getExerciseAnimation(widget.exerciseName);
    
    if (_animationData == null) {
      print('[ExerciseAnimationWidget] No animation found for: "${widget.exerciseName}"');
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

    // Start entrance animations
    _scaleController.forward();
    _fadeController.forward();

    if (widget.autoPlay) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _startAnimation();
      });
    }
  }

  void _startAnimation() {
    if (_animationData == null || _isPlaying) return;
    
    // Safety check: Don't start animation if no images available
    if (_animationData!.imagePaths.isEmpty) {
      print('[ExerciseAnimationWidget] Cannot start animation: No images available');
      return;
    }

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
    if (_animationData == null || _animationData!.imagePaths.isEmpty) return;
    setState(() {
      _currentImageIndex = (_currentImageIndex + 1) % _animationData!.imagePaths.length;
    });
  }

  void _previousStep() {
    if (_animationData == null || _animationData!.imagePaths.isEmpty) return;
    setState(() {
      _currentImageIndex = _currentImageIndex == 0 
          ? _animationData!.imagePaths.length - 1 
          : _currentImageIndex - 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: widget.showControls ? _toggleAnimation : null,
            child: _buildAnimationDisplay(),
          ),
          if (widget.showControls) _buildControls(),
          if (widget.showDescription) _buildDescription(),
        ],
      ),
    );
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
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Handle both animated and frame-based animations
                if (_animationData!.isAnimated)
                  // Single animated .webp file - Flutter natively supports WebP
                  Image.asset(
                    _animationData!.animatedImagePath!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      print('Error loading animated WEBP: $error');
                      return Container(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: const Center(
                          child: Icon(Icons.broken_image, size: 48),
                        ),
                      );
                    },
                  )
                else
                  // Frame-based animation
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Image.asset(
                      _animationData!.imagePaths[_currentImageIndex],
                      key: ValueKey(_currentImageIndex),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: const Center(
                            child: Icon(Icons.broken_image, size: 48),
                          ),
                        );
                      },
                    ),
                  ),
                
                // Step indicator (only for frame-based animations)
                if (!_animationData!.isAnimated)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(12),
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
                
                // Animated indicator for single animated files
                if (_animationData!.isAnimated)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.play_circle_filled,
                            color: Colors.white,
                            size: 12,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'ANIMATED',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                
                // Play overlay (only for frame-based animations when not playing)
                if (!_animationData!.isAnimated && !_isPlaying && widget.showControls)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withOpacity(0.4),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.play_arrow,
                            size: 32,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControls() {
    if (_animationData == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: _previousStep,
            icon: const Icon(Icons.skip_previous),
            iconSize: 20,
          ),
          IconButton(
            onPressed: _toggleAnimation,
            icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
            iconSize: 24,
          ),
          IconButton(
            onPressed: _nextStep,
            icon: const Icon(Icons.skip_next),
            iconSize: 20,
          ),
          IconButton(
            onPressed: _resetAnimation,
            icon: const Icon(Icons.replay),
            iconSize: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildDescription() {
    if (_animationData?.description == null) return const SizedBox.shrink();

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
}

/// Compact version of the Exercise Animation Widget for smaller spaces
class CompactExerciseAnimationWidget extends StatefulWidget {
  final String exerciseName;
  final double size;
  final bool autoPlay;

  const CompactExerciseAnimationWidget({
    super.key,
    required this.exerciseName,
    this.size = 120,
    this.autoPlay = true,
  });

  @override
  State<CompactExerciseAnimationWidget> createState() => _CompactExerciseAnimationWidgetState();
}

class _CompactExerciseAnimationWidgetState extends State<CompactExerciseAnimationWidget>
    with TickerProviderStateMixin {
  ExerciseAnimationData? _animationData;
  int _currentImageIndex = 0;
  Timer? _animationTimer;
  bool _isPlaying = false;
  bool _isLoading = true;
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initializePulseController();
    _loadAnimation();
  }
  
  void _initializePulseController() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
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
    _pulseController.dispose();
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

    if (widget.autoPlay && _animationData != null) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _startAnimation();
      });
    }
  }

  void _startAnimation() {
    if (_animationData == null || _isPlaying) return;
    
    // Safety check: Don't start animation if no images available
    if (_animationData!.imagePaths.isEmpty) {
      print('[CompactExerciseAnimationWidget] Cannot start animation: No images available');
      return;
    }

    setState(() {
      _isPlaying = true;
    });

    _pulseController.repeat(reverse: true);

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
    _pulseController.stop();
    setState(() {
      _isPlaying = false;
    });
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
          child: CircularProgressIndicator(),
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
        child: Center(
          child: Icon(
            Icons.fitness_center,
            size: widget.size * 0.4,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return ScaleTransition(
      scale: _pulseAnimation,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Handle both animated and frame-based animations
              if (_animationData!.isAnimated)
                // Single animated .webp file - Flutter natively supports WebP
                Image.asset(
                  _animationData!.animatedImagePath!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    print('Error loading compact animated WEBP: $error');
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
                )
              else
                // Frame-based animation
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
              
              // Animated indicator for single animated files
              if (_animationData!.isAnimated)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.play_circle_filled,
                      color: Colors.white,
                      size: 10,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
