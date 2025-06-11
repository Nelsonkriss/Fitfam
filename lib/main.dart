import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:timezone/timezone.dart' as tz;
import 'dart:async' show unawaited;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Local imports
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'resource/db_provider_interface.dart';
import 'resource/db_provider.dart';
import 'resource/firebase_provider.dart';
import 'resource/shared_prefs_provider.dart';
import 'bloc/routines_bloc.dart';
import 'bloc/workout_session_bloc.dart';
import 'bloc/theme_provider.dart';
import 'ui/home_page.dart';
import 'ui/statistics_page.dart';
import 'ui/progress_charts.dart';
import 'ui/setting_page.dart';
import 'ui/recommend_page.dart';
import 'ui/onboarding_page.dart';
import 'models/workout_session.dart';

// Global provider instances are created in their respective files
// (e.g., final dbProvider = createDbProvider(); in db_provider.dart)

// --- Notification Service Instance ---
// Create a global instance (or manage it via a provider/service locator)
final NotificationService notificationService = NotificationService();


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print('[MAIN] Flutter Binding Initialized.');

  // Initialize dotenv
  try {
    await dotenv.load(fileName: ".env");
    print('[MAIN] Environment variables loaded successfully');
  } catch (e) {
    print('[MAIN] Warning: Failed to load .env file: $e');
    // Continue execution as the app can still function without env vars
    // Individual features that need env vars will handle their unavailability
  }

  // Optimize app performance
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
    ),
  );
  
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  runApp(const InitializationLoader());
}

/// A widget that handles asynchronous initialization and shows a loading screen.
class InitializationLoader extends StatefulWidget {
  const InitializationLoader({super.key});

  @override
  _InitializationLoaderState createState() => _InitializationLoaderState();
}

class _InitializationLoaderState extends State<InitializationLoader> {
  bool _isInitialized = false;
  String? _errorMessage;

  // Notification helper methods are now part of NotificationService

