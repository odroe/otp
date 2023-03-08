import 'package:hotp/hotp.dart';
import 'package:test/test.dart';

void main() {
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

        test('validate counter $i', () {
          expect(hotp.validate(passwords[i], i), isTrue);
        });
      }
    });
  }
}
