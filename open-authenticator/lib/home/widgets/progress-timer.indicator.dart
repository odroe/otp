import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

class ProgressTimerIndicator extends StatefulWidget {
  final int period;

  const ProgressTimerIndicator({
    Key? key,
    required this.period,
  }) : super(key: key);

  @override
  _ProgressTimerIndicatorState createState() => _ProgressTimerIndicatorState();
}

class _ProgressTimerIndicatorState extends State<ProgressTimerIndicator> {
  /// Timer
  late Timer timer;

  /// Current half-minute seconds
  late int currentHalfMinuteSeconds;

  void updateHalfMinuteSeconds() {
    final value = DateTime.now().millisecondsSinceEpoch / 1000 % widget.period;
    setState(() {
      currentHalfMinuteSeconds = widget.period - value.floor();
    });
  }

  @override
  void initState() {
    const duration = const Duration(seconds: 1);
    updateHalfMinuteSeconds();
    timer = Timer.periodic(
      duration,
      (_timer) => updateHalfMinuteSeconds(),
    );
    super.initState();
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CircularPercentIndicator(
      radius: 24.0,
      lineWidth: 2.0,
      backgroundWidth: 1,
      animation: false,
      percent: currentHalfMinuteSeconds / widget.period,
      progressColor: currentHalfMinuteSeconds > 5
          ? CupertinoTheme.of(context).primaryColor
          : CupertinoColors.destructiveRed,
      center: Text(
        currentHalfMinuteSeconds.toString(),
        style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
              fontSize: 12.0,
              fontWeight: FontWeight.w200,
            ),
      ),
    );
  }
}
