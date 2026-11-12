import 'package:hotp/hotp.dart';

export 'package:hotp/hotp.dart' show Algorithm;

/// An immutable RFC 6238 generator using Unix-epoch time steps.
///
/// Defaults are SHA1, six digits, and a 30-second period. Keys are copied
/// without repetition or truncation. [period] must be positive whole seconds;
/// invalid periods throw [ArgumentError]. On JavaScript, periods are limited
/// to 9007199254 seconds so their microseconds remain exact integers.
/// Native runtimes retain the full [Duration] range. Key and digit validation follow
/// [Hotp.new]. Timestamps before the Unix epoch throw [ArgumentError].
final class Totp({
  required List<int> secret,
  Algorithm algorithm = .sha1,
  int digits = 6,
  Duration period = const Duration(seconds: 30),
}) {
  final Hotp _hotp = Hotp(secret: secret, algorithm: algorithm, digits: digits);

  /// The positive, whole-second lifetime of each code.
  ///
  /// On JavaScript this is at most 9007199254 seconds to preserve microseconds.
  final Duration period = _checkPeriod(period);

  /// An immutable snapshot of the key, which must be kept secret.
  List<int> get secret => _hotp.secret;

  /// The number of decimal digits in each code.
  int get digits => _hotp.digits;

  /// The hash algorithm used to generate codes.
  Algorithm get algorithm => _hotp.algorithm;

  /// Decodes a canonical RFC 4648 Base32 key and creates a generator.
  ///
  /// ASCII letter case is ignored and valid padding is optional. Invalid
  /// characters, padding, lengths, or unused bits throw [FormatException].
  /// Key material is never included in decoding errors.
  factory fromBase32({
    required String secret,
    Algorithm algorithm = .sha1,
    int digits = 6,
    Duration period = const Duration(seconds: 30),
  }) => Totp(
    secret: Hotp.fromBase32(secret: secret).secret,
    algorithm: algorithm,
    digits: digits,
    period: period,
  );

  /// Generates a code at [at], or at the current time if omitted.
  ///
  /// Time steps are the Unix-epoch seconds divided by [period], rounded down.
  /// An exact period boundary belongs to the next step.
  String generate({DateTime? at}) =>
      _hotp.generate(_counterAt(at ?? DateTime.now()));

  /// Returns the matching time-step number, or `null` if no code matches.
  ///
  /// Uses [at], or the current time if omitted. [window] counts steps on each
  /// side of the current step; zero checks only the current step. Checks the
  /// current step first, then increasing distances, preferring the past when
  /// distances tie. The result is a step number, not an epoch timestamp.
  ///
  /// The search is clipped to zero through [Hotp.maxCounter]. Negative windows
  /// or windows above that exact integer range throw [RangeError], even for
  /// malformed codes. Codes must contain exactly [digits] ASCII decimal digits;
  /// malformed codes return `null` after argument validation.
  ///
  /// This method does not prevent replay or store verification state. Callers
  /// must persist consumed steps and enforce attempt limits. Use a small,
  /// application-controlled window: work and guessing risk grow with its size.
  int? verify(String code, {DateTime? at, int window = 0}) {
    final counter = _counterAt(at ?? DateTime.now());
    if (window < 0 || window > Hotp.maxCounter) {
      throw RangeError.range(window, 0, Hotp.maxCounter, 'window');
    }
    if (code.length != digits || !RegExp(r'^[0-9]+$').hasMatch(code)) {
      return null;
    }
    if (_hotp.verify(code, counter) != null) return counter;
    final past = window < counter ? window : counter;
    final futureLimit = Hotp.maxCounter - counter;
    final future = window < futureLimit ? window : futureLimit;
    final limit = past > future ? past : future;
    if (limit == 0) return null;
    for (var distance = 1; ; distance++) {
      if (distance <= past && _hotp.verify(code, counter - distance) != null) {
        return counter - distance;
      }
      if (distance <= future &&
          _hotp.verify(code, counter + distance) != null) {
        return counter + distance;
      }
      if (distance == limit) return null;
    }
  }

  /// The time remaining until the current code expires.
  Duration get remaining => remainingAt(DateTime.now());

  /// Returns the precise time until the next period boundary at [at].
  ///
  /// Returns the full [period] at an exact boundary. Retains subsecond precision
  /// without converting the entire timestamp to microseconds, which can lose
  /// precision in JavaScript for dates far from the Unix epoch.
  Duration remainingAt(DateTime at) {
    final seconds = _secondsSinceEpoch(at);
    final secondsLeft = period.inSeconds - seconds % period.inSeconds;
    return Duration(seconds: secondsLeft) -
        Duration(milliseconds: at.millisecond, microseconds: at.microsecond);
  }

  int _counterAt(DateTime at) => _secondsSinceEpoch(at) ~/ period.inSeconds;
}

int _secondsSinceEpoch(DateTime at) {
  if (at.isBefore(DateTime.fromMillisecondsSinceEpoch(0, isUtc: true))) {
    throw ArgumentError.value(at, 'at', 'must not precede the Unix epoch');
  }
  return at.millisecondsSinceEpoch ~/ 1000;
}

Duration _checkPeriod(Duration period) {
  if (period <= Duration.zero ||
      (identical(1, 1.0) && period.inMicroseconds > 9007199254740991) ||
      period.inMicroseconds % Duration.microsecondsPerSecond != 0) {
    throw ArgumentError.value(
      period,
      'period',
      'must be positive whole seconds within the runtime precision range',
    );
  }
  return period;
}
