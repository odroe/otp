import 'package:base32/base32.dart' show base32;
import 'package:base32/encodings.dart' show Encoding;
import 'package:hotp/hotp.dart';

export 'package:base32/base32.dart' show base32;
export 'package:base32/encodings.dart' show Encoding;
export 'package:hotp/hotp.dart' show Algorithm;

/// An implementation of the Time-based One-time Password (TOTP).
///
/// See: https://tools.ietf.org/html/rfc6238
class Totp({
  required List<int> secret,
  Algorithm algorithm = .sha256,
  int digits = 8,

  /// Period of the TOTP password in seconds.
  final int period = 30,
}) {
  /// The underlying HMAC-based One-time Password (HOTP) instance.
  final Hotp _hotp = Hotp(algorithm: algorithm, secret: secret, digits: digits);

  /// Return the TOTP secret key.
  List<int> get secret => _hotp.secret;

  /// Return the TOTP password length.
  int get digits => _hotp.digits;

  /// Return the TOTP hashing algorithm.
  Algorithm get algorithm => _hotp.algorithm;

  /// Create a new TOTP instance for a given Base32 encoded [secret].
  Totp.fromBase32({
    required String secret,
    Algorithm algorithm = .sha256,
    int digits = 8,
    int period = 30,
    Encoding encoding = .standardRFC4648,
  }) : this(
         secret: base32.decode(secret, encoding: encoding),
         algorithm: algorithm,
         digits: digits,
         period: period,
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

  /// Whole seconds remaining until the current TOTP code expires.
  ///
  /// Returns [period] at a period boundary, counting down to one during
  /// the final second of that period.
  int get remaining => remainingAt(DateTime.now());

  /// Whole seconds remaining at [dateTime] until its TOTP code expires.
  ///
  /// Uses the same Unix-epoch time steps as [generate].
  int remainingAt(DateTime dateTime) {
    final seconds = dateTime.millisecondsSinceEpoch ~/ 1000;
    return period - seconds % period;
  }

  /// Validate a given [password] for the given [dateTime].
  bool validate(String password, DateTime dateTime) =>
      generate(dateTime) == password;
}
