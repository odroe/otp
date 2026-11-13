import 'package:base32/base32.dart';
import 'package:hotp/hotp.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:totp/totp.dart';

import 'account.entity.dart';
import 'parse_account.dart';

/// Retain the historical decoder for existing accounts.
String accountCode(AccountEntity account, {DateTime? at}) {
  validateAccount(account);
  final secret = base32.decode(account.secret.toUpperCase());
  if (account.format == .steam) {
    final milliseconds = (at ?? DateTime.now()).millisecondsSinceEpoch;
    if (milliseconds < 0)
      throw RangeError('Time must not precede the Unix epoch.');
    var counter = milliseconds ~/ 30000;
    final message = List<int>.filled(8, 0);
    for (var index = 7; index >= 0; index--) {
      message[index] = counter & 255;
      counter = counter ~/ 256;
    }
    final digest = crypto.Hmac(crypto.sha1, secret).convert(message).bytes;
    final offset = digest.last & 15;
    var value =
        ((digest[offset] & 127) << 24) |
        (digest[offset + 1] << 16) |
        (digest[offset + 2] << 8) |
        digest[offset + 3];
    const alphabet = '23456789BCDFGHJKMNPQRTVWXY';
    final result = StringBuffer();
    for (var i = 0; i < 5; i++) {
      result.write(alphabet[value % alphabet.length]);
      value ~/= alphabet.length;
    }
    return result.toString();
  }
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
