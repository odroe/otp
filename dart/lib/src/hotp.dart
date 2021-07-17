import 'dart:math';

import 'package:crypto/crypto.dart';

/// The HOTP algorithm default parameters, value that is SHA1.
const String OTP_ALGORITHM = 'sha1';

/// The RFC 4226 implentation of HOTP algorithm.
///
/// @see https://tools.ietf.org/html/rfc4226
///
/// Example
/// ```dart
/// final hotp = HOTP(secret);
/// final otpValue = hotp.make(
///   counter: 0,
///   digits: 6,
/// );
/// ```
class HOTP {
  /// The HOTP use HMAC-SHA1 secret.
  final List<int> secret;

  /// Create a HOTP instance.
  ///
  /// @param `secret` The HOTP secret.
  ///
  /// ```dart
  /// final hotp = HOTP(secret);
  /// ```
  const HOTP(this.secret);

  /// Get using HMAC SHA1 algorithm for secret.
  Hmac get hmac => new Hmac(sha1, secret);

  /// Make a OTP code.
  ///
  /// @param `counter` The counter value.
  /// @param `digits` The OTP code length.
  String make({
    int counter = 0,
    int digits = 6,
  }) {
    /// Get the counter bytes hmac sha1 bytes;
    final bytes = hmac.convert(_int_to_8_bytes(counter)).bytes;

    /// Get the offset of the last byte;
    final offset = bytes.elementAt(bytes.length - 1) & 0xf;
    final value = (bytes.elementAt(offset) & 0x7f) << 24 |
        (bytes.elementAt(offset + 1) & 0xff) << 16 |
        (bytes.elementAt(offset + 2) & 0xff) << 8 |
        (bytes.elementAt(offset + 3) & 0xff);

    /// get the value string
    final str = (value % pow(10, digits)).toString();

    return str.padLeft(digits, '0');
  }

  /// Chack a OTP code.
  ///
  /// @param `otp` The OTP code.
  /// @param `counter` The counter value.
  /// @param `digits` The OTP code length.
  bool check(
    String otp, {
    int counter = 0,
    int breadth = 0,
  }) {
    for (int index = counter - breadth; index <= counter + breadth; index++) {
      if (otp ==
          make(
            digits: otp.length,
            counter: index,
          )) {
        return true;
      }
    }
    return false;
  }

  /// A `int` input to 8 length `List<int>`.
  List<int> _int_to_8_bytes(int input) {
    final bit = 8;
    return List<int>.generate(bit, (index) => (input >> (bit * index)) & 0xff)
        .reversed
        .toList();
  }
}
