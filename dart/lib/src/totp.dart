import 'hotp.dart';

/// The RFC 6238 algorithm implementation.
/// 
/// @see https://tools.ietf.org/html/rfc6238
///
/// Example 1:
/// ```dart
/// final hoto = HOTP(secret);
/// final totp = TOTP(
///    hoto,
///    digits: 6,
///    period: 30,
/// );
/// final value = totp.make();
/// ```
/// Example 2:
/// ```dart
/// final totp = TOTP.secret(
///   secret,
///   digits: 6,
///   period: 30,
/// );
/// final value = totp.make();
/// ```
class TOTP {

  /// The REC 4226 algorithm implementation.
  final HOTP hotp;

  /// digits - The number of digits in the code.
  final int digits;

  /// period - The number of seconds in the time period.
  final int period;

  /// Create a new TOTP instance.
  /// 
  /// @param `hotp` - The HOTP instance.
  /// @param `digits` - The number of digits in the code.
  /// @param `period` - The number of seconds in the time period.
  const TOTP(
    this.hotp, {
    this.digits = 6,
    this.period = 30,
  });

  /// Create a new TOTP instance for a given secret.
  /// 
  /// @param `secret` - The secret.
  /// @param `digits` - The number of digits in the code.
  /// @param `period` - The number of seconds in the time period.
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

  /// Using current time create a counter value.
  int _create_counter() {
    final now = DateTime.now();
    final value = now.millisecondsSinceEpoch / 1000 / period;

    return value.floor();
  }

  /// Make a OTP value.
  String make() => hotp.make(
        counter: _create_counter(),
        digits: digits,
      );

  /// Chack a OTP value.
  /// 
  /// @param `otp` - The OTP value.
  /// @param `breadth` - The number of OTP values to check.
  bool check(String otp, [int breadth = 0]) => hotp.check(
        otp,
        counter: _create_counter(),
        breadth: breadth,
      );
}
