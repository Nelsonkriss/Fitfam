import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:workout_planner/models/user_profile.dart';
import 'package:workout_planner/resource/shared_prefs_provider.dart';
import 'package:workout_planner/resource/firebase_provider.dart';

class OnboardingPage extends StatefulWidget {
  final VoidCallback onOnboardingComplete;
  
  const OnboardingPage({
    super.key,
    required this.onOnboardingComplete,
  });

  @override
  _OnboardingPageState createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  
  // Form controllers
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  FitnessLevel _selectedFitnessLevel = FitnessLevel.beginner;
  
  // Form validation
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _pageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _completeOnboarding() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Create user profile
      final userProfile = UserProfile.create(
        height: double.parse(_heightController.text),
        weight: double.parse(_weightController.text),
        fitnessLevel: _selectedFitnessLevel,
      );

      // Save to local storage
      await context.read<SharedPrefsProvider>().setUserProfile(userProfile);
      await context.read<SharedPrefsProvider>().setOnboardingCompleted(true);

      // Try to sync to cloud if user is signed in
      try {
        final firebaseProvider = context.read<FirebaseProvider>();
        final user = firebaseProvider.currentUser;
        if (user != null) {
          // Save to Firebase (you'll need to implement this in FirebaseProvider)
          await firebaseProvider.saveUserProfile(userProfile);
        }
      } catch (e) {
        debugPrint("Failed to sync profile to cloud: $e");
        // Continue anyway - local storage is sufficient
      }

      // Call the completion callback
      if (mounted) {
        widget.onOnboardingComplete();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _currentPage > 0 ? _previousPage : null,
                    icon: const Icon(Icons.arrow_back),
                  ),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: (_currentPage + 1) / 3,
                      backgroundColor: Colors.grey.shade300,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  Text(
                    '${_currentPage + 1}/3',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            // Page content
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                children: [
                  _buildWelcomePage(),
                  _buildPhysicalInfoPage(),
                  _buildFitnessLevelPage(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomePage() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.fitness_center,
            size: 120,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 32),
          Text(
            'Welcome to Workout Planner!',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Let\'s set up your profile to create personalized workout routines tailored just for you.',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          ElevatedButton(
            onPressed: _nextPage,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
            child: const Text('Get Started'),
          ),
        ],
      ),
    );
  }

  Widget _buildPhysicalInfoPage() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Physical Information',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This helps us calculate your BMI and suggest appropriate starting weights.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _heightController,
              decoration: const InputDecoration(
                labelText: 'Height (cm)',
                hintText: 'e.g., 175',
                prefixIcon: Icon(Icons.height),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
              ],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your height';
                }
                final height = double.tryParse(value);
                if (height == null || height < 100 || height > 250) {
                  return 'Please enter a valid height (100-250 cm)';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _weightController,
              decoration: const InputDecoration(
                labelText: 'Weight (kg)',
                hintText: 'e.g., 70',
                prefixIcon: Icon(Icons.monitor_weight),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
              ],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your weight';
                }
                final weight = double.tryParse(value);
                if (weight == null || weight < 30 || weight > 300) {
                  return 'Please enter a valid weight (30-300 kg)';
                }
                return null;
              },
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  _nextPage();
                }
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFitnessLevelPage() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Fitness Level',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This helps us recommend appropriate exercises and starting weights.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 32),
          ...FitnessLevel.values.map((level) => _buildFitnessLevelCard(level)),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _isLoading ? null : _completeOnboarding,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Complete Setup'),
          ),
        ],
      ),
    );
  }

  Widget _buildFitnessLevelCard(FitnessLevel level) {
    final isSelected = _selectedFitnessLevel == level;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedFitnessLevel = level;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected 
                  ? Theme.of(context).colorScheme.primary 
                  : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
            color: isSelected 
                ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                : null,
          ),
          child: Row(
            children: [
              Icon(
                _getFitnessLevelIcon(level),
                color: isSelected 
                    ? Theme.of(context).colorScheme.primary 
                    : Colors.grey.shade600,
                size: 32,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      level.displayName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isSelected 
                            ? Theme.of(context).colorScheme.primary 
                            : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      level.description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: Theme.of(context).colorScheme.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getFitnessLevelIcon(FitnessLevel level) {
    switch (level) {
      case FitnessLevel.beginner:
        return Icons.directions_walk;
      case FitnessLevel.intermediate:
        return Icons.directions_run;
      case FitnessLevel.advanced:
        return Icons.fitness_center;
    }
  }
}