  Future<void> _scheduleDailyWorkoutReminders() async {
    print("[MAIN] Scheduling daily workout reminders...");
    try {
      final List<Routine> routines = await dbProvider.getAllRoutines();
      final List<WorkoutSession> allSessions = await dbProvider.getWorkoutSessions();
      final DateTime now = DateTime.now();
      final int todayWeekday = now.weekday; // 1 for Monday, 7 for Sunday

      // Define a fixed time for the reminder, e.g., 9:00 AM
      final tz.TZDateTime nowZoned = tz.TZDateTime.from(now, tz.getLocation('Asia/Shanghai'));
      final tz.TZDateTime reminderTime = tz.TZDateTime(tz.getLocation('Asia/Shanghai'), nowZoned.year, nowZoned.month, nowZoned.day, 9, 0, 0);
      // Unique ID base for daily reminders to avoid clashes with other notifications
      const int dailyReminderIdBase = 10000;


      for (final routine in routines) {
        if (routine.id == null) continue; // Skip routines without an ID

        // Check if the routine is scheduled for today
        if (routine.weekdays.contains(todayWeekday)) {
          // Check if this routine has been completed today
          bool completedToday = allSessions.any((session) =>
              session.routine.id == routine.id &&
              session.isCompleted &&
              session.startTime.year == now.year &&
              session.startTime.month == now.month &&
              session.startTime.day == now.day);

          if (!completedToday) {
            final int notificationId = dailyReminderIdBase + routine.id!;
            print("[MAIN] Scheduling reminder for '${routine.routineName}' (ID: ${routine.id}) at $reminderTime. Notification ID: $notificationId");
            await notificationService.scheduleDailyNotification(
              id: notificationId, // Unique ID for this routine's daily reminder
              title: 'Workout Reminder',
              body: "Don't forget your '${routine.routineName}' workout today!",
              scheduledTime: reminderTime,
              payload: 'routine_reminder_${routine.id}',
            );
          } else {
            print("[MAIN] Routine '${routine.routineName}' (ID: ${routine.id}) already completed today. No reminder scheduled.");
             // Optionally, cancel any existing notification for this routine if it was scheduled before completion
            final int notificationId = dailyReminderIdBase + routine.id!;
            await notificationService.cancelNotification(notificationId);
          }
        }
      }
      print("[MAIN] Daily workout reminder scheduling complete.");
    } catch (e, s) {
      print("[MAIN] Error scheduling daily workout reminders: $e\n$s");
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Initialize core services in parallel with error handling
      print('[MAIN] Starting parallel initialization...');
      
      final results = await Future.wait([
        // Firebase initialization
        Future(() async {
          print('[MAIN] Starting Firebase initialization...');
          if (Firebase.apps.isEmpty) {
            await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
            print('[MAIN] Firebase initialized successfully');
          }
        }).catchError((e) {
          print('[MAIN] Firebase initialization error: $e');
          throw e;
        }),
        
        // Database initialization with retry
        Future(() async {
          print('[MAIN] Starting DB initialization...');
          for (int i = 0; i < 3; i++) {
            try {
              await dbProvider.initDB();
              print('[MAIN] DB initialized successfully');
              break;
            } catch (e) {
              if (i == 2) throw e; // Throw on final attempt
              print('[MAIN] DB init attempt ${i + 1} failed, retrying...');
              await Future.delayed(Duration(seconds: 1));
            }
          }
        }).catchError((e) {
          print('[MAIN] Database initialization error: $e');
          throw e;
        }),
        
        // Notification service initialization
        Future(() async {
          print('[MAIN] Starting Notification Service initialization...');
          await notificationService.init();
          print('[MAIN] Notification Service initialized');
        }).catchError((e) {
          print('[MAIN] Notification service initialization error: $e');
          // Don't throw here since notifications aren't critical
        }),
      ], eagerError: false); // Continue even if some futures fail
      
      // Check results
      final errors = results.whereType<Error>().toList();
      if (errors.isNotEmpty) {
        throw Exception('Some services failed to initialize: ${errors.join(', ')}');
      }
      // Schedule reminders after core services are initialized
      await _scheduleDailyWorkoutReminders();

      // Non-critical setup can run in parallel
      unawaited(sharedPrefsProvider.checkAndPrepareOnAppStart());
      unawaited(firebaseProvider.signInSilently().then((user) {
        if (kDebugMode) print("[MAIN] Silent sign-in completed. User: ${user?.uid ?? 'None'}");
      }));

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      print('[MAIN] CRITICAL: Unexpected error during initialization: $e');
      setState(() {
        _errorMessage = 'An unexpected error occurred during initialization:\n$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return ErrorApp(error: _errorMessage!);
    }

    if (!_isInitialized) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    print('[MAIN] Running App with MultiProvider...');
    return MultiProvider(
      providers: [
        Provider<DbProviderInterface>.value(value: dbProvider),
        Provider<FirebaseProvider>.value(value: firebaseProvider),
        Provider<SharedPrefsProvider>.value(value: sharedPrefsProvider),
        ChangeNotifierProvider<ThemeProvider>( // Add ThemeProvider
          create: (_) => ThemeProvider(sharedPrefsProvider),
        ),
        Provider<RoutinesBloc>(
            create: (_) {
              print('[PROVIDER] Creating RoutinesBloc...');
              final bloc = RoutinesBloc();
              bloc.fetchAllRoutines();
              // fetchRecommendedRoutines is specific to RecommendPage, let it handle it.
              // bloc.fetchRecommendedRoutines();
              return bloc;
            },
            dispose: (_, bloc) {
              print('[PROVIDER] Disposing RoutinesBloc...');
              bloc.dispose();
            }
        ),
        Provider<WorkoutSessionBloc>(
            create: (context) {
              print('[PROVIDER] Creating WorkoutSessionBloc...');
              return WorkoutSessionBloc(dbProvider: context.read<DbProviderInterface>());
            },
            dispose: (_, bloc) {
              print('[PROVIDER] Disposing WorkoutSessionBloc...');
              bloc.close();
            }
        ),
      ],
      child: const MyApp(), // MyApp will consume ThemeProvider
    );
  }
}

/// The root application widget. Sets up MaterialApp and consumes ThemeProvider.
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isCheckingOnboarding = true;
  bool _isOnboardingCompleted = false;

  @override
  void initState() {
    super.initState();
    _checkOnboardingStatus();
  }

  Future<void> _checkOnboardingStatus() async {
    try {
      final isCompleted = await sharedPrefsProvider.isOnboardingCompleted();
      setState(() {
        _isOnboardingCompleted = isCompleted;
        _isCheckingOnboarding = false;
      });
      print("[MAIN] Onboarding status checked: completed = $isCompleted");
    } catch (e) {
      print("[MAIN] Error checking onboarding status: $e");
      setState(() {
        _isOnboardingCompleted = false;
        _isCheckingOnboarding = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Consume the ThemeProvider
    final themeProvider = Provider.of<ThemeProvider>(context);
    print("[BUILD] MyApp, ThemeMode from Provider: ${themeProvider.themeMode}");

    if (_isCheckingOnboarding) {
      return MaterialApp(
        home: const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    // Define a light theme
    final ThemeData lightTheme = ThemeData(
      fontFamily: 'Roboto', // Using Roboto for a more standard modern feel
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.deepPurple, // A modern primary color
        primary: Colors.deepPurple.shade600,
        secondary: Colors.teal.shade400, // A complementary accent
        brightness: Brightness.light,
        surface: Colors.grey.shade100, // Background for cards, dialogs
        onSurface: Colors.black87,     // Text on surface
        background: Colors.white,      // Scaffold background
        onBackground: Colors.black87,  // Text on scaffold background
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.deepPurple.shade600,
        foregroundColor: Colors.white,
        elevation: 2,
        titleTextStyle: const TextStyle(fontFamily: 'Roboto', fontSize: 20, fontWeight: FontWeight.w500),
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(fontSize: 16, color: Colors.black87),
        headlineSmall: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black87),
        titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
      ),
      cardTheme: CardTheme(
        elevation: 1.0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
        margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepPurple.shade500,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide(color: Colors.deepPurple.shade500, width: 2.0),
        ),
        labelStyle: TextStyle(color: Colors.deepPurple.shade500),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: Colors.deepPurple.shade600,
        unselectedItemColor: Colors.grey.shade600,
        backgroundColor: Colors.white,
        elevation: 4.0,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: Colors.deepPurple.shade600, // Match primary
        foregroundColor: Colors.white, // Icon color
      ),
      useMaterial3: true,
    );

    // Define a dark theme
    final ThemeData darkTheme = ThemeData(
      fontFamily: 'Roboto',
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.deepPurple,
        primary: Colors.deepPurple.shade300,
        secondary: Colors.tealAccent.shade400,
        brightness: Brightness.dark,
        surface: Colors.grey.shade800,
        onSurface: Colors.white70,
        background: const Color(0xFF121212),
        onBackground: Colors.white70,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.grey.shade900,
        foregroundColor: Colors.white,
        elevation: 2,
        titleTextStyle: const TextStyle(fontFamily: 'Roboto', fontSize: 20, fontWeight: FontWeight.w500, color: Colors.white),
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(fontSize: 16, color: Colors.white70),
        headlineSmall: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
        titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      cardTheme: CardTheme(
        elevation: 2.0,
        color: Colors.grey.shade800, // Darker card color
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
        margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepPurple.shade400,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide(color: Colors.grey.shade700),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide(color: Colors.deepPurple.shade300, width: 2.0),
        ),
        labelStyle: TextStyle(color: Colors.deepPurple.shade300),
        hintStyle: TextStyle(color: Colors.grey.shade500),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: Colors.deepPurple.shade300,
        unselectedItemColor: Colors.grey.shade500,
        backgroundColor: Colors.grey.shade900,
        elevation: 4.0,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: Colors.deepPurple.shade300, // Match dark primary
        foregroundColor: Colors.black87, // Icon color for contrast on lighter purple
      ),
      scaffoldBackgroundColor: const Color(0xFF121212),
      useMaterial3: true,
    );

    return MaterialApp(
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeProvider.themeMode, // Use themeMode from ThemeProvider
      debugShowCheckedModeBanner: false,
      title: 'Workout Planner',
      home: _isOnboardingCompleted 
          ? const MainPage() 
          : OnboardingPage(
              onOnboardingComplete: () {
                setState(() {
                  _isOnboardingCompleted = true;
                });
              },
            ),
    );
  }
}

// The toggleThemeExample is no longer needed here as ThemeProvider handles changes.
// The UI for changing the theme will be in SettingPage.

/// The main scaffold holding the different pages via BottomNavigationBar.
class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  MainPageState createState() => MainPageState();
}

class MainPageState extends State<MainPage> {
  int _selectedIndex = 0;

