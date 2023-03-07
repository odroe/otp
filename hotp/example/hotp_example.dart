import 'package:crypto/crypto.dart';
import 'package:hotp/hotp.dart';

void main() {
  final hotp = Hotp(
    secret: '12345678901234567890'.codeUnits,
    hash: sha1,
    digits: 6,
  );

  print(List.generate(10, (index) => hotp.generate(index)));
}
