import 'package:flutter/material.dart';
import 'package:javelin_workout_tracker/services/workout_repository.dart';

/// Picks exercises from the user's catalogue.
///
/// Pops with the list of selected exercise names, or `null` if the user backed
/// out without confirming.
class ChooseWorkout extends StatefulWidget {
  final List<dynamic> exercises;

  const ChooseWorkout({
    super.key,
    required this.exercises,
  });

  @override
  State<ChooseWorkout> createState() => _ChooseWorkoutState();
}

class _ChooseWorkoutState extends State<ChooseWorkout> {
  final WorkoutRepository _repository = WorkoutRepository();
  final TextEditingController _exerciseNameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  /// The full catalogue. [_visibleExercises] is only ever a view on it, so
  /// deleting while a filter is active still removes from the real list.
  late final List<Map<String, dynamic>> _exercises;
  List<Map<String, dynamic>> _visibleExercises = [];
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _exercises = widget.exercises
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    _visibleExercises = List.of(_exercises);
  }

  @override
  void dispose() {
    _exerciseNameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _runFilter(String keyword) {
    final query = keyword.trim().toLowerCase();
    setState(() {
      _visibleExercises = query.isEmpty
          ? List.of(_exercises)
          : _exercises
              .where((exercise) =>
                  _nameOf(exercise).toLowerCase().contains(query))
              .toList();
    });
  }

  String _nameOf(Map<String, dynamic> exercise) =>
      exercise['name']?.toString() ?? '';

  Future<void> _saveCatalogue() async {
    try {
      await _repository.saveExerciseCatalogue(_exercises);
    } catch (error) {
      _showMessage('Could not save the exercise list: $error');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _delete(Map<String, dynamic> exercise) {
    setState(() {
      _exercises.remove(exercise);
      _visibleExercises.remove(exercise);
      _selected.remove(_nameOf(exercise));
    });
    _saveCatalogue();
  }

  void _toggleSelection(Map<String, dynamic> exercise) {
    final name = _nameOf(exercise);
    setState(() {
      if (!_selected.remove(name)) _selected.add(name);
    });
  }

  void _confirmSelection() {
    // Return the names in catalogue order so the workout is predictable.
    final names = _exercises
        .map(_nameOf)
        .where(_selected.contains)
        .toList();
    Navigator.pop(context, names);
  }

  /// Ids must stay unique even after deletions, so derive the next one from
  /// the highest id in use rather than from the list length.
  int _nextId() {
    var highest = 0;
    for (final exercise in _exercises) {
      final id = exercise['id'];
      final value = id is int ? id : int.tryParse(id?.toString() ?? '') ?? 0;
      if (value > highest) highest = value;
    }
    return highest + 1;
  }

  Future<void> _createNewExercise() async {
    _exerciseNameController.clear();

    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        String? errorText;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            title: const Text(
              'Create a new exercise',
              style: TextStyle(fontSize: 20),
              textAlign: TextAlign.center,
            ),
            content: TextField(
              controller: _exerciseNameController,
              autofocus: true,
              decoration: InputDecoration(errorText: errorText),
            ),
            actionsAlignment: MainAxisAlignment.spaceBetween,
            actions: [
              MaterialButton(
                color: Colors.green,
                onPressed: () {
                  final value = _exerciseNameController.text.trim();
                  // Report problems in the dialog instead of throwing out of
                  // a button callback.
                  if (value.isEmpty) {
                    setDialogState(() => errorText = 'Please enter a name');
                    return;
                  }
                  final exists = _exercises.any((exercise) =>
                      _nameOf(exercise).toLowerCase() == value.toLowerCase());
                  if (exists) {
                    setDialogState(
                        () => errorText = 'This exercise already exists');
                    return;
                  }
                  Navigator.pop(dialogContext, value);
                },
                child: const Text('save'),
              ),
              MaterialButton(
                color: Colors.red,
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('cancel'),
              ),
            ],
          ),
        );
      },
    );

    if (name == null || !mounted) return;

    setState(() {
      _exercises.add({'id': _nextId(), 'name': name});
      _runFilter(_searchController.text);
    });
    _exerciseNameController.clear();
    await _saveCatalogue();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: Container(
        margin: const EdgeInsets.fromLTRB(36.0, 0, 4, 0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (_selected.isNotEmpty)
              FloatingActionButton(
                heroTag: null,
                onPressed: _confirmSelection,
                backgroundColor: Colors.lightGreen,
                child: const Icon(Icons.check, color: Colors.white),
              )
            else
              const SizedBox.shrink(),
            FloatingActionButton(
              heroTag: null,
              onPressed: _createNewExercise,
              backgroundColor: Colors.deepPurple,
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ],
        ),
      ),
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Add Excercise'),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          children: [
            const SizedBox(height: 10),
            TextField(
              controller: _searchController,
              onChanged: _runFilter,
              decoration: const InputDecoration(
                labelText: 'Search',
                suffixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _visibleExercises.isEmpty
                  ? const Center(child: Text('No exercises found'))
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 80.0),
                      itemCount: _visibleExercises.length,
                      itemBuilder: (context, index) {
                        final exercise = _visibleExercises[index];
                        final name = _nameOf(exercise);
                        final title = name.length > 20
                            ? '${name.substring(0, 20)}...'
                            : name;

                        return Card(
                          key: ValueKey(exercise['id'] ?? name),
                          color: Colors.deepPurpleAccent,
                          elevation: 4,
                          margin: const EdgeInsets.symmetric(vertical: 10),
                          child: Tooltip(
                            message: name,
                            child: ListTile(
                              contentPadding:
                                  const EdgeInsets.fromLTRB(12, 0, 0, 0),
                              onTap: () => _toggleSelection(exercise),
                              leading: Text(
                                (index + 1).toString(),
                                style: TextStyle(
                                  color: Colors.grey.shade300,
                                  fontSize: 15,
                                ),
                              ),
                              title: Text(
                                title,
                                style: const TextStyle(fontSize: 15),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.fitness_center_sharp,
                                    color: _selected.contains(name)
                                        ? Colors.green
                                        : Colors.grey.shade300,
                                  ),
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    onPressed: () => _delete(exercise),
                                    icon: Icon(
                                      Icons.delete,
                                      color: Colors.red[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
