import 'package:crypto/crypto.dart';
import 'package:totp/totp.dart';

void main() {
  final totp = Totp(
    secret: '12345678901234567890'.codeUnits,
    hash: sha1,
  );
  final datetime = DateTime.parse('1970-01-01T00:00:59Z');

  print(totp.generate(datetime)); // 94287082
}
