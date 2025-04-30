// Keep if history values might need decoding
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // <-- FIX: Import intl package for DateFormat

// Import Models, Utils, Components, Themes (adjust paths)
import 'package:workout_planner/models/routine.dart'; // Contains Part, Exercise, SetType etc.
import 'package:workout_planner/models/part.dart';
import 'package:workout_planner/ui/theme.dart'; // Assuming ThemeRegular etc. are here
import 'package:workout_planner/ui/components/chart.dart'; // Assuming StackedAreaLineChart is here
import 'package:workout_planner/ui/components/custom_expansion_tile.dart' as custom; // Your custom tile

class PartHistoryPage extends StatelessWidget {
  final Part part;

  const PartHistoryPage(this.part, {super.key});

  @override
  Widget build(BuildContext context) {
    final exercisesWithHistory = part.exercises.where((ex) => ex.exHistory.isNotEmpty).toList();

    if (exercisesWithHistory.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text("Exercise History")),
        body: const Center(child: Text("No history recorded for exercises in this part.")),
      );
    }

    return DefaultTabController(
      length: exercisesWithHistory.length,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back',
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text("Exercise History"),
          bottom: TabBar(
            indicator: CircleTabIndicator(color: Colors.grey.shade400, radius: 3),
            labelColor: Theme.of(context).colorScheme.onPrimary,
            unselectedLabelColor: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
            isScrollable: true,
            tabs: _getTabs(exercisesWithHistory),
          ),
          // backgroundColor: setTypeToThemeColorConverter(part.setType), // Optional
        ),
        body: TabBarView(
          children: _getTabChildren(exercisesWithHistory, part.setType),
        ),
      ),
    );
  }

  List<Widget> _getTabs(List<Exercise> exercises) {
    return exercises.map((ex) => Tab( text: ex.name.isNotEmpty ? ex.name : 'Unnamed', )).toList();
  }

  List<Widget> _getTabChildren(List<Exercise> exercises, SetType setType) {
    final Color color = setTypeToThemeColorConverter(setType);
    return exercises.map((ex) => TabChild(ex, color)).toList();
  }

  Color setTypeToThemeColorConverter(SetType setType) {
    try {
      switch (setType) {
        case SetType.Regular: return ThemeRegular.accentColor;
        case SetType.Drop: return ThemeDrop.accentColor;
        case SetType.Super: return ThemeSuper.accentColor;
        case SetType.Tri: return ThemeTri.accentColor;
        case SetType.Giant: return ThemeGiant.accentColor;
      }
    } catch(e) {
      debugPrint("Error getting theme color for SetType $setType: $e. Using default.");
      return Colors.blueGrey; // Fallback color
    }
  }
}

/// Displays the content for a single exercise tab (Chart + History List).
class TabChild extends StatelessWidget {
  final Exercise exercise;
  final Color foregroundColor; // Used for ExpansionTile theming

  const TabChild(this.exercise, this.foregroundColor, {super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        // Chart Section
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
              height: 200,
              // Ensure StackedAreaLineChart handles potential empty history gracefully
              child: StackedAreaLineChart(exercise)
          ),
        ),
        // History List Section
        Expanded(
            child: HistoryExpansionTile(
              // *** FIX #1: Pass the required positional arguments ***
                exercise.exHistory, // Pass the exHistory map
                foregroundColor     // Pass the foregroundColor
            )
        ),
      ],
    );
  }
}

/// Helper class to group history dates by year.
class _YearGroup {
  final int year;
  final List<DateTime> dates = [];

  _YearGroup(this.year);
}

/// Displays the exercise history grouped by year in expandable tiles.
class HistoryExpansionTile extends StatelessWidget {
  final Map<String, dynamic> exHistory; // Expects date string keys
  final Color foregroundColor;          // For potential theming

