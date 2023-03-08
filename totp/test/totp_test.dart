import 'package:totp/totp.dart';
import 'package:test/test.dart';

void main() {
  final source = {
    DateTime.parse('1970-01-01T00:00:59Z'): {
      Algorithm.sha1: '94287082',
      Algorithm.sha256: '46119246',
      Algorithm.sha512: '90693936',
    },
    DateTime.parse('2005-03-18T01:58:29Z'): {
      Algorithm.sha1: '07081804',
      Algorithm.sha256: '68084774',
      Algorithm.sha512: '25091201',
    },
    DateTime.parse('2005-03-18T01:58:31Z'): {
      Algorithm.sha1: '14050471',
      Algorithm.sha256: '67062674',
      Algorithm.sha512: '99943326',
    },
    DateTime.parse('2009-02-13T23:31:30Z'): {
      Algorithm.sha1: '89005924',
      Algorithm.sha256: '91819424',
      Algorithm.sha512: '93441116',
    },
    DateTime.parse('2033-05-18T03:33:20Z'): {
      Algorithm.sha1: '69279037',
      Algorithm.sha256: '90698825',
      Algorithm.sha512: '38618901',
    },
    DateTime.parse('2603-10-11T11:33:20Z'): {
      Algorithm.sha1: '65353130',
      Algorithm.sha256: '77737706',
      Algorithm.sha512: '47863826',
    },
  };

  final algorithms = source.values.expand((element) => element.keys).toSet();
  late Totp totp;

  for (final algorithm in algorithms) {
    group(algorithm, () {
      setUp(() {
        totp = Totp(
          secret: '12345678901234567890'.codeUnits,
          digits: 8,
          period: 30,
          algorithm: algorithm,
        );
      });

      for (final DateTime dateTime in source.keys) {
        test(dateTime.toIso8601String(), () {
          expect(totp.generate(dateTime), source[dateTime]![algorithm]);
        });
      }
    });
  }
}
