import 'package:hotp/hotp.dart';

void main() {
  final hotp = Hotp(algorithm: .sha1, secret: '12345678901234567890'.codeUnits);
  print(hotp.generate(0)); // 755224
  print(hotp.verify('287082', 0, window: 1)); // 1
}
