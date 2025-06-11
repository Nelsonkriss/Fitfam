import 'package:flutter/material.dart';
import 'package:workout_planner/models/exercise_animation_data.dart';
import 'package:workout_planner/ui/components/exercise_animation_widget.dart';

/// Dialog for searching and selecting exercises with animations
class ExerciseSearchDialog extends StatefulWidget {
  final Function(String exerciseName) onExerciseSelected;
  final String? initialQuery;

  const ExerciseSearchDialog({
    super.key,
    required this.onExerciseSelected,
    this.initialQuery,
  });

  @override
  State<ExerciseSearchDialog> createState() => _ExerciseSearchDialogState();
}

class _ExerciseSearchDialogState extends State<ExerciseSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<String> _searchResults = [];
  String? _selectedExercise;
  bool _showAnimationPreview = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null) {
      _searchController.text = widget.initialQuery!;
    }
    _performSearch(_searchController.text);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _performSearch(String query) {
    setState(() {
      if (query.isEmpty) {
        _searchResults = ExerciseAnimationData.getAllExerciseNames();
      } else {
        _searchResults = ExerciseAnimationData.searchExercises(query);
      }
      _selectedExercise = null;
      _showAnimationPreview = false;
    });
  }

  void _selectExercise(String exerciseName) {
    setState(() {
      _selectedExercise = exerciseName;
      _showAnimationPreview = true;
    });
  }

  void _confirmSelection() {
    if (_selectedExercise != null) {
      widget.onExerciseSelected(_selectedExercise!);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'Exercise Library',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Search Bar
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search exercises...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _searchController.clear();
                          _performSearch('');
                        },
                        icon: const Icon(Icons.clear),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              onChanged: _performSearch,
              autofocus: true,
            ),
            
            const SizedBox(height: 16),
            
            // Results count
            Text(
              '${_searchResults.length} exercises available',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Content Area
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Use single column layout on smaller screens
                  final isSmallScreen = constraints.maxWidth < 600;
                  
                  if (isSmallScreen || !_showAnimationPreview) {
                    return _buildExerciseList();
                  }
                  
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Exercise List
                      Expanded(
                        flex: 1,
                        child: _buildExerciseList(),
                      ),
                      
                      // Animation Preview
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 1,
                        child: _buildAnimationPreview(),
                      ),
                    ],
                  );
                },
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8), // Reduced spacing
                Flexible(
                  child: ElevatedButton.icon(
                    onPressed: _selectedExercise != null ? _confirmSelection : null,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text(
                      'Select Exercise',
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // Reduced padding
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseList() {
    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No exercises found',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different search term',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListView.separated(
        itemCount: _searchResults.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
        ),
        itemBuilder: (context, index) {
          final exerciseName = _searchResults[index];
          final isSelected = _selectedExercise == exerciseName;
          final animationData = ExerciseAnimationData.getExerciseAnimation(exerciseName);

          return ListTile(
            selected: isSelected,
            selectedTileColor: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected 
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.fitness_center,
                color: isSelected 
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                size: 24,
              ),
            ),
            title: Text(
              exerciseName,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected 
                    ? Theme.of(context).colorScheme.onPrimaryContainer
                    : null,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
            subtitle: animationData != null
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.play_circle_outline,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Animation available',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  )
                : null,
            trailing: isSelected
                ? Icon(
                    Icons.check_circle,
                    color: Theme.of(context).colorScheme.primary,
                  )
                : const Icon(Icons.chevron_right),
            onTap: () => _selectExercise(exerciseName),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          );
        },
      ),
    );
  }

  Widget _buildAnimationPreview() {
    if (_selectedExercise == null) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Preview Header
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.preview,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Preview',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Selected Exercise Name
          Text(
            _selectedExercise!,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
          
          const SizedBox(height: 16),
          
          // Animation Widget
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: constraints.maxWidth,
                      maxHeight: constraints.maxHeight,
                    ),
                    child: ExerciseAnimationWidget(
                      exerciseName: _selectedExercise!,
                      autoPlay: true,
                      showControls: true,
                      showDescription: true,
                      width: constraints.maxWidth,
                      height: constraints.maxHeight * 0.7, // Limit height to prevent overflow
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper function to show the exercise search dialog
Future<String?> showExerciseSearchDialog({
  required BuildContext context,
  String? initialQuery,
}) async {
  String? selectedExercise;
  
  await showDialog<void>(
    context: context,
    builder: (context) => ExerciseSearchDialog(
      initialQuery: initialQuery,
      onExerciseSelected: (exerciseName) {
        selectedExercise = exerciseName;
      },
    ),
  );
  
  return selectedExercise;
}
