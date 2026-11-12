import 'package:base32/base32.dart' as encoding;
import 'package:crypto/crypto.dart' as crypto;

/// The hash algorithm used to generate a one-time password.
enum Algorithm() {
  /// HMAC-SHA1, the RFC 4226 default.
  sha1,

  /// HMAC-SHA256.
  sha256,

  /// HMAC-SHA512.
  sha512,
}

/// An immutable RFC 4226 generator with caller-managed counters.
///
/// The key is copied without repetition or truncation. [secret] must contain
/// at least one byte, each in the range 0 through 255. RFC 4226 recommends
/// randomly generated keys of at least 128 bits; shorter existing keys remain
/// supported for compatibility. [digits] must be between 6 and 8, inclusive.
/// Invalid keys throw [ArgumentError]; invalid digit counts throw [RangeError].
final class Hotp({
  required List<int> secret,

  /// The hash algorithm used for each code.
  final Algorithm algorithm = .sha1,
  int digits = 6,
}) {
  /// An immutable snapshot of the secret key.
  ///
  /// Treat these bytes as sensitive data. They are never included in errors.
  final List<int> secret = _copySecret(secret);

  /// The number of decimal digits in each code.
  final int digits = _checkDigits(digits);

  // Late initialization accesses the validated fields, not constructor inputs.
  late final crypto.Hmac _hmac = crypto.Hmac(_hash(algorithm), secret);

  /// The largest exact counter supported by this runtime.
  ///
  /// Native runtimes support 2^63 - 1; JavaScript supports 2^53 - 1.
  /// This int-based API does not support the full unsigned 64-bit range.
  static int get maxCounter =>
      identical(1, 1.0) ? 9007199254740991 : int.parse('9223372036854775807');

  /// Decodes an RFC 4648 Base32 key and creates a generator.
  ///
  /// ASCII letters are case-insensitive and padding is optional. Invalid
  /// characters, padding, lengths, or nonzero unused bits throw [FormatException]
  /// without including the key. Algorithm and digit validation match [Hotp.new].
  factory fromBase32({
    required String secret,
    Algorithm algorithm = .sha1,
    int digits = 6,
  }) =>
      Hotp(secret: _decodeSecret(secret), algorithm: algorithm, digits: digits);

  /// Generates a zero-padded decimal code for [counter].
  ///
  /// Throws [RangeError] unless [counter] is between zero and [maxCounter].
  /// This operation does not advance or persist a counter.
  String generate(int counter) {
    _checkCounter(counter);
    var remaining = counter;
    final bytes = List<int>.filled(8, 0);
    for (var index = bytes.length - 1; index >= 0; index--) {
      final byte = remaining & 0xff;
      bytes[index] = byte;
      // Arithmetic division preserves the upper bits on JavaScript.
      remaining = (remaining - byte) ~/ 256;
    }
    final digest = _hmac.convert(bytes).bytes;
    final offset = digest.last & 0xf;
    final binary =
        (digest[offset] & 0x7f) << 24 |
        digest[offset + 1] << 16 |
        digest[offset + 2] << 8 |
        digest[offset + 3];
    final modulus = const [1000000, 10000000, 100000000][digits - 6];
    return (binary % modulus).toString().padLeft(digits, '0');
  }

  /// Returns the first matching counter in the forward window, or `null`.
  ///
  /// Checks [counter] through `counter + window`, inclusive. The default
  /// [window] of zero checks only [counter]. Malformed codes return `null`:
  /// [code] must contain exactly [digits] ASCII decimal digits.
  ///
  /// Throws [RangeError] for an invalid counter, negative window, or a window
  /// extending beyond [maxCounter], even when the code is malformed.
  ///
  /// No counter is changed or stored. Callers must persist advancement beyond
  /// a successful match and enforce attempt limits to prevent replay and guessing.
  /// Search cost grows with [window]; use a small, application-controlled limit.
  int? verify(String code, int counter, {int window = 0}) {
    _checkCounter(counter);
    if (window < 0 || window > maxCounter - counter) {
      throw RangeError('window exceeds the supported counter range');
    }
    if (code.length != digits || !RegExp(r'^[0-9]+$').hasMatch(code)) {
      return null;
    }
    final end = counter + window;
    for (var current = counter; ; current++) {
      if (_equalCode(generate(current), code)) return current;
      if (current == end) return null;
    }
  }
}

crypto.Hash _hash(Algorithm algorithm) => switch (algorithm) {
  .sha1 => crypto.sha1,
  .sha256 => crypto.sha256,
  .sha512 => crypto.sha512,
};

List<int> _copySecret(List<int> secret) {
  final copy = List<int>.unmodifiable(secret);
  if (copy.isEmpty || copy.any((byte) => byte < 0 || byte > 255)) {
    throw ArgumentError('secret must be a nonempty list of bytes');
  }
  return copy;
}

int _checkDigits(int digits) {
  if (digits < 6 || digits > 8) {
    throw RangeError.range(digits, 6, 8, 'digits');
  }
  return digits;
}

void _checkCounter(int counter) {
  if (counter < 0 || counter > Hotp.maxCounter) {
    throw RangeError.range(counter, 0, Hotp.maxCounter, 'counter');
  }
}

bool _equalCode(String expected, String actual) {
  var difference = 0;
  for (var index = 0; index < expected.length; index++) {
    difference |= expected.codeUnitAt(index) ^ actual.codeUnitAt(index);
  }
  return difference == 0;
}

List<int> _decodeSecret(String secret) {
  if (!RegExp(r'^[A-Za-z2-7]+={0,6}$').hasMatch(secret)) {
    throw const FormatException('Invalid Base32 secret');
  }
  final upper = secret.toUpperCase();
  final unpadded = upper.replaceFirst(RegExp(r'=+$'), '');
  if (const {1, 3, 6}.contains(unpadded.length % 8)) {
    throw const FormatException('Invalid Base32 secret length');
  }
  final padding = (8 - unpadded.length % 8) % 8;
  if (upper != unpadded &&
      upper != unpadded.padRight(unpadded.length + padding, '=')) {
    throw const FormatException('Invalid Base32 padding');
  }
  final bytes = encoding.base32.decode(unpadded);
  if (encoding.base32.encode(bytes).replaceFirst(RegExp(r'=+$'), '') !=
      unpadded) {
    throw const FormatException('Noncanonical Base32 secret');
  }
  return bytes;
}
