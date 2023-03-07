/// Support for doing something awesome.
///
/// More dartdocs go here.
library hotp;

import 'dart:math';

import 'package:crypto/crypto.dart';

class Hotp {
  final Hmac hmac;
  final int digits;

  /// Creare a HOTP instance for the given [hmac] and [digits].
  ///
  /// The [digits] must be at least 6.
  ///
  /// Refer to [RFC 4226](https://tools.ietf.org/html/rfc4226) for more details.
  const Hotp({
    required this.hmac,
    this.digits = 6,
  }) : assert(digits >= 6, 'The digits must be at least 6');

  /// Create a HOTP instance from [secret].
  ///
  /// The [digits] must be at least 6.
  ///
  /// The [hash] must be one of the following: [sha1], [sha256] or [sha512].
  ///
  /// The [secret] must be a list of bytes. minimum length is 128 bits.
  ///
  /// Refer to [RFC 4226](https://tools.ietf.org/html/rfc4226) for more details.
  Hotp.fromSecret({
    required List<int> secret,
    Hash hash = sha1,
    this.digits = 6,
  })  : assert(hash == sha1 || hash == sha256 || hash == sha512,
            'Only SHA1, SHA256 and SHA512 are supported'),
        assert(digits >= 6, 'The digits must be at least 6'),
        assert(secret.length >= 16, 'The secret must be at least 128 bits'),
        hmac = Hmac(hash, secret);

  /// Generate a One-Time Password (OTP) for the given [counter].
  String generage(int counter) {
    // Generate the counter bytes.
    final bytes =
        List<int>.generate(8, (index) => (counter >> (8 * index)) & 0xff)
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
    final password = (binary % pow(10, digits)).toString();

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
      if (generage(counter + index) == password) {
        return true;
      }
    }

    return false;
  }
}
