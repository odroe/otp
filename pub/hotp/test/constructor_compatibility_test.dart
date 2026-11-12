import 'package:hotp/hotp.dart';
import 'package:test/test.dart';

class DerivedHotp extends Hotp {
  DerivedHotp(List<int> secret) : super(secret: secret);
}

void main() {
  test('primary constructor retains defaults and subclassing', () {
    final hotp = DerivedHotp('12345678901234567890'.codeUnits);
    expect(hotp.algorithm, Algorithm.sha1);
    expect(hotp.digits, 6);
    expect(hotp.generate(0), '755224');
  });
}
