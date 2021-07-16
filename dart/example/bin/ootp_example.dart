import 'package:base32/base32.dart';
import 'package:ootp/ootp.dart';

void main(List<String> arguments) {
  final String encodedSecret = "MU2TSNRZG5TGKMBYGAZDCMJTMM3GIMJVMZRTINDFGI3WGZRVMQ4Q";
  final secret = base32.decode(encodedSecret);
  final totp = TOTP.secret(secret);

  final otpAuthUri = "otpauth://totp/OOTP:Tester?secret=${encodedSecret}&issuer=OOTP&period=${totp.period}&digits=${totp.digits}";

  print("otp: ${totp.make()}");
  print("uri: ${otpAuthUri}");
}
