import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

class const ProgressTimerIndicator({super.key, required final int period})
    extends StatefulWidget {
  @override
  _ProgressTimerIndicatorState createState() => _ProgressTimerIndicatorState();
}

class _ProgressTimerIndicatorState()
    extends State<ProgressTimerIndicator>
    with WidgetsBindingObserver {
  /// Timer
  Timer? timer;

  /// Current half-minute seconds
  late int currentHalfMinuteSeconds;

  int remaining() {
    final seconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return widget.period - seconds % widget.period;
  }

  void scheduleNextTick() {
    timer?.cancel();
    final delay = 1000 - DateTime.now().millisecondsSinceEpoch % 1000;
    timer = Timer(Duration(milliseconds: delay), () {
      if (!mounted) return;
      setState(() => currentHalfMinuteSeconds = remaining());
      scheduleNextTick();
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    currentHalfMinuteSeconds = remaining();
    scheduleNextTick();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() => currentHalfMinuteSeconds = remaining());
      scheduleNextTick();
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
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
