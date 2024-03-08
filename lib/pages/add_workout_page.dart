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
  List workoutList = [];
  Map isSelected = {};
  List exerciseWidgets = [];

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
                toggleWorkout
                    ? Container(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        margin: EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: Colors.grey.shade200),
                        height: exerciseWidgets.length <= 7
                            ? exerciseWidgets.length * 60
                            : 500,
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
                        exerciseWidgets.add(new ExerciseWidget(name: key));
                      }
                    });
                    print(exerciseWidgets);
                    setState(() {});
                  },
                  child: Container(
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
