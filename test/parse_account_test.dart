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
  test('empty issuer with a valid account label remains supported', () {
    final account = parseAccount('otpauth://totp/user?issuer=&secret=$secret');
    expect(account.issuer, '');
    expect(account.name, 'user');
  });
  test(
    'explicit name equal to issuer stays distinct from issuer-only label',
    () {
      final explicit = parseAccount(
        'otpauth://totp/Acme:Acme?issuer=Acme&secret=$secret',
      );
      final issuerOnly = parseAccount(
        'otpauth://totp/Acme?issuer=Acme&secret=$secret',
      );
      expect(explicit.name, 'Acme');
      expect(issuerOnly.name, isNull);
      expect(
        '${explicit.issuer}:${explicit.name}',
        isNot('${issuerOnly.issuer}:${issuerOnly.name}'),
      );
    },
  );
  for (final secretLength in [1, 3, 6, 9, 11, 14, 33, 35, 38]) {
    test('reject impossible Base32 length $secretLength', () {
      final invalid = List.filled(secretLength, 'A').join();
      expect(
        () => parseAccount('otpauth://totp/Acme?secret=$invalid'),
        throwsFormatException,
      );
    });
  }
  for (final value in [
    'MY',
    'MY======',
    'MZXQ',
    'MZXQ====',
    'MZXW6',
    'MZXW6===',
    'MZXW6YQ',
    'MZXW6YQ=',
    'MZXW6YTB',
  ]) {
    test('accept supported Base32 length and padding: $value', () {
      expect(parseAccount('otpauth://totp/Acme?secret=$value').secret, value);
    });
  }
  for (final uri in [
    'otpauth://totp/?issuer=&secret=$secret',
    'otpauth://totp/?issuer=Acme&secret=$secret',
    'https://example.com/?secret=$secret',
    'otpauth://totp/Acme?secret=',
    'otpauth://totp/Acme?secret=not-a-secret',
    'otpauth://totp/Acme?secret=$secret&period=0',
    'otpauth://totp/Acme?secret=$secret&period=-1',
    'otpauth://totp/Acme?secret=$secret&digits=0',
  ]) {
    test(
      'reject malformed or unsupported QR (${uri.split('?').first}, case ${uri.hashCode})',
      () {
        expect(() => parseAccount(uri), throwsFormatException);
      },
    );
  }
  test('supports HOTP counters and configured algorithms', () {
    final account = parseAccount(
      'otpauth://hotp/Acme:user?secret=$secret&counter=7&algorithm=SHA256&digits=8',
    );
    expect(account.type.name, 'HOTP');
    expect(account.counter, 7);
    expect(account.algorithm.name, 'sha256');
    expect(account.digits, 8);
  });
  test('surfaces conflicting label and issuer', () {
    final result = parseProvisioning(
      'otpauth://totp/Old:user?secret=$secret&issuer=New',
    );
    expect(result.issuerMismatch, isTrue);
    expect(result.labelIssuer, 'Old');
    expect(result.account.issuer, 'New');
  });
  for (final query in [
    'counter=1&counter=2',
    'counter=-1',
    'algorithm=SHA3&counter=1',
    'period=30&counter=1',
    '',
  ]) {
    test('rejects invalid HOTP fields: $query', () {
      expect(
        () => parseAccount('otpauth://hotp/Acme?secret=$secret&$query'),
        throwsFormatException,
      );
    });
  }
  test('rejects non-ASCII keys before normalization', () {
    expect(
      () => parseAccount('otpauth://totp/Acme?secret=ıA'),
      throwsFormatException,
    );
  });
}
