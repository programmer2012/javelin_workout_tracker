import 'dart:async';

import 'package:flutter/material.dart';

class CountUpTimer extends StatefulWidget {
  const CountUpTimer({
    super.key,
  });

  @override
  State<CountUpTimer> createState() => _CountUpTimerState();
}

class _CountUpTimerState extends State<CountUpTimer> {
  Duration duration = Duration();
  Timer? timer;

  @override
  void initState() {
    super.initState();
    startTimer();
  }

  void addTime() {
    const addSeconds = 1;

    setState(() {
      final seconds = duration.inSeconds + addSeconds;

      duration = Duration(seconds: seconds);
    });
  }

  void startTimer() {
    timer = Timer.periodic(Duration(seconds: 1), (_) => addTime());
  }

  void stopTimer() {
    setState(() {
      timer?.cancel();
    });
  }

  void toggleFunction() {
    if (timer!.isActive) {
      stopTimer();
    } else {
      startTimer();
    }
  }

  // todo remove CENTER WIDGET
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
