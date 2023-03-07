import 'package:crypto/crypto.dart';
import 'package:hotp/hotp.dart';
import 'package:test/test.dart';

void main() {
  late Hotp hotp;
  setUpAll(() {
    hotp = Hotp(
      secret: '12345678901234567890'.codeUnits,
      hash: sha1,
      digits: 6,
    );
  });

  const passwords = [
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
  ];

  test('generate', () {
    final generaged = Iterable.generate(
        passwords.length, (counter) => hotp.generate(counter));
    expect(generaged, passwords);
  });

  test('validate', () {
    final verified = Iterable.generate(passwords.length,
        (counter) => hotp.validate(passwords[counter], counter));
    expect(verified, List.filled(passwords.length, true));
  });
}
