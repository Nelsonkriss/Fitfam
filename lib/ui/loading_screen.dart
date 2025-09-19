import 'package:flutter/material.dart';
import 'design_system.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  _LoadingScreenState createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FadeTransition(
                opacity: _animation,
                child: Image.asset(
                  // Prefer the exact Android mipmap-xxxhdpi launcher icon
                  'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png',
                  width: 120.0,
                  height: 120.0,
                  errorBuilder: (context, error, stack) {
                    // Fallback to bundled asset for non-Android platforms or if path changes
                    return Image.asset(
                      'assets/ic_launcher.png',
                      width: 120.0,
                      height: 120.0,
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Getting your workout ready...',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 18.0,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
