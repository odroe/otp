import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

class const ProgressTimerIndicator({super.key, required final int period})
    extends StatefulWidget {
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
    const duration = Duration(seconds: 1);
    updateHalfMinuteSeconds();
    timer = Timer.periodic(duration, (_timer) => updateHalfMinuteSeconds());
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
        style: CupertinoTheme.of(context).textTheme.textStyle
            .copyWith(fontSize: 12.0, fontWeight: .w200),
      ),
    );
  }
}
