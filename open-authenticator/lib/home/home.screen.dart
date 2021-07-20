import 'package:flutter/cupertino.dart';

import 'widgets/help.dart';
import 'widgets/progress-timer.indicator.dart';

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: ListView(
        children: [
          Container(
            margin: EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
            padding: EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 8.0,
            ),
            decoration: BoxDecoration(
              color: CupertinoDynamicColor.withBrightness(
                color: CupertinoColors.white,
                darkColor: CupertinoColors.white.withAlpha(30),
              ).resolveFrom(context),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "GitHub",
                        style: CupertinoTheme.of(context)
                            .textTheme
                            .navTitleTextStyle,
                      ),
                      Text(
                        "medz",
                        style: CupertinoTheme.of(context)
                            .textTheme
                            .textStyle
                            .copyWith(
                              color: CupertinoColors.systemGrey,
                            ),
                      ),
                      Text(
                        "123 856",
                        style: CupertinoTheme.of(context)
                            .textTheme
                            .textStyle
                            .copyWith(
                              color: CupertinoTheme.of(context).primaryColor,
                              fontSize: 36.0,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ),
                ProgressTimerIndicator(period: 30),
                CupertinoButton(
                  child: Icon(
                    CupertinoIcons.right_chevron,
                    size: 16.0,
                    color: CupertinoColors.systemGrey,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: () {},
                ),
              ],
            ),
          ),
          const Help(),
        ],
      ),
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
        middle: CupertinoSearchTextField(),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: Icon(CupertinoIcons.add),
          onPressed: () {},
        ),
      ),
    );
  }
}
