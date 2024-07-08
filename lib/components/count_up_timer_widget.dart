import 'dart:async';

import 'package:flutter/material.dart';

class CountUpTimer extends StatefulWidget {
  const CountUpTimer({super.key, getTim});

  @override
  State<CountUpTimer> createState() => _CountUpTimerState();
}

class _CountUpTimerState extends State<CountUpTimer> {
  Duration duration = const Duration();
  Timer? timer;
  bool isPaused = false;

  @override
  void initState() {
    super.initState();
    startTimer();
  }

  // getTime() {
  //   return timer;
  // }

  void addTime() {
    const addSeconds = 1;

    setState(() {
      final seconds = duration.inSeconds + addSeconds;

      duration = Duration(seconds: seconds);
    });
  }

  void startTimer() {
    timer = Timer.periodic(const Duration(seconds: 1), (_) => addTime());
  }

  void stopTimer() {
    setState(() {
      timer?.cancel();
    });
  }

  void toggleFunction() {
    setState(() {
      isPaused = !isPaused;
    });
    if (timer!.isActive) {
      stopTimer();
    } else {
      startTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(child: Container(child: buildTime()));
  }

  Widget buildTime() {
    String twoDigets(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigets(duration.inHours);
    final minuts = twoDigets(duration.inMinutes.remainder(60));
    final seconds = twoDigets(duration.inSeconds.remainder(60));
    return GestureDetector(
      onTap: () => toggleFunction(),
      child: Container(
          height: 30,
          width: 100,
          decoration: const BoxDecoration(
            color: Colors.deepPurple,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(10.0),
              bottomRight: Radius.circular(10.0),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isPaused ? Icons.play_arrow : Icons.pause,
                size: 20,
              ),
              timeContainer(time: hours),
              Container(
                  padding: EdgeInsets.only(right: 1),
                  // color: Colors.white,
                  alignment: Alignment.center,
                  child: Text(
                    ':',
                    textAlign: TextAlign.center,
                  )),
              timeContainer(time: minuts),
              Container(
                  padding: EdgeInsets.only(right: 1),
                  // color: Colors.white,
                  alignment: Alignment.center,
                  child: Text(
                    ':',
                    textAlign: TextAlign.center,
                  )),
              timeContainer(time: seconds),
            ],
          )),
    );
  }

  Widget timeContainer({required time}) {
    return Container(
      alignment: Alignment.centerLeft,
      // color: Colors.red,
      width: 20,
      child: Text(time),
    );
  }
}
