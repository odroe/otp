import 'package:crypto/crypto.dart';
import 'package:totp/totp.dart';
import 'package:test/test.dart';

void main() {
  final source = {
    DateTime.parse('1970-01-01T00:00:59Z'): {
      sha1: '94287082',
      sha256: '46119246',
      sha512: '90693936',
    },
    DateTime.parse('2005-03-18T01:58:29Z'): {
      sha1: '07081804',
      sha256: '68084774',
      sha512: '25091201',
    },
    DateTime.parse('2005-03-18T01:58:31Z'): {
      sha1: '14050471',
      sha256: '67062674',
      sha512: '99943326',
    },
    DateTime.parse('2009-02-13T23:31:30Z'): {
      sha1: '89005924',
      sha256: '91819424',
      sha512: '93441116',
    },
    DateTime.parse('2033-05-18T03:33:20Z'): {
      sha1: '69279037',
      sha256: '90698825',
      sha512: '38618901',
    },
    DateTime.parse('2603-10-11T11:33:20Z'): {
      sha1: '65353130',
      sha256: '77737706',
      sha512: '47863826',
    },
  };

  final hashs = source.values.expand((element) => element.keys).toSet();
  late Totp totp;

  for (final hash in hashs) {
    group(hash, () {
      setUp(() {
        totp = Totp(
          secret: '12345678901234567890'.codeUnits,
          hash: hash,
          digits: 8,
          period: 30,
        );
      });

      for (final DateTime dateTime in source.keys) {
        test(dateTime.toIso8601String(), () {
          expect(totp.generate(dateTime), source[dateTime]![hash]);
        });
      }
    });
  }
}