  // *** FIX #1: Corrected constructor signature ***
  const HistoryExpansionTile(this.exHistory, this.foregroundColor, {super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Parse and Group Dates by Year robustly
    final List<_YearGroup> yearGroups = [];
    final List<DateTime> sortedDates = [];

    for (var dateString in exHistory.keys) {
      try {
        // Attempt to parse assuming YYYY-MM-DD format
        final dateTime = DateTime.parse(dateString);
        sortedDates.add(dateTime);
      } catch (e) {
        debugPrint("Error parsing history date string: '$dateString'. Skipping. Error: $e");
      }
    }

    if (sortedDates.isEmpty) {
      return const Center(child: Text("No valid history entries found."));
    }

    // Sort dates chronologically (most recent first)
    sortedDates.sort((a, b) => b.compareTo(a));

    // Group sorted dates by year
    for (final date in sortedDates) {
      if (yearGroups.isEmpty || date.year != yearGroups.last.year) {
        yearGroups.add(_YearGroup(date.year));
      }
      yearGroups.last.dates.add(date);
    }

    // 2. Build ListView with ExpansionTiles
    return ListView.builder(
        itemCount: yearGroups.length,
        itemBuilder: (context, i) {
          final yearGroup = yearGroups[i];
          // *** FIX #2: Removed non-existent parameters for custom.ExpansionTile ***
          // Check your custom_expansion_tile.dart for available parameters like
          // 'iconColor', 'titleColor', 'backgroundColor', etc. and use those instead if needed.
          return custom.ExpansionTile(
            // Pass parameters supported by YOUR custom widget
            title: Text(yearGroup.year.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
            initiallyExpanded: i == 0, // Expand the first (most recent) year
            children: _buildHistoryListTiles(yearGroup.dates, exHistory),
            // Removed unsupported parameters:
            // foregroundColor: foregroundColor,
            // iconColor: foregroundColor,
            // collapsedIconColor: foregroundColor.withOpacity(0.7),
            // textColor: foregroundColor,
            // collapsedTextColor: Theme.of(context).textTheme.bodyLarge?.color,
            // childrenPadding: const EdgeInsets.only(bottom: 8.0),
          );
          // *** END FIX #2 ***
        });
  }

  /// Builds the ListTiles for the dates within a specific year.
  List<Widget> _buildHistoryListTiles(List<DateTime> dates, Map<String, dynamic> historyMap) {
    // *** FIX #3: Use imported DateFormat ***
    final DateFormat dateFormat = DateFormat.yMMMd(); // Example format: Jan 1, 2023
    List<Widget> listTiles = <Widget>[];

    for (int i = 0; i < dates.length; i++) {
      final date = dates[i];
      // Convert DateTime back to the String key used in the map
      final dateStringKey = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      final historyValue = historyMap[dateStringKey]?.toString() ?? 'N/A';

      listTiles.add(ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: Colors.grey[300],
          child: Text( (i + 1).toString(), style: const TextStyle(fontSize: 12, color: Colors.black87),),
        ),
        title: Text(dateFormat.format(date)), // Use DateFormat
        subtitle: Text("Record: $historyValue"),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 0),
      ));
      if (i < dates.length - 1) {
        listTiles.add(const Divider(height: 1, indent: 56, endIndent: 16));
      }
    }
    return listTiles;
  }
}


// --- Custom Tab Indicator --- (Keep as is if it works)
class CircleTabIndicator extends Decoration {
  final BoxPainter _painter;

  CircleTabIndicator({required Color color, required double radius}) : _painter = _CirclePainter(color, radius);

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) => _painter;
}

class _CirclePainter extends BoxPainter {
  final Paint _paint;
  final double radius;

  _CirclePainter(Color color, this.radius)
      : _paint = Paint()
    ..color = color
    ..isAntiAlias = true;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration cfg) {
    if (cfg.size != null) {
      final Offset circleOffset = offset + Offset(cfg.size!.width / 2, cfg.size!.height - radius - 5);
      canvas.drawCircle(circleOffset, radius, _paint);
    }
  }
}