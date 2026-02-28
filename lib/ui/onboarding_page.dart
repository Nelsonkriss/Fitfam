import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:workout_planner/models/user_profile.dart';
import 'package:workout_planner/resource/shared_prefs_provider.dart';
import 'package:workout_planner/resource/firebase_provider.dart';
import 'design_system.dart';

class OnboardingPage extends StatefulWidget {
  final VoidCallback onOnboardingComplete;

  const OnboardingPage({super.key, required this.onOnboardingComplete});

  @override
  _OnboardingPageState createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  FitnessLevel _selectedFitnessLevel = FitnessLevel.beginner;
  final Set<FitnessGoal> _selectedFitnessGoals = {FitnessGoal.buildMuscle};
  final Set<AvailableEquipment> _selectedEquipment = {};

  final GlobalKey<FormState> _nameFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isSigningIn = false;
  String _weightUnit = 'kg';

  final Map<FitnessGoal, String> _goalDescriptions = const {
    FitnessGoal.buildMuscle: 'Hypertrophy focus with progressive overload.',
    FitnessGoal.loseWeight: 'Efficient sessions for fat loss and consistency.',
    FitnessGoal.improveStrength: 'Lower reps, heavier lifts, longer rest.',
    FitnessGoal.improveEndurance: 'Higher reps, shorter rest, steady volume.',
    FitnessGoal.maintainFitness: 'Balanced mix to stay strong and mobile.',
  };

  final Map<FitnessGoal, IconData> _goalIcons = const {
    FitnessGoal.buildMuscle: Icons.fitness_center,
    FitnessGoal.loseWeight: Icons.local_fire_department,
    FitnessGoal.improveStrength: Icons.bolt,
    FitnessGoal.improveEndurance: Icons.directions_run,
    FitnessGoal.maintainFitness: Icons.spa,
  };

