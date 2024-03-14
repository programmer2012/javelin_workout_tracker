import 'package:flutter/material.dart';
import 'package:javelin_workout_tracker/components/new_set_widget.dart';

class ExerciseWidget extends StatefulWidget {
  final String name;
  final Function deleteExercise;
  final int index;
  const ExerciseWidget({
    super.key,
    required this.name,
    required this.deleteExercise,
    required this.index,
  });

  @override
  State<ExerciseWidget> createState() => _ExerciseWidgetState();
}

class _ExerciseWidgetState extends State<ExerciseWidget> {
  List<NewSetWidget> setWidgetList = [];

  List<String> weight = [];

  List<String> reps = [];

  addSet() {
    getWeightAndSets();
    setState(() {});
    setWidgetList.add(
      NewSetWidget(
        index: setWidgetList.length,
        // weightBevor: weight.isNotEmpty ? weight.last : '',
        // repsBevor: reps.isNotEmpty ? reps.last : '',
        weight:
            TextEditingController(text: weight.isNotEmpty ? weight.last : ''),
        reps: TextEditingController(text: reps.isNotEmpty ? reps.last : ''),
        onDelete: (int index) {
          setState(() {
            setWidgetList.removeAt(index);

            // Update indexes
            for (int i = index; i < setWidgetList.length; i++) {
              setWidgetList[i].index = i;
            }
          });
        },
      ),
    );
  }

  getWeightAndSets() {
    for (var widget in setWidgetList) {
      weight.add(widget.weight.text);
    }

    for (var widget in setWidgetList) {
      reps.add(widget.reps.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () => widget.deleteExercise(),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 0),
        title: Text(widget.name),
        children: [
          Container(
            padding: EdgeInsets.symmetric(vertical: 7),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 50,
                  alignment: Alignment.center,
                  child: Text('Set'),
                ),
                Container(
                  width: 75,
                  alignment: Alignment.center,
                  child: Text('Reps'),
                ),
                Container(
                  width: 80,
                  alignment: Alignment.center,
                  child: Text('Weight [kg]'),
                ),
                SizedBox(
                  width: 60,
                )
              ],
            ),
          ),
          Container(
            height: setWidgetList.length <= 3
                ? (50 * setWidgetList.length).ceilToDouble()
                : 150,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: setWidgetList.length,
              itemBuilder: (context, index) => setWidgetList[index],
            ),
          ),
          TextButton(onPressed: addSet, child: const Text('Add Set'))
        ],
      ),
    );
  }
}
