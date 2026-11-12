import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:totp/totp.dart';

class DerivedTotp extends Totp {
  DerivedTotp(List<int> secret) : super(secret: secret);
  DerivedTotp.fromBase32(String secret) : super.fromBase32(secret: secret);
}

void main() {
  test('retains Base32 exports and non-default encoding support', () {
    final secret = '12345678901234567890'.codeUnits;
    final encoded = base32.encode(
      Uint8List.fromList(secret),
      encoding: Encoding.base32Hex,
    );
    final totp = Totp.fromBase32(
      secret: encoded,
      encoding: Encoding.base32Hex,
      algorithm: .sha1,
      digits: 6,
      period: 60,
    );
    final raw = Totp(secret: secret, algorithm: .sha1, digits: 6, period: 60);
    final time = DateTime.fromMillisecondsSinceEpoch(59000, isUtc: true);
    expect(totp.secret, secret);
    expect(totp.generate(time), raw.generate(time));
    expect(totp.validate(raw.generate(time), time), isTrue);
    expect(totp.period, 60);
  });

  test('primary and named constructors retain defaults and subclassing', () {
    final raw = DerivedTotp('12345678901234567890'.codeUnits);
    final encoded = DerivedTotp.fromBase32('GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ');
    expect(raw.algorithm, Algorithm.sha256);
    expect(raw.digits, 8);
    expect(raw.period, 30);
    final time = DateTime.fromMillisecondsSinceEpoch(59000, isUtc: true);
    expect(encoded.generate(time), raw.generate(time));
    expect(encoded.secret, raw.secret);
  });
}
