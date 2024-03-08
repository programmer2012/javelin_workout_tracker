import 'package:flutter/material.dart';
import 'package:javelin_workout_tracker/components/new_set_widget.dart';

class ExerciseWidget extends StatefulWidget {
  final String name;
  const ExerciseWidget({super.key, required this.name});

  @override
  State<ExerciseWidget> createState() => _ExerciseWidgetState();
}

class _ExerciseWidgetState extends State<ExerciseWidget> {
  List<NewSetWidget> setWidgetList = [];

  List<String> weight = [];

  List<String> reps = [];

  addSet() {
    setWidgetList.add(new NewSetWidget(
        length: setWidgetList.length,
        weightBevor: weight.isNotEmpty ? weight[-1] : '0',
        repsBevor: reps.isNotEmpty ? reps[-1] : '0'));
    setState(() {});
    getWeightAndSets();
  }

  getWeightAndSets() {
    setWidgetList.forEach((widget) => weight.add(widget.weight.text));
    setWidgetList.forEach((widget) => reps.add(widget.reps.text));
  }

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      backgroundColor: Colors.orange,
      tilePadding: EdgeInsets.symmetric(horizontal: 0),
      title: Text(widget.name),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text('Set'), Text('Reps'), Text('Weight [kg]')],
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
        TextButton(onPressed: addSet, child: Text('Add Set'))
      ],
    );
  }
}
