/// Support for doing something awesome.
///
/// More dartdocs go here.
library hotp;

import 'dart:math';

import 'package:crypto/crypto.dart';

extension _PadSecret on List<int> {
  /// https://www.rfc-editor.org/rfc/rfc6238
  ///
  /// sha512 -> 64
  /// sha256 -> 32
  /// sha1 -> 20
  repeat(Hash hash) {
    final length = findHmacHashLength(hash);
    final result = List<int>.filled(length, 0);

    for (var i = 0; i < length; i++) {
      result[i] = this[i % this.length];
    }

    return result;
  }

  int findHmacHashLength(Hash hash) {
    switch (hash) {
      case sha1:
        return 20;
      case sha256:
        return 32;
      case sha512:
        return 64;
    }

    throw ArgumentError.value(hash, 'hash', 'Invalid hash algorithm');
  }
}

class Hotp {
  /// Current HMAC instalce.
  final Hmac hmac;

  /// Password length.
  final int digits;

  /// Create a HOTP instance from [secret].
  ///
  /// The [digits] must be at least 6.
  ///
  /// The [hash] must be one of the following: [sha1], [sha256] or [sha512].
  ///
  /// The [secret] must be a list of bytes. minimum length is 128 bits.
  ///
  /// Refer to [RFC 4226](https://tools.ietf.org/html/rfc4226) for more details.
  Hotp({
    required List<int> secret,
    Hash hash = sha1,
    this.digits = 6,
  })  : assert(hash == sha1 || hash == sha256 || hash == sha512,
            'Only SHA1, SHA256 and SHA512 are supported'),
        assert(digits >= 6, 'The digits must be at least 6'),
        assert(secret.length >= 16, 'The secret must be at least 128 bits'),
        hmac = Hmac(hash, secret.repeat(hash));

  /// Generate a HMAC-based One-time Password (HOTP) for the given [counter].
  String generate(int counter) {
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
      if (generate(counter + index) == password) {
        return true;
      }
    }

    return false;
  }
}
