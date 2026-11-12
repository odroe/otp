import 'package:base32/base32.dart';

import 'account.entity.dart';

/// Validate before persistence. Unsupported OTP modes must not silently become TOTP.
AccountEntity parseAccount(String value) {
  final uri = Uri.parse(value);
  if (uri.scheme != 'otpauth' || uri.host != 'totp') {
    throw const FormatException('Only otpauth TOTP QR codes are supported.');
  }
  if ((uri.queryParameters['algorithm'] ?? 'SHA1').toUpperCase() != 'SHA1') {
    throw const FormatException('This version supports SHA1 accounts only.');
  }
  final label = Uri.decodeComponent(uri.path.replaceFirst(RegExp(r'^/'), ''));
  if (label.isEmpty) {
    throw const FormatException('An account label is required.');
  }
  final separator = label.indexOf(':');
  final issuer =
      uri.queryParameters['issuer'] ??
      (separator < 0 ? label : label.substring(0, separator));
  final name = separator < 0 ? label : label.substring(separator + 1);
  final account = AccountEntity()
    ..type = .TOTP
    ..issuer = issuer
    ..name = (name.isEmpty || (separator < 0 && name == issuer)) ? null : name
    ..secret = (uri.queryParameters['secret'] ?? '').toUpperCase()
    ..digits = int.tryParse(uri.queryParameters['digits'] ?? '6') ?? 0
    ..period = int.tryParse(uri.queryParameters['period'] ?? '30') ?? 0;
  if (account.issuer.isEmpty && (account.name?.isEmpty ?? true)) {
    throw const FormatException('An account label is required.');
  }
  validateAccount(account);
  return account;
}

/// Also used for legacy data: invalid records stay stored, not silently deleted.
void validateAccount(AccountEntity account) {
  final unpaddedLength = account.secret.replaceFirst(RegExp(r'=+$'), '').length;
  if (account.type != .TOTP ||
      account.period <= 0 ||
      account.digits < 6 ||
      account.digits > 8 ||
      !RegExp(r'^[A-Z2-7]+={0,6}$').hasMatch(account.secret.toUpperCase()) ||
      const {1, 3, 6}.contains(unpaddedLength % 8) ||
      base32.decode(account.secret.toUpperCase()).isEmpty) {
    throw const FormatException(
      'Invalid or unsupported authentication account.',
    );
  }
}
