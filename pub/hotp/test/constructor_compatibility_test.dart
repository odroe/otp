import 'package:hotp/hotp.dart';
import 'package:test/test.dart';

void main() {
  test('primary constructor retains RFC defaults', () {
    final hotp = Hotp(secret: '12345678901234567890'.codeUnits);
    expect(hotp.algorithm, Algorithm.sha1);
    expect(hotp.digits, 6);
    expect(hotp.generate(0), '755224');
  });
}
