import 'package:test/test.dart';
import 'package:totp/totp.dart';

void main() {
  test('constructors share RFC defaults and immutable key snapshots', () {
    final secret = '12345678901234567890'.codeUnits.toList();
    final raw = Totp(secret: secret);
    final encoded = Totp.fromBase32(secret: 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ');
    secret.clear();
    expect(raw.algorithm, Algorithm.sha1);
    expect(raw.digits, 6);
    expect(raw.period, const Duration(seconds: 30));
    final time = DateTime.fromMillisecondsSinceEpoch(59000, isUtc: true);
    expect(raw.generate(at: time), '287082');
    expect(encoded.generate(at: time), raw.generate(at: time));
    expect(encoded.secret, raw.secret);
    expect(() => raw.secret[0] = 0, throwsUnsupportedError);
  });
}
