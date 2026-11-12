import 'package:hotp/hotp.dart';
import 'package:test/test.dart';

void main() {
  test('preserves a common 10-byte Base32 secret', () {
    final hotp = Hotp.fromBase32(secret: 'JBSWY3DPEHPK3PXP');
    expect(hotp.generate(1), '996554');
    expect(hotp.verify('996554', 1), 1);
    expect(hotp.verify('503347', 1), isNull);
  });

  // Independently generated with Python's standard-library hmac, using
  // bytes(range(length)), an eight-byte big-endian counter of 1, RFC 4226
  // dynamic truncation, and six digits. Includes keys above the HMAC block
  // sizes (64 bytes for SHA1/SHA256 and 128 bytes for SHA512).
  const keyLengthVectors = {
    Algorithm.sha1: {
      10: '672805',
      20: '524447',
      32: '555770',
      64: '602149',
      65: '428521',
      129: '348990',
    },
    Algorithm.sha256: {
      10: '258687',
      20: '779215',
      32: '309558',
      64: '636119',
      65: '898559',
      129: '628066',
    },
    Algorithm.sha512: {
      10: '043114',
      20: '516977',
      32: '995247',
      64: '267899',
      65: '462533',
      129: '745993',
    },
  };
  for (final algorithm in keyLengthVectors.keys) {
    for (final entry in keyLengthVectors[algorithm]!.entries) {
      test('$algorithm preserves a ${entry.key}-byte key', () {
        final hotp = Hotp(
          secret: List.generate(entry.key, (index) => index),
          algorithm: algorithm,
        );
        expect(hotp.generate(1), entry.value);
      });
    }
  }

  const source = {
    Algorithm.sha1: [
      '755224',
      '287082',
      '359152',
      '969429',
      '338314',
      '254676',
      '287922',
      '162583',
      '399871',
      '520489',
    ],
  };

  for (final algorithm in source.keys) {
    group(algorithm, () {
      late Hotp hotp;
      setUp(() {
        hotp = Hotp(
          algorithm: algorithm,
          secret: '12345678901234567890'.codeUnits,
          digits: 6,
        );
      });

      final passwords = source[algorithm]!;
      for (var i = 0; i < passwords.length; i++) {
        test('generage counter $i', () {
          expect(hotp.generate(i), passwords[i]);
        });

        test('verify counter $i', () {
          expect(hotp.verify(passwords[i], i), i);
        });
      }
    });
  }
}
