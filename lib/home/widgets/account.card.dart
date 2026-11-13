import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/services.dart';

import '../../entities/account.entity.dart';
import '../../entities/account_code.dart';
import '../../entities/parse_account.dart';
import '../../repository.dart';
import 'progress-timer.indicator.dart';

class const AccountCard(
  final AccountEntity account, {
  super.key,
  final String? accountKey,
}) extends StatefulWidget {
  @override
  _AccountCardState createState() => _AccountCardState();
}

class _AccountCardState() extends State<AccountCard> {
  /// Current time create a counter value.
  late int counter;

  /// Timer
  Timer? timer;

  bool valid = false;
  bool advancing = false;

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
    valid = false;
    try {
      validateAccount(widget.account);
      accountCode(widget.account);
      valid = true;
      if (widget.account.type == .TOTP) {
        counter = createCounter();
        timer = Timer.periodic(
          const Duration(seconds: 1),
          (_) => updateCounter(),
        );
      }
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
  String get otpCode => accountCode(widget.account);

  /// Get a make OTP code for formatted.
  String get formattedOtpCode => widget.account.format == .steam
      ? otpCode
      : otpCode.replaceAllMapped(
          RegExp(r"(.{3})"),
          (Match match) => "${match.group(0)} ",
        );

  void showCopyFailure() {
    if (!mounted) return;
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Could not copy'),
        content: const Text('Unable to copy the code. Please try again.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

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
              crossAxisAlignment: .start,
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
                    !valid ? 'Unable to generate code' : formattedOtpCode,
                    style: CupertinoTheme.of(context).textTheme.textStyle
                        .copyWith(
                          color: CupertinoTheme.of(context).primaryColor,
                          fontSize: 36.0,
                          fontWeight: .bold,
                        ),
                  ),
                  onTap: !valid
                      ? null
                      : () async {
                          final code = otpCode;
                          try {
                            await Clipboard.setData(ClipboardData(text: code));
                          } on PlatformException {
                            showCopyFailure();
                            return;
                          } on MissingPluginException {
                            showCopyFailure();
                            return;
                          }
                          if (!mounted) return;
                          SystemSound.play(.alert);
                          showCupertinoDialog(
                            useRootNavigator: true,
                            context: context,
                            builder: (context) => CupertinoAlertDialog(
                              title: Text("Copied"),
                              content: Text("One-time password copied: $code"),
                              actions: [
                                CupertinoButton(
                                  child: Text("OK"),
                                  onPressed: () => Navigator.of(context).pop(),
                                ),
                              ],
                            ),
                            barrierDismissible: true,
                          );
                        },
                ),
              ],
            ),
          ),
          if (valid && widget.account.type == .HOTP)
            CupertinoButton(
              onPressed: advancing
                  ? null
                  : () async {
                      final key = widget.accountKey;
                      final expected = widget.account.counter;
                      if (key == null || expected == null) return;
                      setState(() => advancing = true);
                      try {
                        await accounts.advanceHotp(key, expected);
                      } catch (_) {
                        if (mounted) {
                          showCupertinoDialog<void>(
                            context: context,
                            builder: (context) => CupertinoAlertDialog(
                              content: const Text(
                                'Could not advance the counter. Please try again.',
                              ),
                              actions: [
                                CupertinoDialogAction(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('OK'),
                                ),
                              ],
                            ),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => advancing = false);
                      }
                    },
              child: const Text('Next code'),
            ),
          if (valid && widget.account.type == .TOTP)
            ProgressTimerIndicator(
              key: ValueKey(widget.account.period),
              period: widget.account.period,
            ),
          CupertinoButton(
            child: Icon(
              CupertinoIcons.right_chevron,
              size: 16.0,
              semanticLabel: 'Delete account',
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
