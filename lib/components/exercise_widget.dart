import 'package:flutter/material.dart';
import 'package:javelin_workout_tracker/components/new_set_widget.dart';

// ignore: must_be_immutable
class ExerciseWidget extends StatefulWidget {
  final String name;
  final Function deleteExercise;
  int index;
  List<NewSetWidget> setWidgetList;
  ExerciseWidget(
      {super.key,
      required this.name,
      required this.deleteExercise,
      required this.index,
      required this.setWidgetList});

  @override
  State<ExerciseWidget> createState() => _ExerciseWidgetState();
}

class _ExerciseWidgetState extends State<ExerciseWidget> {
  List<String> weight = [];

  List<String> reps = [];

  addSet() {
    weight.clear();
    reps.clear();

    getWeightAndSets();
    setState(() {});

    widget.setWidgetList.add(
      NewSetWidget(
        index: widget.setWidgetList.length,
        // weightBevor: weight.isNotEmpty ? weight.last : '',
        // repsBevor: reps.isNotEmpty ? reps.last : '',
        weight:
            TextEditingController(text: weight.isNotEmpty ? weight.last : ''),
        reps: TextEditingController(text: reps.isNotEmpty ? reps.last : ''),
        onDelete: (int index) {
          setState(() {
            widget.setWidgetList.removeAt(index);

            // Update indexes
            for (int i = index; i < widget.setWidgetList.length; i++) {
              widget.setWidgetList[i].index = i;
            }
          });
        },
      ),
    );
    // widget.setWidgetList.forEach((element) {
    //   print(element.reps.text);
    //   print(element.weight.text);
    // });
  }

  getWeightAndSets() {
    for (var widget in widget.setWidgetList) {
      weight.add(widget.weight.text);
    }

    for (var widget in widget.setWidgetList) {
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
            height: widget.setWidgetList.length <= 3
                ? (50 * widget.setWidgetList.length).ceilToDouble()
                : 150,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.setWidgetList.length,
              itemBuilder: (context, index) => widget.setWidgetList[index],
            ),
          ),
          TextButton(onPressed: addSet, child: const Text('Add Set'))
        ],
      ),
    );
  }
}
