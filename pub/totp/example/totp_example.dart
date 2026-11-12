import 'package:totp/totp.dart';

void main() {
  final totp = Totp(
    algorithm: Algorithm.sha1,
    secret: '12345678901234567890'.codeUnits,
  );
  final datetime = DateTime.parse('1970-01-01T00:00:59Z');

  print(totp.generate(datetime)); // 94287082
}
