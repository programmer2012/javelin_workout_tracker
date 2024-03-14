import 'package:flutter/material.dart';
import 'package:javelin_workout_tracker/components/exercise_widget.dart';
import 'package:javelin_workout_tracker/pages/choose_workout.dart';

class AddWorkoutPage extends StatefulWidget {
  final Map<dynamic, dynamic> userData;
  const AddWorkoutPage({required this.userData, super.key});

  @override
  State<AddWorkoutPage> createState() => _AddWorkoutPageState();
}

class _AddWorkoutPageState extends State<AddWorkoutPage> {
  bool toggleWorkout = true;
  Map isSelected = {};
  List exerciseWidgets = [];

  deleteExercise(index) {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              title: const Text(
                'Delete this exercise?',
                style: TextStyle(fontSize: 20),
                textAlign: TextAlign.center,
              ),
              actionsAlignment: MainAxisAlignment.spaceBetween,
              actions: [
                MaterialButton(
                  onPressed: delete(index),
                  child: const Text('yes'),
                  color: Colors.green,
                ),
                MaterialButton(
                  onPressed: cancel,
                  child: const Text('no'),
                  color: Colors.red,
                )
              ],
            ));
  }

  void cancel() {
    Navigator.pop(context);
  }

  delete(index) {
    print("bevore $exerciseWidgets");
    exerciseWidgets.removeAt(index);

    print("after $exerciseWidgets");

    Navigator.pop(context);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepPurple,
      appBar: AppBar(
        title: const Center(child: Text('Add a new Workout')),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Container(
            margin: EdgeInsets.symmetric(
              horizontal: 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                exerciseWidgets.isNotEmpty
                    ? Container(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        margin: EdgeInsets.only(top: 20),
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: Colors.grey.shade200),
                        height: 500,
                        child: ListView.builder(
                          itemCount: exerciseWidgets.length,
                          itemBuilder: (context, index) =>
                              exerciseWidgets[index],
                        ),
                      )
                    : Container(),
                GestureDetector(
                  onTap: () async {
                    isSelected = await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => ChooseWorkout(
                                userData: widget.userData,
                              )),
                    );
                    print('main Page $isSelected');
                    isSelected.forEach((key, value) {
                      if (value) {
                        exerciseWidgets.add(ExerciseWidget(
                          name: key,
                          index: exerciseWidgets.length,
                          deleteExercise: () =>
                              deleteExercise(exerciseWidgets.length),
                        ));
                      }
                    });
                    print(exerciseWidgets);
                    setState(() {});
                  },
                  child: Container(
                    margin: EdgeInsets.only(top: 20),
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    // margin: EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: Colors.grey.shade200),
                    child: const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Choose exercise',
                            style: TextStyle(fontSize: 17),
                          ),
                          Icon(Icons.add)
                        ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
