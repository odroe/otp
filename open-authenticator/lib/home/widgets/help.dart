import 'package:flutter/cupertino.dart';

class Help extends StatelessWidget {
  const Help({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      child: Text(
        "Do you want to setup Authenticator or get help?",
        style: TextStyle(
          fontSize: 12.0,
        ),
      ),
      onPressed: () {
        // TODO: Jump to setting and help page.
      },
    );
  }
}
