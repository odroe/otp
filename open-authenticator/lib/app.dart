import 'package:flutter/cupertino.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

class Application extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      theme: CupertinoThemeData(
        primaryColor: CupertinoColors.systemBlue,
        barBackgroundColor: CupertinoDynamicColor.withBrightness(
          color: CupertinoColors.white,
          darkColor: CupertinoColors.black,
        ),
        scaffoldBackgroundColor: CupertinoDynamicColor.withBrightness(
            color: CupertinoColors.white.withAlpha(240),
            darkColor: CupertinoColors.black),
      ),
      home: HomeScreen(),
    );
  }
}

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
                CircularPercentIndicator(
                  radius: 26.0,
                  lineWidth: 3.0,
                  backgroundWidth: 1,
                  animation: true,
                  percent: 0.4,
                  progressColor: CupertinoTheme.of(context).primaryColor,
                  center: Text(
                    '30',
                    style:
                        CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                              fontSize: 12.0,
                              fontWeight: FontWeight.w200,
                            ),
                  ),
                ),
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
          CupertinoButton(
            child: Text(
              "Do you want to setup Authenticator or get help?",
              style: TextStyle(
                fontSize: 12.0,
              ),
            ),
            onPressed: () {},
          ),
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
