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
  final DateTime Function()? clock,
}) extends StatefulWidget {
  @override
  _AccountCardState createState() => _AccountCardState();
}

class _AccountCardState()
    extends State<AccountCard>
    with WidgetsBindingObserver {
  /// Current time create a counter value.
  late int counter;

  /// Timer
  Timer? timer;
  Timer? boundaryTimer;
  Timer? feedbackTimer;

  bool valid = false;
  bool advancing = false;
  String? copiedCode;
  String? displayedCode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    initializeAccount();
  }

  @override
  void didUpdateWidget(covariant AccountCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.account, widget.account)) {
      feedbackTimer?.cancel();
      copiedCode = null;
    }
    initializeAccount();
  }

  void initializeAccount() {
    timer?.cancel();
    boundaryTimer?.cancel();
    valid = false;
    displayedCode = null;
    try {
      validateAccount(widget.account);
      final instant = now();
      displayedCode = accountCode(widget.account, at: instant);
      valid = true;
      if (widget.account.type == .TOTP) {
        counter = counterAt(instant);
        timer = Timer.periodic(
          const Duration(seconds: 1),
          (_) => updateCounter(),
        );
        scheduleBoundary();
      }
    } catch (_) {
      // Keep the original record and show a recoverable error, not a broken list.
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    boundaryTimer?.cancel();
    feedbackTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        valid &&
        widget.account.type == .TOTP) {
      refreshCode();
    }
  }

  int counterAt(DateTime instant) {
    return (instant.millisecondsSinceEpoch / 1000 / widget.account.period)
        .floor();
  }

  DateTime now() => widget.clock?.call() ?? DateTime.now();

  void updateCounter() {
    final value = counterAt(now());
    if (value != counter) refreshCode();
  }

  void scheduleBoundary() {
    boundaryTimer?.cancel();
    final periodMs = widget.account.period * 1000;
    final instant = now();
    final current = instant.millisecondsSinceEpoch;
    boundaryTimer = Timer(
      Duration(
        milliseconds: counterAt(instant) != counter
            ? 0
            : periodMs - current % periodMs,
      ),
      refreshCode,
    );
  }

  void refreshCode() {
    if (!mounted || !valid) return;
    final instant = now();
    final current = accountCode(widget.account, at: instant);
    setState(() {
      displayedCode = current;
      counter = counterAt(instant);
    });
    scheduleBoundary();
  }

  /// Get a make OTP value
  String get otpCode => displayedCode!;

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

  Future<void> copyCode() async {
    final code = otpCode;
    final account = widget.account;
    try {
      await Clipboard.setData(ClipboardData(text: code));
    } on PlatformException {
      if (mounted && identical(widget.account, account)) showCopyFailure();
      return;
    } on MissingPluginException {
      if (mounted && identical(widget.account, account)) showCopyFailure();
      return;
    }
    if (!mounted || !identical(widget.account, account)) return;
    feedbackTimer?.cancel();
    setState(() => copiedCode = code);
    feedbackTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => copiedCode = null);
    });
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
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Column(
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
              Semantics(
                button: valid,
                label: valid
                    ? '${widget.account.issuer}${(widget.account.name ?? '').isEmpty ? '' : ', ${widget.account.name}'}. Code $formattedOtpCode. Double tap to copy.'
                    : '${widget.account.issuer}. Unable to generate code',
                excludeSemantics: true,
                onTap: valid ? copyCode : null,
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: valid ? copyCode : null,
                  child: Text(
                    !valid ? 'Unable to generate code' : formattedOtpCode,
                    style: CupertinoTheme.of(context).textTheme.textStyle
                        .copyWith(
                          color: CupertinoTheme.of(context).primaryColor,
                          fontSize: 36.0,
                          fontWeight: .bold,
                        ),
                  ),
                ),
              ),
              if (copiedCode != null)
                Semantics(
                  liveRegion: true,
                  label: 'Code copied',
                  excludeSemantics: true,
                  child: Text('Copied $copiedCode'),
                ),
              if (valid && widget.account.type == .HOTP)
                Text('Counter: ${widget.account.counter}'),
            ],
          ),
          Wrap(
            alignment: .end,
            crossAxisAlignment: .center,
            children: [
              if (valid && widget.account.type == .HOTP)
                CupertinoButton(
                  onPressed: advancing
                      ? null
                      : () async {
                          if (advancing) return;
                          final key = widget.accountKey;
                          final expected = widget.account.counter;
                          final observedAccount = widget.account;
                          if (key == null || expected == null) return;
                          setState(() => advancing = true);
                          try {
                            final confirmed = await showCupertinoDialog<bool>(
                              context: context,
                              builder: (context) => CupertinoAlertDialog(
                                title: const Text('Advance counter?'),
                                content: const Text(
                                  'This replaces the current code and advances the counter. The service may require resynchronization if a code is skipped.',
                                ),
                                actions: [
                                  CupertinoDialogAction(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  CupertinoDialogAction(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Next code'),
                                  ),
                                ],
                              ),
                            );
                            if (!mounted ||
                                confirmed != true ||
                                !identical(widget.account, observedAccount))
                              return;
                            await accounts.advanceHotp(
                              key,
                              expected,
                              expectedAccount: observedAccount,
                            );
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
                ExcludeSemantics(
                  child: ProgressTimerIndicator(
                    key: ValueKey(widget.account.period),
                    period: widget.account.period,
                  ),
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
                      content: Text(
                        'Do you want to delete the current password?',
                      ),
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
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
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
        ],
      ),
    );
  }
}
