import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_planner/models/part.dart';
import 'package:workout_planner/models/routine.dart';
import 'package:workout_planner/ui/part_edit_page.dart';
import 'package:workout_planner/utils/routine_helpers.dart' show AddOrEdit;

void main() {
  group('PartEditPage Widget Tests', () {
    late Part testPart;

    setUp(() {
      testPart = Part(
        partName: 'Test Part',
        defaultName: false,
        targetedBodyPart: TargetedBodyPart.Chest,
        setType: SetType.Regular,
        exercises: [
          Exercise(
            name: 'Bench Press',
            weight: 60.0,
            sets: 3,
            reps: '10',
            workoutType: WorkoutType.Weight,
          ),
        ],
        additionalNotes: '',
      );
    });

    testWidgets('Workout type buttons layout and appearance', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PartEditPage(
            addOrEdit: AddOrEdit.edit,
            part: testPart,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify workout type segments are present
      expect(find.byType(CupertinoSlidingSegmentedControl<SetType>), findsOneWidget);
      expect(find.byType(SegmentedButton<WorkoutType>), findsOneWidget);

      // Verify the SegmentedButton has 3 segments with correct tooltips
      final weightSegment = find.byWidgetPredicate((widget) =>
        widget is ButtonSegment<WorkoutType> && widget.tooltip == 'Weight'
      );
      final timedSegment = find.byWidgetPredicate((widget) =>
        widget is ButtonSegment<WorkoutType> && widget.tooltip == 'Timed'
      );
      final cardioSegment = find.byWidgetPredicate((widget) =>
        widget is ButtonSegment<WorkoutType> && widget.tooltip == 'Cardio'
      );

      expect(weightSegment, findsOneWidget);
      expect(timedSegment, findsOneWidget);
      expect(cardioSegment, findsOneWidget);

      // Verify no overflow errors
      expect(tester.takeException(), isNull);
    });

    testWidgets('Workout type toggle functionality', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PartEditPage(
            addOrEdit: AddOrEdit.edit,
            part: testPart,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially Weight type should be selected
      final segmentedButton = find.byType(SegmentedButton<WorkoutType>);
      expect(segmentedButton, findsOneWidget);

      // Find and tap the Timed segment
      final timedButton = find.byWidgetPredicate((widget) =>
        widget is ButtonSegment<WorkoutType> && widget.tooltip == 'Timed'
      );
      await tester.tap(timedButton);
      await tester.pumpAndSettle();

      // Verify weight field is hidden for Timed workout
      expect(find.text('Wt (kg)'), findsNothing);
      expect(find.text('Time (sec) *'), findsOneWidget);

      // Find and tap the Cardio segment
      final cardioButton = find.byWidgetPredicate((widget) =>
        widget is ButtonSegment<WorkoutType> && widget.tooltip == 'Cardio'
      );
      await tester.tap(cardioButton);
      await tester.pumpAndSettle();

      // Verify appropriate fields for Cardio workout
      expect(find.text('Time (sec) *'), findsOneWidget);
    });

    testWidgets('Long exercise names handling', (WidgetTester tester) async {
      testPart = testPart.copyWith(
        exercises: [
          Exercise(
            name: 'Very Long Exercise Name That Should Not Cause Overflow Issues',
            weight: 60.0,
            sets: 3,
            reps: '10',
            workoutType: WorkoutType.Weight,
          ),
        ],
      );
      
      await tester.pumpWidget(
        MaterialApp(
          home: PartEditPage(
            addOrEdit: AddOrEdit.edit,
            part: testPart,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify no overflow errors with long exercise name
      expect(tester.takeException(), isNull);
    });

    testWidgets('Multiple exercises layout', (WidgetTester tester) async {
      testPart = testPart.copyWith(
        setType: SetType.Super,
        exercises: [
          Exercise(
            name: 'Bench Press',
            weight: 60.0,
            sets: 3,
            reps: '10',
            workoutType: WorkoutType.Weight,
          ),
          Exercise(
            name: 'Second Exercise',
            weight: 40.0,
            sets: 3,
            reps: '12',
            workoutType: WorkoutType.Weight,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PartEditPage(
            addOrEdit: AddOrEdit.edit,
            part: testPart,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify exercises are displayed with correct titles
      expect(
        find.text('Exercise 1'), 
        findsOneWidget,
        reason: 'Exercise 1 title should be visible',
      );
      expect(
        find.text('Exercise 2'), 
        findsOneWidget,
        reason: 'Exercise 2 title should be visible',
      );

      // Verify workout type segments for both exercises
      expect(
        find.byType(SegmentedButton<WorkoutType>), 
        findsNWidgets(2),
        reason: 'Should find two SegmentedButton widgets for workout types',
      );

      // Verify no overflow errors with multiple exercises
      expect(tester.takeException(), isNull);
    });

    testWidgets('Exercise search integration', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PartEditPage(
            addOrEdit: AddOrEdit.edit,
            part: testPart,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the search IconButton
      final searchButton = find.byWidgetPredicate(
        (widget) => widget is IconButton && 
                    widget.tooltip == 'Search Exercise Library' &&
                    (widget.icon as Icon).icon == Icons.search
      );
      expect(searchButton, findsOneWidget);

      // Verify no layout issues with search button
      expect(tester.takeException(), isNull);
    });

    testWidgets('Weight recommendation integration', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PartEditPage(
            addOrEdit: AddOrEdit.edit,
            part: testPart,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the weight field with the AI recommendation button
      final weightField = find.ancestor(
        of: find.byIcon(Icons.auto_awesome),
        matching: find.byType(TextFormField),
      );
      expect(weightField, findsOneWidget);

      // Verify the AI recommendation button
      final recommendButton = find.byWidgetPredicate(
        (widget) => widget is IconButton && 
                    widget.tooltip == 'AI Weight Recommendation' &&
                    (widget.icon as Icon).icon == Icons.auto_awesome
      );
      expect(recommendButton, findsOneWidget);

      // Verify no layout issues
      expect(tester.takeException(), isNull);
    });

    testWidgets('Different screen sizes', (WidgetTester tester) async {
      // Test with different screen sizes
      final sizes = [
        const Size(320, 480), // Small phone
        const Size(375, 667), // iPhone SE
        const Size(414, 896), // iPhone 11 Pro Max
        const Size(768, 1024), // Tablet
      ];

      for (final size in sizes) {
        await tester.binding.setSurfaceSize(size);
        
        await tester.pumpWidget(
          MaterialApp(
            home: PartEditPage(
              addOrEdit: AddOrEdit.edit,
              part: testPart,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify no overflow errors at this screen size
        expect(tester.takeException(), isNull);
      }
    });
  });
}
