import 'package:base32/base32.dart';
import 'package:hotp/hotp.dart';
import 'package:totp/totp.dart';

import 'account.entity.dart';
import 'parse_account.dart';

/// Retain the historical decoder for existing accounts.
String accountCode(AccountEntity account, {DateTime? at}) {
  validateAccount(account);
  final secret = base32.decode(account.secret.toUpperCase());
  if (account.type == .HOTP) {
    return Hotp(
      secret: secret,
      algorithm: account.algorithm,
      digits: account.digits,
    ).generate(account.counter!);
  }
  return Totp(
    secret: secret,
    algorithm: account.algorithm,
    digits: account.digits,
    period: Duration(seconds: account.period),
  ).generate(at: at);
}
