import 'package:flutter/cupertino.dart';

import 'home/home.screen.dart';

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
      initialRoute: '/',
      routes: {
        "/": (context) => const HomeScreen(),
      },
    );
  }
}