  static const List<Widget> _widgetOptions = <Widget>[
    HomePage(),
    StatisticsPage(),
    ProgressCharts(),
    RecommendPage(), // Added RecommendPage
    SettingPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    print("[BUILD] MainPage (Tab: $_selectedIndex)");
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _widgetOptions,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem( icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home', ),
          BottomNavigationBarItem( icon: Icon(Icons.calendar_today_outlined), activeIcon: Icon(Icons.calendar_today), label: 'Calendar', ),
          BottomNavigationBarItem( icon: Icon(Icons.show_chart_outlined), activeIcon: Icon(Icons.show_chart), label: 'Progress', ),
          BottomNavigationBarItem( icon: Icon(Icons.auto_awesome_outlined), activeIcon: Icon(Icons.auto_awesome), label: 'AI Coach', ), // Added AI Coach / Recommend
          BottomNavigationBarItem( icon: Icon(Icons.settings_outlined), activeIcon: Icon(Icons.settings), label: 'Settings', ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey.shade600,
        showUnselectedLabels: false,
        type: BottomNavigationBarType.fixed,
        onTap: _onItemTapped,
      ),
    );
  }
}

/// A simple widget shown when critical initialization fails.
class ErrorApp extends StatelessWidget {
  final String error;
  const ErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 60, color: Colors.red),
                  const SizedBox(height: 20),
                  const Text('Application Error', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  Text(
                    'Failed to initialize essential services:\n\n$error',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red.shade900, height: 1.4),
                  ),
                  const SizedBox(height: 25),
                  const Text(
                      'Please close and restart the app.\nIf the problem persists, please contact support.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey)
                  ),
                ],
              ),
            )
        ),
      ),
    );
  }
}

// The notificationTapBackground callback is now handled within NotificationService.
// No need for a top-level function here anymore unless specifically required
// by a plugin constraint not handled by the service's static method.