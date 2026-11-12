import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

final url = Uri.parse('https://github.com/odroe/otp/issues');

class Help extends StatelessWidget {
  const Help({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      child: Text(
        "Do you want to setup Authenticator or get help?",
        style: TextStyle(fontSize: 12.0),
      ),
      onPressed: () async {
        if (await launchUrl(url, mode: LaunchMode.externalApplication)) {
          return;
        }

        if (!context.mounted) return;
        showCupertinoDialog(
          context: context,
          builder: (context) {
            return CupertinoAlertDialog(
              title: Text('Error'),
              content: Text('Unable to open external help address'),
              actions: [
                CupertinoDialogAction(
                  child: Text('Close'),
                  onPressed: () {
                    if (context.mounted) Navigator.of(context).pop();
                  },
                ),
                CupertinoDialogAction(
                  child: Text('Copy URL'),
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: url.toString()),
                    );
                    if (context.mounted) Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}
