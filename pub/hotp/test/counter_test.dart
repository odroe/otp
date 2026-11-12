import 'package:hotp/hotp.dart';
import 'package:test/test.dart';

void main() {
  // Python standard-library HMAC-SHA1 with the RFC 4226 key, an eight-byte
  // big-endian counter, dynamic truncation, and six digits.
  const vectors = {
    0: '755224',
    1: '287082',
    4294967295: '117190',
    4294967296: '999456',
    4294967297: '108930',
    9007199254740991: '891307',
  };
  final hotp = Hotp(secret: '12345678901234567890'.codeUnits);
  test('encodes the largest signed native counter', () {
    expect(hotp.generate(int.parse('9223372036854775807')), '181742');
  }, skip: identical(1, 1.0) ? 'Exceeds JavaScript safe integer range' : false);
  for (final entry in vectors.entries) {
    test('encodes all eight bytes of counter ${entry.key}', () {
      expect(hotp.generate(entry.key), entry.value);
      expect(hotp.verify(entry.value, entry.key), entry.key);
    });
  }
}