  final Map<AvailableEquipment, IconData> _equipmentIcons = const {
    AvailableEquipment.barbell: Icons.sports_gymnastics,
    AvailableEquipment.dumbbell: Icons.fitness_center_outlined,
    AvailableEquipment.kettlebell: Icons.sports_handball,
    AvailableEquipment.bodyweight: Icons.accessibility_new,
    AvailableEquipment.machine: Icons.precision_manufacturing,
    AvailableEquipment.bands: Icons.auto_graph,
    AvailableEquipment.other: Icons.more_horiz,
  };

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onInputChanged);
    _heightController.addListener(_onInputChanged);
    _weightController.addListener(_onInputChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPrefs());
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.removeListener(_onInputChanged);
    _heightController.removeListener(_onInputChanged);
    _weightController.removeListener(_onInputChanged);
    _nameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    try {
      final unit = await context.read<SharedPrefsProvider>().getWeightUnit();
      final firebaseUser = context.read<FirebaseProvider>().currentUser;
      if (!mounted) return;
      setState(() {
        _weightUnit = unit;
      });
      if (_nameController.text.trim().isEmpty) {
        final displayName = firebaseUser?.displayName?.trim();
        if (displayName != null && displayName.isNotEmpty) {
          _nameController.text = displayName;
        } else if (firebaseUser?.email != null &&
            firebaseUser!.email!.contains('@')) {
          _nameController.text = firebaseUser.email!.split('@').first;
        }
      }
    } catch (_) {}
  }

  void _onInputChanged() {
    if (mounted) setState(() {});
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _jumpToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
    );
  }

  void _setWeightUnit(String unit) {
    if (_weightUnit == unit) return;
    final currentWeight = double.tryParse(_weightController.text);
    if (currentWeight != null && currentWeight > 0) {
      final converted =
          unit == 'lb' ? currentWeight * 2.20462 : currentWeight / 2.20462;
      _weightController.text = converted.toStringAsFixed(1);
    }
    setState(() {
      _weightUnit = unit;
    });
  }

  double? _parseHeightCm() {
    return double.tryParse(_heightController.text);
  }

  double? _parseWeightInput() {
    return double.tryParse(_weightController.text);
  }

  double? _weightToKg(double? weight) {
    if (weight == null) return null;
    return _weightUnit == 'lb' ? weight / 2.20462 : weight;
  }

  int _recommendedFrequency() {
    switch (_selectedFitnessLevel) {
      case FitnessLevel.beginner:
        return 3;
      case FitnessLevel.intermediate:
        return 4;
      case FitnessLevel.advanced:
        return 5;
    }
  }

  List<FitnessGoal> _orderedSelectedGoals() {
    return FitnessGoal.values.where(_selectedFitnessGoals.contains).toList();
  }

  FitnessGoal get _primaryFitnessGoal {
    final orderedGoals = _orderedSelectedGoals();
    if (orderedGoals.isEmpty) return FitnessGoal.buildMuscle;
    return orderedGoals.first;
  }

  String get _selectedGoalsLabel {
    final orderedGoals = _orderedSelectedGoals();
    if (orderedGoals.isEmpty) return 'Not selected';
    return orderedGoals.map((goal) => goal.displayName).join(', ');
  }

  Future<void> _handleSignIn(SignInMethod method) async {
    if (_isSigningIn) return;
    setState(() {
      _isSigningIn = true;
    });

    try {
      final firebaseProvider = context.read<FirebaseProvider>();
      final user =
          method == SignInMethod.google
              ? await firebaseProvider.signInWithGoogle()
              : await firebaseProvider.signInWithApple();

      if (!mounted) return;

      if (user == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Sign in cancelled.')));
        return;
      }

      if (_nameController.text.trim().isEmpty) {
        final displayName = user.displayName?.trim();
        if (displayName != null && displayName.isNotEmpty) {
          _nameController.text = displayName;
        } else if (user.email != null && user.email!.contains('@')) {
          _nameController.text = user.email!.split('@').first;
        }
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Signed in successfully.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sign in failed: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSigningIn = false;
        });
      }
    }
  }

  String _firstName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '';
    final parts = trimmed.split(RegExp(r'\s+'));
    return parts.first;
  }

  String? _validateName(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Please enter your name';
    if (trimmed.length < 2) return 'Name is too short';
    return null;
  }

  String? _validateHeight(String? value) {
    if (value == null || value.isEmpty) return 'Please enter your height';
    final height = double.tryParse(value);
    if (height == null || height < 100 || height > 250) {
      return 'Enter a valid height (100-250 cm)';
    }
    return null;
  }

  String? _validateWeight(String? value) {
    if (value == null || value.isEmpty) return 'Please enter your weight';
    final weight = double.tryParse(value);
    final weightKg = _weightToKg(weight);
    if (weight == null || weightKg == null || weightKg < 30 || weightKg > 300) {
      return 'Enter a valid weight';
    }
    return null;
  }

  Future<void> _completeOnboarding() async {
    final name = _nameController.text.trim();
    final nameValid =
        (_nameFormKey.currentState?.validate() ??
            (_validateName(name) == null)) &&
        name.isNotEmpty;
    if (!nameValid) {
      _jumpToPage(1);
      return;
    }

    final physicalInfoValid =
        _formKey.currentState?.validate() ??
        (_validateHeight(_heightController.text) == null &&
            _validateWeight(_weightController.text) == null);
    if (!physicalInfoValid) {
      _jumpToPage(2);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final height = double.parse(_heightController.text);
      final weightInput = double.parse(_weightController.text);
      final weightKg = _weightToKg(weightInput) ?? weightInput;

      final userProfile = UserProfile.create(
        height: height,
        weight: weightKg,
        fitnessLevel: _selectedFitnessLevel,
        fitnessGoal: _primaryFitnessGoal,
        fitnessGoals: _orderedSelectedGoals(),
        availableEquipment: _selectedEquipment.toList(),
        displayName: name.isEmpty ? null : name,
      );

      final prefs = context.read<SharedPrefsProvider>();
      await prefs.setUserProfile(userProfile);
      await prefs.setOnboardingCompleted(true);
      await prefs.setWeightUnit(_weightUnit);
      await prefs.setWeightIncrement(_weightUnit == 'lb' ? 5.0 : 2.5);
      await prefs.setWeeklyAmount(userProfile.recommendedWorkoutFrequency);

      try {
        final firebaseProvider = context.read<FirebaseProvider>();
        final user = firebaseProvider.currentUser;
        if (user != null) {
          if (name.isNotEmpty &&
              (user.displayName == null ||
                  user.displayName!.trim().isEmpty ||
                  user.displayName != name)) {
            await user.updateDisplayName(name);
          }
          await firebaseProvider.saveUserProfile(userProfile);
        }
      } catch (e) {
        debugPrint("Failed to sync profile to cloud: $e");
      }

      if (mounted) {
        widget.onOnboardingComplete();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving profile: $e'),
            backgroundColor: AppColors.danger,
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
    final gradient = _pageGradients[_currentPage];

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.background,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 450),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradient,
            ),
          ),
          child: Stack(
            children: [
              _buildAmbientGlow(),
              SafeArea(
                child: Column(
                  children: [
                    _buildTopBar(),
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        onPageChanged: (index) {
                          setState(() {
                            _currentPage = index;
                          });
                        },
                        itemCount: _pages.length,
                        physics: const BouncingScrollPhysics(),
                        itemBuilder: (context, index) {
                          return _buildAnimatedPage(index, _pages[index]());
                        },
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

  Widget _buildAmbientGlow() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            Positioned(
              top: -80,
              left: -40,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.accent.withOpacity(0.25),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -120,
              right: -40,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.accentAlt.withOpacity(0.2),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: _currentPage > 0 ? _previousPage : null,
            icon: const Icon(Icons.arrow_back, color: AppColors.onSurface),
          ),
          Expanded(child: _buildProgressDots()),
          Text(
            '${_currentPage + 1}/${_pages.length}',
            style: AppText.caption.copyWith(color: AppColors.onSurfaceSubtle),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_pages.length, (index) {
        final isActive = index == _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 8,
          width: isActive ? 28 : 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: isActive ? AppColors.accentAlt : Colors.white24,
          ),
        );
      }),
    );
  }

  Widget _buildAnimatedPage(int index, Widget child) {
    return AnimatedBuilder(
      animation: _pageController,
      builder: (context, _) {
        final page =
            _pageController.hasClients
                ? (_pageController.page ?? _currentPage.toDouble())
                : _currentPage.toDouble();
        final delta = (page - index).abs().clamp(0.0, 1.0);
        final opacity = (1 - delta * 0.35).clamp(0.0, 1.0);
        final translate = 30 * delta;
        final scale = 1 - (delta * 0.04);
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, translate),
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
    );
  }

  List<Widget Function()> get _pages => [
    _buildWelcomePage,
    _buildIdentityPage,
    _buildPhysicalInfoPage,
    _buildFitnessLevelPage,
    _buildFitnessGoalPage,
    _buildEquipmentPage,
  ];

  List<List<Color>> get _pageGradients => const [
    [Color(0xFF10121A), Color(0xFF0E0F12)],
    [Color(0xFF11141A), Color(0xFF1B1E24)],
    [Color(0xFF0E1218), Color(0xFF141B22)],
    [Color(0xFF0F1117), Color(0xFF1A1E28)],
    [Color(0xFF10121A), Color(0xFF1A1B20)],
    [Color(0xFF0D1014), Color(0xFF132028)],
  ];

  Widget _scrollablePage({required Widget child}) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return LayoutBuilder(
      builder: (context, constraints) {
        final minHeight = (constraints.maxHeight - bottomInset).clamp(
          0.0,
          double.infinity,
        );
        return SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(24, 12, 24, bottomInset + 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: IntrinsicHeight(child: child),
          ),
        );
      },
    );
  }

  Widget _buildWelcomePage() {
    return _scrollablePage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 8),
          _buildHeroGraphic(),
          const SizedBox(height: 24),
          Text(
            'Train with a plan that learns you',
            style: AppText.headline,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Answer a few questions and we will build sessions, rest, and weights that fit your body and goals.',
            style: AppText.body,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          _buildFeatureStrip(),
          const SizedBox(height: 24),
          _primaryButton('Start Personalization', _nextPage),
        ],
      ),
    );
  }

  Widget _buildHeroGraphic() {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 650),
      tween: Tween(begin: 0.9, end: 1),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(scale: value, child: child);
      },
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.surfaceBright, AppColors.surface],
          ),
          border: Border.all(color: Colors.white10),
        ),
        child: Stack(
          children: [
            Positioned(
              top: 20,
              left: 20,
              child: _statBubble('Smart weights', Icons.auto_graph),
            ),
            Positioned(
              top: 20,
              right: 20,
              child: _statBubble('Rest timers', Icons.timer),
            ),
            Align(
              alignment: Alignment.center,
              child: Icon(
                Icons.fitness_center,
                size: 72,
                color: AppColors.accentAlt,
              ),
            ),
            Positioned(
              bottom: 20,
              left: 20,
              child: _statBubble('Progress path', Icons.trending_up),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statBubble(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.accentAlt),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppText.caption.copyWith(color: AppColors.onSurface),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureStrip() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: const [
        _FeatureCard(
          title: 'Adaptive',
          subtitle: 'Weights that scale with you',
          icon: Icons.auto_awesome,
        ),
        _FeatureCard(
          title: 'Focused',
          subtitle: 'Goal-driven routines',
          icon: Icons.flag,
        ),
        _FeatureCard(
          title: 'Simple',
          subtitle: 'Log sets in seconds',
          icon: Icons.flash_on,
        ),
      ],
    );
  }

  Widget _buildIdentityPage() {
    final firebaseUser = context.read<FirebaseProvider>().currentUser;
    final signedInLabel =
        (firebaseUser?.displayName?.trim().isNotEmpty ?? false)
            ? firebaseUser!.displayName!.trim()
            : firebaseUser?.email;
    final showApple =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS);

    return _scrollablePage(
      child: Form(
        key: _nameFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Make it yours', style: AppText.headline),
            const SizedBox(height: 8),
            Text(
              'Add your name and sign in if you want to sync progress across devices.',
              style: AppText.body,
            ),
            const SizedBox(height: 20),
            Text('Sign in or create account', style: AppText.title),
            const SizedBox(height: 12),
            _buildSignInButton(
              icon: FaIcon(
                FontAwesomeIcons.google,
                color: Colors.redAccent.shade200,
                size: 18,
              ),
              label: 'Continue with Google',
              onPressed:
                  _isSigningIn
                      ? null
                      : () => _handleSignIn(SignInMethod.google),
            ),
            if (showApple) ...[
              const SizedBox(height: 12),
              _buildSignInButton(
                icon: const FaIcon(
                  FontAwesomeIcons.apple,
                  color: Colors.white,
                  size: 18,
                ),
                label: 'Continue with Apple',
                onPressed:
                    _isSigningIn
                        ? null
                        : () => _handleSignIn(SignInMethod.apple),
              ),
            ],
            if (_isSigningIn)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: const [
                    SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text('Signing you in...', style: AppText.caption),
                  ],
                ),
              ),
            if (signedInLabel != null && signedInLabel.isNotEmpty)
              _buildSignInStatus(signedInLabel),
            const SizedBox(height: 20),
            _buildOrDivider(),
            const SizedBox(height: 20),
            _buildNameField(),
            const SizedBox(height: 24),
            _primaryButton('Continue', () {
              final isValid =
                  _nameFormKey.currentState?.validate() ??
                  (_validateName(_nameController.text) == null);
              if (isValid) {
                _nextPage();
              }
            }),
            const SizedBox(height: 8),
            Text(
              'You can always sign in later from Settings.',
              style: AppText.caption,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignInButton({
    required Widget icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: icon,
        label: Text(
          label,
          style: AppText.title.copyWith(color: AppColors.onSurface),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.onSurface,
          backgroundColor: Colors.white10,
          side: const BorderSide(color: Colors.white24),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _buildSignInStatus(String label) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified, size: 18, color: AppColors.accentAlt),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Signed in as $label',
              style: AppText.caption.copyWith(color: AppColors.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrDivider() {
    return Row(
      children: [
        const Expanded(child: Divider(color: Colors.white12, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'OR',
            style: AppText.caption.copyWith(
              color: AppColors.onSurfaceSubtle,
              letterSpacing: 1,
            ),
          ),
        ),
        const Expanded(child: Divider(color: Colors.white12, thickness: 1)),
      ],
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameController,
      style: AppText.title.copyWith(color: AppColors.onSurface),
      decoration: InputDecoration(
        labelText: 'Name',
        hintText: 'e.g., Jordan',
        prefixIcon: const Icon(Icons.person, color: AppColors.onSurfaceSubtle),
        filled: true,
        fillColor: AppColors.surfaceBright,
        labelStyle: AppText.caption.copyWith(color: AppColors.onSurfaceSubtle),
        hintStyle: AppText.caption,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.accentAlt, width: 1.5),
        ),
      ),
      keyboardType: TextInputType.name,
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.name],
      validator: (value) {
        return _validateName(value);
      },
      scrollPadding: const EdgeInsets.only(bottom: 140),
      onFieldSubmitted: (_) {
        final isValid =
            _nameFormKey.currentState?.validate() ??
            (_validateName(_nameController.text) == null);
        if (isValid) {
          _nextPage();
        }
      },
    );
  }

  Widget _buildPhysicalInfoPage() {
    return _scrollablePage(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your baseline', style: AppText.headline),
            const SizedBox(height: 8),
            Text(
              'We will personalize starting weights and rest based on your body metrics.',
              style: AppText.body,
            ),
            const SizedBox(height: 16),
            _buildUnitToggle(),
            const SizedBox(height: 16),
            _buildInputField(
              label: 'Height (cm)',
              hint: 'e.g., 175',
              icon: Icons.height,
              controller: _heightController,
              validator: _validateHeight,
            ),
            const SizedBox(height: 16),
            _buildInputField(
              label: 'Weight ($_weightUnit)',
              hint: _weightUnit == 'lb' ? 'e.g., 160' : 'e.g., 70',
              icon: Icons.monitor_weight,
              controller: _weightController,
              validator: _validateWeight,
            ),
            const SizedBox(height: 20),
            _buildSnapshotCard(),
            const SizedBox(height: 24),
            _primaryButton('Continue', () {
              final isValid =
                  _formKey.currentState?.validate() ??
                  (_validateHeight(_heightController.text) == null &&
                      _validateWeight(_weightController.text) == null);
              if (isValid) {
                _nextPage();
              }
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildUnitToggle() {
    return Row(
      children: [
        Text('Preferred unit', style: AppText.title),
        const SizedBox(width: 12),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('kg'),
              selected: _weightUnit == 'kg',
              onSelected: (_) => _setWeightUnit('kg'),
              selectedColor: AppColors.accentAlt,
              backgroundColor: AppColors.surfaceBright,
              labelStyle: TextStyle(
                color: _weightUnit == 'kg' ? Colors.black : AppColors.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            ChoiceChip(
              label: const Text('lb'),
              selected: _weightUnit == 'lb',
              onSelected: (_) => _setWeightUnit('lb'),
              selectedColor: AppColors.accentAlt,
              backgroundColor: AppColors.surfaceBright,
              labelStyle: TextStyle(
                color: _weightUnit == 'lb' ? Colors.black : AppColors.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSnapshotCard() {
    final height = _parseHeightCm();
    final weight = _parseWeightInput();
    final weightKg = _weightToKg(weight);
    final hasMetrics = height != null && weightKg != null;
    final bmi =
        hasMetrics ? (weightKg! / ((height! / 100) * (height / 100))) : null;
    final bmiText = bmi == null ? '--' : bmi.toStringAsFixed(1);
    final bmiCategory =
        hasMetrics
            ? (bmi! < 18.5
                ? 'Underweight'
                : bmi < 25
                ? 'Normal'
                : bmi < 30
                ? 'Overweight'
                : 'High')
            : 'Enter metrics';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.card.copyWith(
        gradient: AppColors.accentGradient,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your snapshot',
            style: AppText.title.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _snapshotTile('BMI', bmiText)),
              const SizedBox(width: 12),
              Expanded(child: _snapshotTile('Status', bmiCategory)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Recommended frequency: ${_recommendedFrequency()} days/week',
            style: AppText.body.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _snapshotTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.caption.copyWith(color: Colors.white70)),
          const SizedBox(height: 4),
          Text(value, style: AppText.title.copyWith(color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildFitnessLevelPage() {
    return _scrollablePage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Choose your level', style: AppText.headline),
          const SizedBox(height: 8),
          Text(
            'We will tune weights, recovery, and weekly volume for you.',
            style: AppText.body,
          ),
          const SizedBox(height: 20),
          ...FitnessLevel.values.map(_buildFitnessLevelCard),
          const SizedBox(height: 24),
          _primaryButton('Continue', _nextPage),
        ],
      ),
    );
  }

  Widget _buildFitnessGoalPage() {
    return _scrollablePage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What is your goal?', style: AppText.headline),
          const SizedBox(height: 8),
          Text(
            'Select one or more goals. Your plan will balance these priorities each week.',
            style: AppText.body,
          ),
          const SizedBox(height: 20),
          ...FitnessGoal.values.map(_buildFitnessGoalCard),
          const SizedBox(height: 24),
          _primaryButton(
            'Continue',
            _selectedFitnessGoals.isEmpty ? null : _nextPage,
          ),
        ],
      ),
    );
  }

  Widget _buildEquipmentPage() {
    final greetingName = _firstName(_nameController.text);
    final greeting =
        greetingName.isEmpty
            ? 'Your plan is ready to go.'
            : 'Great to meet you, $greetingName.';

    return _scrollablePage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What equipment do you have?', style: AppText.headline),
          const SizedBox(height: 8),
          Text(
            'Select all that apply. We will only suggest routines you can do.',
            style: AppText.body,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children:
                AvailableEquipment.values
                    .map((equipment) => _buildEquipmentChip(equipment))
                    .toList(),
          ),
          const SizedBox(height: 16),
          _buildSummaryGreeting(greeting),
          const SizedBox(height: 20),
          _buildPlanPreviewCard(),
          const SizedBox(height: 24),
          _primaryButton(
            _isLoading ? 'Finishing...' : 'Complete Setup',
            _isLoading ? null : _completeOnboarding,
            isLoading: _isLoading,
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      style: AppText.title.copyWith(color: AppColors.onSurface),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.onSurfaceSubtle),
        filled: true,
        fillColor: AppColors.surfaceBright,
        labelStyle: AppText.caption.copyWith(color: AppColors.onSurfaceSubtle),
        hintStyle: AppText.caption,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.accentAlt, width: 1.5),
        ),
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
      ],
      validator: validator,
      scrollPadding: const EdgeInsets.only(bottom: 140),
      textInputAction: TextInputAction.next,
      onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
    );
  }

  Widget _buildFitnessLevelCard(FitnessLevel level) {
    final isSelected = _selectedFitnessLevel == level;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSelected ? Colors.white10 : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? AppColors.accentAlt : Colors.white12,
        ),
      ),
      child: InkWell(
        onTap: () => setState(() => _selectedFitnessLevel = level),
        borderRadius: BorderRadius.circular(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    isSelected
                        ? AppColors.accentAlt.withOpacity(0.2)
                        : Colors.white10,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getFitnessLevelIcon(level),
                color:
                    isSelected
                        ? AppColors.accentAlt
                        : AppColors.onSurfaceSubtle,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    level.displayName,
                    style: AppText.title.copyWith(color: AppColors.onSurface),
                  ),
                  const SizedBox(height: 6),
                  Text(level.description, style: AppText.body),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: AppColors.accentAlt),
          ],
        ),
      ),
    );
  }

  Widget _buildFitnessGoalCard(FitnessGoal goal) {
    final isSelected = _selectedFitnessGoals.contains(goal);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSelected ? Colors.white10 : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? AppColors.accentAlt : Colors.white12,
        ),
      ),
      child: InkWell(
        onTap:
            () => setState(() {
              if (isSelected) {
                _selectedFitnessGoals.remove(goal);
              } else {
                _selectedFitnessGoals.add(goal);
              }
            }),
        borderRadius: BorderRadius.circular(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    isSelected
                        ? AppColors.accentAlt.withOpacity(0.2)
                        : Colors.white10,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _goalIcons[goal],
                color:
                    isSelected
                        ? AppColors.accentAlt
                        : AppColors.onSurfaceSubtle,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    goal.displayName,
                    style: AppText.title.copyWith(color: AppColors.onSurface),
                  ),
                  const SizedBox(height: 6),
                  Text(_goalDescriptions[goal] ?? '', style: AppText.body),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: AppColors.accentAlt),
          ],
        ),
      ),
    );
  }

  Widget _buildEquipmentChip(AvailableEquipment equipment) {
    final isSelected = _selectedEquipment.contains(equipment);

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedEquipment.remove(equipment);
          } else {
            _selectedEquipment.add(equipment);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? AppColors.accentAlt.withOpacity(0.2)
                  : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected ? AppColors.accentAlt : Colors.white12,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _equipmentIcons[equipment],
              size: 18,
              color: AppColors.onSurfaceSubtle,
            ),
            const SizedBox(width: 8),
            Text(
              equipment.displayName,
              style: AppText.caption.copyWith(color: AppColors.onSurface),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryGreeting(String greeting) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.card.copyWith(color: AppColors.surfaceBright),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome, color: AppColors.accentAlt, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Final summary', style: AppText.caption),
                const SizedBox(height: 6),
                Text(
                  greeting,
                  style: AppText.title.copyWith(color: AppColors.onSurface),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanPreviewCard() {
    final equipmentText =
        _selectedEquipment.isEmpty
            ? 'Any equipment'
            : _selectedEquipment.map((e) => e.displayName).take(3).join(', ');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your plan preview',
            style: AppText.title.copyWith(color: AppColors.onSurface),
          ),
          const SizedBox(height: 8),
          _previewRow('Goals', _selectedGoalsLabel),
          _previewRow('Level', _selectedFitnessLevel.displayName),
          _previewRow('Frequency', '${_recommendedFrequency()} days/week'),
          _previewRow('Equipment', equipmentText),
        ],
      ),
    );
  }

  Widget _previewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(width: 90, child: Text(label, style: AppText.caption)),
          Expanded(
            child: Text(
              value,
              style: AppText.body.copyWith(color: AppColors.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  Widget _primaryButton(
    String label,
    VoidCallback? onPressed, {
    bool isLoading = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentAlt,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child:
            isLoading
                ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                : Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
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

class _FeatureCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _FeatureCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.accentAlt),
          const SizedBox(height: 10),
          Text(title, style: AppText.title),
          const SizedBox(height: 6),
          Text(subtitle, style: AppText.body),
        ],
      ),
    );
  }
}
