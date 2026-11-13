import 'package:base32/base32.dart';
import 'package:hotp/hotp.dart';

import 'account.entity.dart';

const maxProvisioningLength = 8192;
const maxSecretLength = 4096;
int get maxPeriod => identical(1, 1.0) ? 9007199254 : 9223372036854;

class Provisioning(final AccountEntity account, {final String? labelIssuer}) {
  bool get issuerMismatch =>
      labelIssuer != null && labelIssuer != account.issuer;
}

AccountEntity parseAccount(String value) => parseProvisioning(value).account;

Provisioning parseProvisioning(String value) {
  if (value.length > maxProvisioningLength) {
    throw const FormatException('Provisioning input is too long.');
  }
  if (RegExp(r'%(?![0-9a-fA-F]{2})').hasMatch(value)) {
    throw const FormatException('Malformed URI escape.');
  }
  try {
    final uri = Uri.parse(value);
    if (uri.scheme != 'otpauth' ||
        !{'totp', 'hotp'}.contains(uri.host) ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        uri.hasFragment) {
      throw const FormatException('Use an otpauth TOTP or HOTP URI.');
    }
    final params = uri.queryParametersAll;
    for (final key in [
      'secret',
      'issuer',
      'algorithm',
      'digits',
      'period',
      'counter',
    ]) {
      if ((params[key]?.length ?? 0) > 1) {
        throw FormatException('Repeated $key parameter.');
      }
    }
    final query = uri.queryParameters;
    final label = Uri.decodeComponent(uri.path.replaceFirst(RegExp(r'^/'), ''));
    if (label.isEmpty)
      throw const FormatException('An account label is required.');
    final colon = label.indexOf(':');
    final labelIssuer = colon < 0 ? null : label.substring(0, colon);
    final issuer = query['issuer'] ?? labelIssuer ?? label;
    final name = colon < 0 ? label : label.substring(colon + 1);
    if (uri.host == 'totp' && query.containsKey('counter')) {
      throw const FormatException('TOTP does not use a counter parameter.');
    }
    if (uri.host == 'hotp' && query.containsKey('period')) {
      throw const FormatException('HOTP does not use a period parameter.');
    }
    return Provisioning(
      accountFromFields(
        type: uri.host == 'totp' ? .TOTP : .HOTP,
        issuer: issuer,
        name: colon < 0 && name == issuer ? null : name,
        secret: query['secret'] ?? '',
        algorithm: query['algorithm'] ?? 'SHA1',
        digits: query['digits'] ?? '6',
        period: query['period'] ?? '30',
        counter: query['counter'],
      ),
      labelIssuer: labelIssuer,
    );
  } on FormatException catch (error) {
    // Parser-provided error sources can contain the provisioning secret.
    if (error.source == null && !error.message.startsWith('Invalid')) rethrow;
    throw const FormatException('Malformed provisioning URI or Base32 secret.');
  }
}

int _decimal(String value, String field, int maximum, {int minimum = 0}) {
  if (value.length > 20 || !RegExp(r'^[0-9]+$').hasMatch(value)) {
    throw FormatException('$field must be a whole decimal number.');
  }
  final number = BigInt.parse(value);
  if (number < BigInt.from(minimum) || number > BigInt.from(maximum)) {
    throw FormatException('$field must be between $minimum and $maximum.');
  }
  return number.toInt();
}

/// Validates manual and QR inputs in the same way before storing either.
AccountEntity accountFromFields({
  required AccountType type,
  required String issuer,
  String? name,
  required String secret,
  String algorithm = 'SHA1',
  String digits = '6',
  String period = '30',
  String? counter,
}) {
  if (issuer.length > 1024 ||
      (name?.length ?? 0) > 1024 ||
      secret.length > maxSecretLength ||
      algorithm.length > 16) {
    throw const FormatException('Account input is too long.');
  }
  if (issuer.isEmpty && (name?.isEmpty ?? true)) {
    throw const FormatException('An account label is required.');
  }
  final hash = switch (algorithm.toUpperCase()) {
    'SHA1' => Algorithm.sha1,
    'SHA256' => Algorithm.sha256,
    'SHA512' => Algorithm.sha512,
    _ => throw const FormatException(
      'Algorithm must be SHA1, SHA256 or SHA512.',
    ),
  };
  Hotp.fromBase32(secret: secret);
  return AccountEntity()
    ..type = type
    ..issuer = issuer
    ..name = name == '' ? null : name
    ..secret = secret.toUpperCase()
    ..algorithm = hash
    ..digits = _decimal(digits, 'Digits', 8, minimum: 6)
    ..period = type == .TOTP
        ? _decimal(period, 'Period', maxPeriod, minimum: 1)
        : 30
    ..counter = type == .HOTP
        ? _decimal(counter ?? '', 'Counter', Hotp.maxCounter)
        : null;
}

/// Legacy keys retain their original decoding; malformed records are not deleted.
void validateAccount(AccountEntity account) {
  final unpaddedLength = account.secret.replaceFirst(RegExp(r'=+$'), '').length;
  if ((account.type == .TOTP &&
          (account.period <= 0 || account.period > maxPeriod)) ||
      (account.type == .HOTP &&
          (account.counter == null ||
              account.counter! < 0 ||
              account.counter! > Hotp.maxCounter)) ||
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
