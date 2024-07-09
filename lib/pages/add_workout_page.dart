import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:javelin_workout_tracker/components/count_up_timer_widget.dart';
import 'package:javelin_workout_tracker/components/exercise_widget.dart';
import 'package:javelin_workout_tracker/components/new_set_widget.dart';
// import 'package:javelin_workout_tracker/models/exercise_data.dart';
// import 'package:javelin_workout_tracker/models/set_widget_data.dart';
import 'package:javelin_workout_tracker/pages/choose_workout.dart';
import 'package:stop_watch_timer/stop_watch_timer.dart';

class AddWorkoutPage extends StatefulWidget {
  final Map<dynamic, dynamic> userData;
  const AddWorkoutPage({required this.userData, super.key});

  @override
  State<AddWorkoutPage> createState() => _AddWorkoutPageState();
}

class _AddWorkoutPageState extends State<AddWorkoutPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool toggleWorkout = true;
  Map isSelected = {};
  List exerciseWidgets = [];
  Map exerciseWidgetRaw = {};
  List exerciseWidgetsArr = [];
  bool isStopped = false;
  List<NewSetWidget> setWidegetList = [];

  final StopWatchTimer _stopWatchTimer = StopWatchTimer();

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

  void saveWorkout() {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              title: const Text(
                'Sure you want to save and quit this workout?',
                style: TextStyle(fontSize: 20),
                textAlign: TextAlign.center,
              ),
              actionsAlignment: MainAxisAlignment.spaceBetween,
              actions: [
                MaterialButton(
                  onPressed: saveWorkoutAction,
                  child: const Text('save'),
                  color: Colors.green,
                ),
                MaterialButton(
                  onPressed: cancelSaveWorkoutAction,
                  child: const Text('cancel'),
                  color: Colors.red,
                )
              ],
            ));
  }

  void saveWorkoutAction() {
    updateFirestore();
    resetCurrentWorkout();
    Navigator.pop(context);
  }

  void cancelSaveWorkoutAction() {
    Navigator.pop(context);
  }

  void resetCurrentWorkout() {
    _firestore
        .collection('users')
        .doc(_auth.currentUser!.uid)
        .update({'currentWorkout': {}});
  }

  void updateFirestore() {
    Map exercises = {};
    // print(exerciseWidgets);
    for (var element in exerciseWidgets) {
      var widgetList = element.setWidgetList;
      var name = element.name;

      exercises['$name'] = {};
      int setCount = 1;
      widgetList.forEach((set) {
        String setString = 'set$setCount';
        exercises['$name']
            ['$setString'] = {'reps': set.reps.text, 'weight': set.weight.text};
        setCount++;
      });
    }
    print(exercises);

    setState(() {});
    _firestore
        .collection('users')
        .doc(_auth.currentUser!.uid)
        .update({'currentWorkout': exercises});
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
    updateFirestore();
  }

  updateExerciseIndex() {
    for (int i = 0; i < exerciseWidgets.length; i++) {
      exerciseWidgets[i].index = i;
      print('${exerciseWidgets[i].name} ${exerciseWidgets[i].index}');
    }
    setState(() {});
  }

// Todo if data get fetchet sets are broke - no delete function - no add set function

  getCurrentWorkout() async {
    try {
      var snap = await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .get();
      var data = snap.data()!['currentWorkout'] as Map<String, dynamic>;

      for (var exerciseName in data.keys) {
        var sets = data[exerciseName] as Map<String, dynamic>;
        List<NewSetWidget> setWidgetList = [];
        sets.forEach((setName, setData) {
          setWidgetList.add(NewSetWidget(
            index: setWidgetList.length,
            reps: TextEditingController(text: setData['reps']),
            weight: TextEditingController(text: setData['weight']),
            updateFirestore: updateFirestore,
            onDelete: (int index) {
              setState(() {
                setWidgetList.removeAt(index);

                // Update indexes
                for (int i = index; i < setWidgetList.length; i++) {
                  setWidgetList[i].index = i;
                }
              });
            },
          ));
        });
        exerciseWidgets.add(ExerciseWidget(
          name: exerciseName,
          index: exerciseWidgets.length,
          deleteExercise: () => deleteExercise(exerciseWidgets.length),
          setWidgetList: setWidgetList,
          updateFirestore: updateFirestore,
        ));
      }

      setState(() {});
    } catch (e) {
      print('Error fetching current workout: $e');
    }
  }

  @override
  void dispose() async {
    super.dispose();
    await _stopWatchTimer.dispose(); // Need to call dispose function.
  }

  @override
  void initState() {
    getCurrentWorkout();
    super.initState();
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
                            // TextButton(
                            //     onPressed: updateFirestore,
                            //     child: Text('Update Firestore')),
                            TextButton(
                                onPressed: saveWorkout,
                                child: Text('Save Workout'))
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
                          setWidgetList: setWidegetList,
                          updateFirestore:
                              updateFirestore, // Hier wird der Index an deleteExercise übergeben
                        ));
                      }
                    });
                    setState(() {});
                    updateFirestore();
                    // print(exerciseWidgets[0]);
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
