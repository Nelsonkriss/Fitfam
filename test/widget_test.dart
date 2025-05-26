import 'package:flutter_test/flutter_test.dart';
import 'package:workout_planner/main.dart';
import 'package:workout_planner/ui/home_page.dart';
import 'package:workout_planner/ui/setting_page.dart';
import 'package:workout_planner/ui/routine_detail_page.dart';
import 'package:workout_planner/models/routine.dart';
import 'test_helper.dart';
import 'mocks/mock_providers.dart';

void main() {
  group('App Widget Tests', () {
    testWidgets('App launches successfully and finds main page structure', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(child: const MyApp()));
      await tester.pumpAndSettle();

      // Verify basic app structure
      expect(find.byType(HomePage), findsOneWidget);
      expect(find.byType(BottomNavigationBar), findsOneWidget);
    });

    testWidgets('Navigation works correctly', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(child: const MyApp()));
      await tester.pumpAndSettle();

      // Navigate to Settings
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();
      expect(find.byType(SettingPage), findsOneWidget);

      // Navigate back to Home
      await tester.tap(find.byIcon(Icons.home));
      await tester.pumpAndSettle();
      expect(find.byType(HomePage), findsOneWidget);
    });

    testWidgets('Theme switching works', (WidgetTester tester) async {
      final mockThemeProvider = MockThemeProvider();
      
      await tester.pumpWidget(createTestApp(
        child: const MyApp(),
        themeProvider: mockThemeProvider,
      ));
      await tester.pumpAndSettle();

      // Navigate to Settings
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      // Toggle theme
      await tester.tap(find.byKey(const Key('theme_toggle')));
      await tester.pumpAndSettle();

      expect(mockThemeProvider.themeMode, equals(ThemeMode.dark));
    });
  });

  group('Routine Management Tests', () {
    testWidgets('Can create and view routine', (WidgetTester tester) async {
      final mockRoutinesBloc = MockRoutinesBloc();
      
      await tester.pumpWidget(createTestApp(
        child: const MyApp(),
        routinesBloc: mockRoutinesBloc,
      ));
      await tester.pumpAndSettle();

      // Add new routine
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // Fill routine details
      await tester.enterText(find.byKey(const Key('routine_name')), 'Test Routine');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Verify routine was added
      expect(find.text('Test Routine'), findsOneWidget);
    });

    testWidgets('Can view routine details', (WidgetTester tester) async {
      final mockRoutine = TestData.createMockRoutine();
      final mockRoutinesBloc = MockRoutinesBloc()..addRoutine(mockRoutine);

      await tester.pumpWidget(createTestApp(
        child: RoutineDetailPage(routine: mockRoutine),
        routinesBloc: mockRoutinesBloc,
      ));
      await tester.pumpAndSettle();

      // Verify routine details are displayed
      expect(find.text(mockRoutine.name), findsOneWidget);
      expect(find.text(mockRoutine.exercises.first.name), findsOneWidget);
    });
  });

  group('Workout Session Tests', () {
    testWidgets('Can start and complete workout session', (WidgetTester tester) async {
      final mockRoutine = TestData.createMockRoutine();
      final mockWorkoutSessionBloc = MockWorkoutSessionBloc();

      await tester.pumpWidget(createTestApp(
        child: const MyApp(),
        workoutSessionBloc: mockWorkoutSessionBloc,
      ));
      await tester.pumpAndSettle();

      // Start workout
      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pumpAndSettle();

      // Select routine
      await tester.tap(find.text(mockRoutine.name));
      await tester.pumpAndSettle();

      // Complete workout
      await tester.tap(find.byIcon(Icons.check));
      await tester.pumpAndSettle();

      // Verify completion
      expect(find.text('Workout Complete'), findsOneWidget);
    });
  });

  group('Error Handling Tests', () {
    testWidgets('Shows error message when data loading fails', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(
        child: const MyApp(),
        useMockProviders: true,
        dbProvider: MockDbProviderWithError(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Failed to load data'), findsOneWidget);
      expect(find.byType(RetryButton), findsOneWidget);
    });

    testWidgets('Can retry after error', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(
        child: const MyApp(),
        useMockProviders: true,
        dbProvider: MockDbProviderWithError(),
      ));
      await tester.pumpAndSettle();

      // Tap retry button
      await tester.tap(find.byType(RetryButton));
      await tester.pumpAndSettle();

      // Verify loading state
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('Platform-specific Tests', () {
    testWidgets('Shows correct layout for web', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      
      await tester.pumpWidget(createTestApp(
        child: const MyApp(),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(DesktopLayout), findsOneWidget);
    });

    testWidgets('Shows correct layout for mobile', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      
      await tester.pumpWidget(createTestApp(
        child: const MyApp(),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(MobileLayout), findsOneWidget);
    });
  });
}
