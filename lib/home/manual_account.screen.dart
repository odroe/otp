import 'package:cupertino_ui/cupertino_ui.dart';

import '../entities/parse_account.dart';

enum _ManualMode() {
  totp,
  hotp,
  steam,
}

class const ManualAccountScreen() extends StatefulWidget {
  @override
  State<ManualAccountScreen> createState() => _ManualAccountScreenState();
}

class _ManualAccountScreenState() extends State<ManualAccountScreen> {
  final issuer = TextEditingController();
  final name = TextEditingController();
  final secret = TextEditingController();
  final steamSecret = TextEditingController();
  final digits = TextEditingController(text: '6');
  final period = TextEditingController(text: '30');
  final counter = TextEditingController();
  _ManualMode mode = .totp;
  String algorithm = 'SHA1';
  String? error;

  @override
  void dispose() {
    issuer.dispose();
    name.dispose();
    secret.dispose();
    steamSecret.dispose();
    digits.dispose();
    period.dispose();
    counter.dispose();
    super.dispose();
  }

  void submit() {
    try {
      final account = accountFromFields(
        type: mode == .hotp ? .HOTP : .TOTP,
        issuer: issuer.text.trim(),
        name: name.text.trim(),
        secret: mode == .steam
            ? steamSecretFromBase64(steamSecret.text.trim())
            : secret.text.trim(),
        algorithm: mode == .steam ? 'SHA1' : algorithm,
        digits: digits.text,
        period: mode == .steam ? '30' : period.text,
        counter: mode == .hotp ? counter.text : null,
        format: mode == .steam ? .steam : .decimal,
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
          CupertinoSlidingSegmentedControl<_ManualMode>(
            groupValue: mode,
            children: const {
              .totp: Text('TOTP'),
              .hotp: Text('HOTP'),
              .steam: Text('Steam'),
            },
            onValueChanged: (value) {
              if (value != null) setState(() => mode = value);
            },
          ),
          field('Service / issuer', issuer),
          field('Account (optional)', name),
          field(
            mode == .steam ? 'Steam shared secret (Base64)' : 'Base32 secret',
            mode == .steam ? steamSecret : secret,
            obscure: true,
          ),
          if (mode == .steam)
            const Text(
              'Requires an existing Steam Guard shared secret. This does not enroll a device or approve confirmations.',
            ),
          if (mode != .steam)
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
          if (mode != .steam) field('Digits (6–8)', digits, numeric: true),
          if (mode == .totp) field('Period in seconds', period, numeric: true),
          if (mode == .hotp) field('Initial counter', counter, numeric: true),
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
