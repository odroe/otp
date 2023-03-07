/// Support for doing something awesome.
///
/// More dartdocs go here.
library totp;

import 'package:crypto/crypto.dart';
import 'package:hotp/hotp.dart';

class Totp {
  final Hotp hotp;
  final int period;

  /// Create a new TOTP instance for a given [secret].
  Totp({
    required List<int> secret,
    Hash hash = sha1,
    int digits = 8,
    this.period = 30,
  }) : hotp = Hotp(secret: secret, hash: hash, digits: digits);

  /// Generate a new Time-based One-time Password (TOTP) for the
  /// given [dateTime].
  String generate(DateTime dateTime) {
    // Convert the [dateTime] to UTC.
    final utc = dateTime.isUtc ? dateTime : dateTime.toUtc();

    // Generate the counter value.
    final counter = utc.millisecondsSinceEpoch ~/ 1000 ~/ period;

    // Generate the Time-based One-time Password (TOTP).
    return hotp.generate(counter);
  }

  /// Generage a new Time-based One-time Password (TOTP) for the
  /// current time.
  String now() => generate(DateTime.now());
}
