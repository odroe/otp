import 'package:totp/totp.dart';

void main() {
  final totp = Totp(secret: '12345678901234567890'.codeUnits);
  final at = DateTime.parse('1970-01-01T00:00:59Z');
  print(totp.generate(at: at)); // 287082
  print(totp.verify('287082', at: at)); // 1 (the matching time step)
  print(totp.remainingAt(at)); // 0:00:01.000000
}
