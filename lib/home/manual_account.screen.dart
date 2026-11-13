import 'package:cupertino_ui/cupertino_ui.dart';

import '../entities/account.entity.dart';
import '../entities/parse_account.dart';

class const ManualAccountScreen() extends StatefulWidget {
  @override
  State<ManualAccountScreen> createState() => _ManualAccountScreenState();
}

class _ManualAccountScreenState() extends State<ManualAccountScreen> {
  final issuer = TextEditingController();
  final name = TextEditingController();
  final secret = TextEditingController();
  final digits = TextEditingController(text: '6');
  final period = TextEditingController(text: '30');
  final counter = TextEditingController();
  AccountType type = .TOTP;
  String algorithm = 'SHA1';
  String? error;

  @override
  void dispose() {
    issuer.dispose();
    name.dispose();
    secret.dispose();
    digits.dispose();
    period.dispose();
    counter.dispose();
    super.dispose();
  }

  void submit() {
    try {
      final account = accountFromFields(
        type: type,
        issuer: issuer.text.trim(),
        name: name.text.trim(),
        secret: secret.text.trim(),
        algorithm: algorithm,
        digits: digits.text,
        period: period.text,
        counter: type == .HOTP ? counter.text : null,
      );
      Navigator.of(context).pop(account);
    } on FormatException catch (e) {
      setState(() => error = e.message);
    }
  }

  Widget field(
    String label,
    TextEditingController controller, {
    bool numeric = false,
    bool obscure = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: CupertinoTextField(
      controller: controller,
      placeholder: label,
      obscureText: obscure,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      autocorrect: false,
      enableSuggestions: false,
    ),
  );

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    navigationBar: const CupertinoNavigationBar(middle: Text('Manual entry')),
    child: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CupertinoSlidingSegmentedControl<AccountType>(
            groupValue: type,
            children: const {.TOTP: Text('TOTP'), .HOTP: Text('HOTP')},
            onValueChanged: (value) {
              if (value != null) setState(() => type = value);
            },
          ),
          field('Service / issuer', issuer),
          field('Account (optional)', name),
          field('Base32 secret', secret, obscure: true),
          CupertinoSlidingSegmentedControl<String>(
            groupValue: algorithm,
            children: const {
              'SHA1': Text('SHA-1'),
              'SHA256': Text('SHA-256'),
              'SHA512': Text('SHA-512'),
            },
            onValueChanged: (value) {
              if (value != null) setState(() => algorithm = value);
            },
          ),
          field('Digits (6–8)', digits, numeric: true),
          if (type == .TOTP)
            field('Period in seconds', period, numeric: true)
          else
            field('Initial counter', counter, numeric: true),
          if (error != null)
            Text(
              error!,
              style: const TextStyle(color: CupertinoColors.systemRed),
            ),
          CupertinoButton.filled(
            onPressed: submit,
            child: const Text('Review'),
          ),
        ],
      ),
    ),
  );
}
