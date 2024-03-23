import 'package:flutter/material.dart';
import 'package:javelin_workout_tracker/components/count_up_timer_widget.dart';
import 'package:javelin_workout_tracker/components/exercise_widget.dart';
import 'package:javelin_workout_tracker/pages/choose_workout.dart';
import 'package:stop_watch_timer/stop_watch_timer.dart';

class AddWorkoutPage extends StatefulWidget {
  final Map<dynamic, dynamic> userData;
  const AddWorkoutPage({required this.userData, super.key});

  @override
  State<AddWorkoutPage> createState() => _AddWorkoutPageState();
}

// todo toogle timer isnt working

class _AddWorkoutPageState extends State<AddWorkoutPage> {
  bool toggleWorkout = true;
  Map isSelected = {};
  List exerciseWidgets = [];
  bool isStopped = false;

  // Todo Stopwatch timer
  final StopWatchTimer _stopWatchTimer = StopWatchTimer();

  deleteExercise(index) {
    // print(exerciseWidgets[index]["name"]);

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
                  onPressed: () => delete(index),
                  child: const Text('delete'),
                  color: Colors.green,
                ),
                MaterialButton(
                  onPressed: () => cancel(index),
                  child: const Text('cancel'),
                  color: Colors.red,
                )
              ],
            ));
  }

  void cancel(index) {
    print(index);
    Navigator.pop(context);
  }

  delete(index) {
    exerciseWidgets.removeAt(index);
    Navigator.pop(context);
    setState(() {});
    updateExerciseIndex();
  }

  updateExerciseIndex() {
    for (int i = 0; i < exerciseWidgets.length; i++) {
      exerciseWidgets[i].index = i;
      print('${exerciseWidgets[i].name} ${exerciseWidgets[i].index}');
    }
    setState(() {});
  }

  @override
  void dispose() async {
    super.dispose();
    await _stopWatchTimer.dispose(); // Need to call dispose function.
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
                        child: Column(
                          children: [
                            CountUpTimer(),
                            Container(
                              height: 400,
                              child: ListView.builder(
                                itemCount: exerciseWidgets.length,
                                itemBuilder: (context, index) =>
                                    exerciseWidgets[index],
                              ),
                            ),
                          ],
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
                    isSelected.forEach((key, value) {
                      if (value) {
                        int index = exerciseWidgets
                            .length; // Index setzen auf aktuelle Länge der Liste
                        exerciseWidgets.add(ExerciseWidget(
                          name: key,
                          index: index, // Index setzen
                          deleteExercise: () => deleteExercise(index),
                          setWidgetList: [], // Hier wird der Index an deleteExercise übergeben
                        ));
                      }
                    });
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
