import 'dart:math' as math;

import 'package:base32/base32.dart' show base32;
import 'package:base32/encodings.dart' show Encoding;
import 'package:crypto/crypto.dart' as crypto;

export 'package:base32/base32.dart' show base32;
export 'package:base32/encodings.dart' show Encoding;

/// Counter bytes length.
const _counterBytesLength = 8;

/// The HMAC-based One-time Password (HOTP) algorithm.
enum Algorithm {
  /// The SHA1 algorithm.
  sha1(crypto.sha1, 20),

  /// The SHA256 algorithm.
  sha256(crypto.sha256, 32),

  /// The SHA512 algorithm.
  sha512(crypto.sha512, 64);

  /// The algorithm [crypto.Hash].
  final crypto.Hash hash;

  /// The algorithm bytes length.
  final int length;

  /// Create a new [Algorithm].
  const Algorithm(this.hash, this.length);

  /// Repeat the secret key to the algorithm bytes length.
  List<int> repeat(List<int> secret) =>
      List<int>.generate(length, (index) => secret[index % secret.length]);
}

/// An implementation of the HMAC-based One-time Password (HOTP).
///
/// [rfc]: https://tools.ietf.org/html/rfc4226
class Hotp {
  /// Current HMAC instalce.
  final crypto.Hmac hmac;

  /// Password length.
  final int digits;

  /// Hashing algorithm used
  final Algorithm algorithm;

  /// HMAC-based One-time Password (HOTP) secret key.
  final List<int> secret;

  /// Create a HOTP instance from [secret].
  ///
  /// Refer to [RFC 4226](https://tools.ietf.org/html/rfc4226) for more details.
  Hotp({
    required this.secret,
    this.algorithm = Algorithm.sha1,
    this.digits = 6,
  })  : assert(digits >= 6, 'The digits must be at least 6'),
        hmac = crypto.Hmac(algorithm.hash, algorithm.repeat(secret));

  /// Create a HOTP instance from [secret] as a base32 encoded string.
  factory Hotp.fromBase32({
    required String secret,
    Algorithm algorithm = Algorithm.sha1,
    int digits = 6,
    Encoding encoding = Encoding.standardRFC4648,
  }) =>
      Hotp(
        algorithm: algorithm,
        secret: base32.decode(secret, encoding: encoding),
        digits: digits,
      );

  /// Generate a HMAC-based One-time Password (HOTP) for the given [counter].
  String generate(int counter) {
    // Generate the counter bytes.
    final bytes = List<int>.generate(_counterBytesLength,
            (index) => (counter >> (_counterBytesLength * index)) & 0xff)
        .reversed
        .toList();

    // Convert the counter bytes to a HMAC digest bytes.
    final digest = hmac.convert(bytes).bytes;

    // Generate the offset of the last byte.
    final offset = digest.last & 0xf;

    // Generate One-Time Password (OTP) binary.
    final binary = (digest[offset] & 0x7f) << 24 |
        (digest[offset + 1] & 0xff) << 16 |
        (digest[offset + 2] & 0xff) << 8 |
        (digest[offset + 3] & 0xff);

    // Generate One-Time Password (OTP) string.
    final password = (binary % math.pow(10, digits)).toString();

    // Return the One-Time Password (OTP) string.
    //
    // If the password is less than [digits] digits, then it is padded with
    // leading zeros.
    return password.padLeft(digits, '0');
  }

  /// Validate the given [password] for the given [counter].
  bool validate(
    String password,
    int counter, {
    int breadth = 0,
  }) {
    for (int index = 0; index <= breadth; index++) {
      if (generate(counter + index) == password) {
        return true;
      }
    }

    return false;
  }
}
