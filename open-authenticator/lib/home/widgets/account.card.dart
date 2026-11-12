import 'dart:async';

import 'package:base32/base32.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:ootp/ootp.dart';

import '../../entities/account.entity.dart';
import '../../entities/parse_account.dart';
import '../../repository.dart';
import 'progress-timer.indicator.dart';

class AccountCard extends StatefulWidget {
  final AccountEntity account;
  final String? accountKey;

  const AccountCard(this.account, {Key? key, this.accountKey})
    : super(key: key);

  @override
  _AccountCardState createState() => _AccountCardState();
}

class _AccountCardState extends State<AccountCard> {
  /// Current time create a counter value.
  late int counter;

  /// Timer
  Timer? timer;

  /// Time-based One-time password
  TOTP? totp;

  @override
  void initState() {
    super.initState();
    initializeAccount();
  }

  @override
  void didUpdateWidget(covariant AccountCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    initializeAccount();
  }

  void initializeAccount() {
    timer?.cancel();
    totp = null;
    try {
      validateAccount(widget.account);
      counter = createCounter();
      totp = TOTP.secret(
        base32.decode(widget.account.secret.toUpperCase()),
        digits: widget.account.digits,
        period: widget.account.period,
      );
      timer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => updateCounter(),
      );
    } catch (_) {
      // Keep the original record and show a recoverable error, not a broken list.
    }
  }

  @override
  void dispose() {
    timer?.cancel();
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
  String get otpCode => totp!.make();

  /// Get a make OTP code for formatted.
  String get formattedOtpCode => totp!.make().replaceAllMapped(
    RegExp(r"(.{3})"),
    (Match match) => "${match.group(0)} ",
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
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
                if ((widget.account.name ?? '').isNotEmpty)
                  Text(
                    widget.account.name!,
                    style: CupertinoTheme.of(context).textTheme.textStyle
                        .copyWith(color: CupertinoColors.systemGrey),
                  ),
                GestureDetector(
                  child: Text(
                    totp == null ? 'Unable to generate code' : formattedOtpCode,
                    style: CupertinoTheme.of(context).textTheme.textStyle
                        .copyWith(
                          color: CupertinoTheme.of(context).primaryColor,
                          fontSize: 36.0,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  onTap: totp == null
                      ? null
                      : () {
                          Clipboard.setData(ClipboardData(text: otpCode)).then((
                            _void,
                          ) {
                            SystemSound.play(SystemSoundType.alert);
                            showCupertinoDialog(
                              useRootNavigator: true,
                              context: context,
                              builder: (context) => CupertinoAlertDialog(
                                title: Text("Copied"),
                                content: Text(
                                  "One-time password copied: $otpCode",
                                ),
                                actions: [
                                  CupertinoButton(
                                    child: Text("OK"),
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                  ),
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
          if (totp != null)
            ProgressTimerIndicator(
              key: ValueKey(widget.account.period),
              period: widget.account.period,
            ),
          CupertinoButton(
            child: Icon(
              CupertinoIcons.right_chevron,
              size: 16.0,
              color: CupertinoColors.systemGrey,
            ),
            padding: EdgeInsets.zero,
            onPressed: () {
              final key =
                  widget.accountKey ??
                  "${widget.account.issuer}:${widget.account.name}";
              showCupertinoDialog(
                context: context,
                builder: (context) => CupertinoAlertDialog(
                  title: Text('Confirm'),
                  content: Text('Do you want to delete the current password?'),
                  actions: [
                    CupertinoDialogAction(
                      child: Text('Cancel'),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                    CupertinoDialogAction(
                      child: Text('Delete'),
                      onPressed: () async {
                        try {
                          await accounts.delete(key);
                          if (context.mounted) Navigator.of(context).pop();
                        } catch (_) {
                          if (!context.mounted) return;
                          Navigator.of(context).pop();
                          showCupertinoDialog(
                            context: this.context,
                            builder: (context) => CupertinoAlertDialog(
                              content: const Text(
                                'Could not delete the account. Please try again.',
                              ),
                              actions: [
                                CupertinoDialogAction(
                                  child: const Text('OK'),
                                  onPressed: () => Navigator.of(context).pop(),
                                ),
                              ],
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
