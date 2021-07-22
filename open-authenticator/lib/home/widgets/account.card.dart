import 'dart:async';

import 'package:base32/base32.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:ootp/ootp.dart';

import '../../entities/account.entity.dart';
import 'progress-timer.indicator.dart';

class AccountCard extends StatefulWidget {
  final AccountEntity account;

  const AccountCard(this.account, {Key? key}) : super(key: key);

  @override
  _AccountCardState createState() => _AccountCardState();
}

class _AccountCardState extends State<AccountCard> {
  /// Current time create a counter value.
  late int counter;

  /// Timer
  late Timer timer;

  /// Time-based One-time password
  late TOTP totp;

  @override
  void initState() {
    counter = createCounter();

    final secret = base32.decode(widget.account.secret);
    totp = TOTP.secret(
      secret,
      digits: widget.account.digits,
      period: widget.account.period,
    );

    const duration = const Duration(seconds: 1);
    timer = Timer.periodic(duration, (_timer) => updateCounter());

    super.initState();
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  int createCounter() {
    return (DateTime.now().millisecondsSinceEpoch /
            1000 /
            widget.account.period)
        .floor();
  }

  void updateCounter() {
    final value = createCounter();
    if (value != counter) {
      setState(() {
        counter = value;
      });
    }
  }

  /// Get a make OTP value
  String get otpCode => totp.make();

  /// Get a make OTP code for formatted.
  String get formattedOtpCode => totp.make().replaceAllMapped(
      RegExp(r"(.{3})"), (Match match) => "${match.group(0)} ");

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
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
                  widget.account.issuer,
                  style: CupertinoTheme.of(context).textTheme.navTitleTextStyle,
                ),
                if (widget.account.name!.isNotEmpty)
                  Text(
                    widget.account.name!,
                    style:
                        CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                              color: CupertinoColors.systemGrey,
                            ),
                  ),
                GestureDetector(
                  child: Text(
                    formattedOtpCode,
                    style:
                        CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                              color: CupertinoTheme.of(context).primaryColor,
                              fontSize: 36.0,
                              fontWeight: FontWeight.bold,
                            ),
                  ),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: otpCode))
                        .then((_void) {
                      SystemSound.play(SystemSoundType.alert);
                      showCupertinoDialog(
                        useRootNavigator: true,
                        context: context,
                        builder: (context) => CupertinoAlertDialog(
                          title: Text("Copied"),
                          content: Text("One-time password copied: $otpCode"),
                          actions: [
                            CupertinoButton(
                              child: Text("OK"),
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                            )
                          ],
                        ),
                        barrierDismissible: true,
                      );
                    });
                  },
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
    );
  }
}
