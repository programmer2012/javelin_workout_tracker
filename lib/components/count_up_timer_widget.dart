import 'package:flutter/material.dart';
import 'package:javelin_workout_tracker/utils/count_up_timer_controler.dart';

class CountUpTimer extends StatelessWidget {
  final CountUpTimerController controller;

  const CountUpTimer({required this.controller, super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        String twoDigits(int n) => n.toString().padLeft(2, '0');
        final duration = controller.elapsed;
        final hours = twoDigits(duration.inHours);
        final minutes = twoDigits(duration.inMinutes.remainder(60));
        final seconds = twoDigits(duration.inSeconds.remainder(60));

        return Center(
          child: GestureDetector(
            onTap: controller.toggle,
            child: Container(
              height: 30,
              width: 110,
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
                    controller.isRunning ? Icons.pause : Icons.play_arrow,
                    size: 20,
                    color: Colors.white,
                  ),
                  _TimePart(text: hours),
                  const _Separator(),
                  _TimePart(text: minutes),
                  const _Separator(),
                  _TimePart(text: seconds),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TimePart extends StatelessWidget {
  final String text;

  const _TimePart({required this.text});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white),
      ),
    );
  }
}

class _Separator extends StatelessWidget {
  const _Separator();

  @override
  Widget build(BuildContext context) {
    return const Text(':', style: TextStyle(color: Colors.white));
  }
}
