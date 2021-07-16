import 'hotp.dart';

class TOTP {
  final HOTP hotp;
  final int digits;
  final int period;

  const TOTP(
    this.hotp, {
    this.digits = 6,
    this.period = 30,
  });

  factory TOTP.secret(
    List<int> secret, {
    int digits = 6,
    int period = 30,
  }) {
    return TOTP(
      HOTP(secret),
      digits: digits,
      period: period,
    );
  }

  int _create_counter() {
    final now = DateTime.now();
    final value = now.millisecondsSinceEpoch / 1000 / period;
    
    return value.floor();
  }

  String make() => hotp.make(
        counter: _create_counter(),
        digits: digits,
      );

  bool check(String otp, [int breadth = 0]) => hotp.check(
        otp,
        counter: _create_counter(),
        breadth: breadth,
      );
}
