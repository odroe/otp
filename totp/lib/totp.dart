import 'package:hotp/hotp.dart';

export 'package:hotp/hotp.dart' show Algorithm, Encoding, base32;

/// An implementation of the Time-based One-time Password (TOTP).
///
/// See: https://tools.ietf.org/html/rfc6238
class Totp {
  /// The underlying HMAC-based One-time Password (HOTP) instance.
  final Hotp _hotp;

  /// period of TOTP password
  final int period;

  /// Return the TOTP secret key.
  List<int> get secret => _hotp.secret;

  /// Return the TOTP password length.
  int get digits => _hotp.digits;

  /// Return the TOTP hashing algorithm.
  Algorithm get algorithm => _hotp.algorithm;

  /// Create a new TOTP instance for a given [secret].
  Totp({
    required List<int> secret,
    Algorithm algorithm = Algorithm.sha256,
    int digits = 8,
    this.period = 30,
  }) : _hotp = Hotp(
          algorithm: algorithm,
          secret: secret,
          digits: digits,
        );

  /// Create a new TOTP instance for a given Base32 encoded [secret].
  Totp.fromBase32({
    required String secret,
    Algorithm algorithm = Algorithm.sha256,
    int digits = 8,
    this.period = 30,
    Encoding encoding = Encoding.standardRFC4648,
  }) : _hotp = Hotp.fromBase32(
          secret: secret,
          algorithm: algorithm,
          digits: digits,
          encoding: encoding,
        );

  /// Generate a new Time-based One-time Password (TOTP) for the
  /// given [dateTime].
  String generate(DateTime dateTime) {
    // Convert the [dateTime] to UTC.
    final utc = dateTime.isUtc ? dateTime : dateTime.toUtc();

    // Generate the counter value.
    final counter = utc.millisecondsSinceEpoch ~/ 1000 ~/ period;

    // Generate the Time-based One-time Password (TOTP).
    return _hotp.generate(counter);
  }

  /// Generage a new Time-based One-time Password (TOTP) for the
  /// current time.
  String now() => generate(DateTime.now());

  /// Generate remaining time of the TOTP code by period
  int get remaining {
    // Convert current time to second
    int currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // Generate the counter value.
    return currentTime % period;
  }

  /// Validate a given [password] for the given [dateTime].
  bool validate(String password, DateTime dateTime) =>
      generate(dateTime) == password;
}
