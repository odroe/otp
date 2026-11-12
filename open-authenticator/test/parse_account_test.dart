import 'package:flutter_test/flutter_test.dart';
import 'package:authenticator/entities/parse_account.dart';

void main() {
  const secret = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ';
  test(
    'issuer-only QR creates the optional null name without losing the secret',
    () {
      final account = parseAccount(
        'otpauth://totp/Acme?issuer=Acme&secret=$secret',
      );
      expect(account.issuer, 'Acme');
      expect(account.name, isNull);
      expect(account.secret, secret);
    },
  );
  test('percent-encoded labels preserve issuer and account', () {
    final account = parseAccount(
      'otpauth://totp/Acme%3Aalice%40example.com?secret=$secret',
    );
    expect(account.issuer, 'Acme');
    expect(account.name, 'alice@example.com');
  });
  for (final uri in [
    'https://example.com/?secret=$secret',
    'otpauth://hotp/Acme?secret=$secret&counter=1',
    'otpauth://totp/Acme?secret=',
    'otpauth://totp/Acme?secret=not-a-secret',
    'otpauth://totp/Acme?secret=$secret&period=0',
    'otpauth://totp/Acme?secret=$secret&period=-1',
    'otpauth://totp/Acme?secret=$secret&digits=0',
    'otpauth://totp/Acme?secret=$secret&algorithm=SHA256',
  ]) {
    test(
      'reject malformed or unsupported QR (${uri.split('?').first}, case ${uri.hashCode})',
      () {
        expect(() => parseAccount(uri), throwsFormatException);
      },
    );
  }
}
