import 'package:flutter/material.dart';
import 'package:javelin_workout_tracker/components/new_set_widget.dart';
import 'package:javelin_workout_tracker/models/workout_exercise.dart';

/// Renders one exercise of the current workout. All mutations are delegated to
/// the page, which owns the data.
class ExerciseWidget extends StatefulWidget {
  final WorkoutExercise exercise;
  final int index;
  final bool isExpanded;
  final VoidCallback onDelete;
  final VoidCallback onAddSet;
  final ValueChanged<int> onDeleteSet;
  final VoidCallback onChanged;
  final ValueChanged<int> onExpansionChanged;

  const ExerciseWidget({
    super.key,
    required this.exercise,
    required this.index,
    required this.isExpanded,
    required this.onDelete,
    required this.onAddSet,
    required this.onDeleteSet,
    required this.onChanged,
    required this.onExpansionChanged,
  });

  @override
  State<ExerciseWidget> createState() => _ExerciseWidgetState();
}

class _ExerciseWidgetState extends State<ExerciseWidget> {
  final ExpansionTileController _expansionController =
      ExpansionTileController();

  @override
  void didUpdateWidget(covariant ExerciseWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only safe here: in initState the controller is not attached to a tile
    // yet. Keeps the accordion to a single open exercise.
    if (widget.isExpanded != oldWidget.isExpanded) {
      widget.isExpanded
          ? _expansionController.expand()
          : _expansionController.collapse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final sets = widget.exercise.sets;

    return GestureDetector(
      onLongPress: widget.onDelete,
      child: ExpansionTile(
        controller: _expansionController,
        initiallyExpanded: widget.isExpanded,
        onExpansionChanged: (expanded) {
          widget.onExpansionChanged(expanded ? widget.index : -1);
        },
        tilePadding: const EdgeInsets.symmetric(horizontal: 0),
        title: Text(widget.exercise.name),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 7),
            alignment: Alignment.center,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SizedBox(
                  width: 50,
                  child: Text('Set', textAlign: TextAlign.center),
                ),
                SizedBox(
                  width: 75,
                  child: Text('Reps', textAlign: TextAlign.center),
                ),
                SizedBox(
                  width: 80,
                  child: Text('Weight [kg]', textAlign: TextAlign.center),
                ),
                SizedBox(width: 60),
              ],
            ),
          ),
          // Laid out at its natural height rather than inside a fixed-height
          // inner scroller: the page's own list scrolls, so every set stays
          // reachable no matter how many there are or how large the user's
          // font scale is.
          Column(
            children: [
              for (var index = 0; index < sets.length; index++)
                NewSetWidget(
                  // The id keeps each row's text controllers with its set.
                  key: ValueKey(sets[index].id),
                  set: sets[index],
                  index: index,
                  onChanged: widget.onChanged,
                  onDelete: () => widget.onDeleteSet(index),
                ),
            ],
          ),
          TextButton(
            onPressed: widget.onAddSet,
            child: const Text('Add Set'),
          ),
        ],
      ),
    );
  }
}
