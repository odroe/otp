import 'package:hotp/hotp.dart';

void main() {
  final hotp = Hotp(
    algorithm: Algorithm.sha1,
    secret: '12345678901234567890'.codeUnits,
    digits: 6,
  );

  print(List.generate(10, (index) => hotp.generate(index)));
}
