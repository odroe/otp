import 'package:hotp/hotp.dart';
import 'package:test/test.dart';

void main() {
  final rfcSecret = '12345678901234567890'.codeUnits;

  group('configuration', () {
    test('defaults to SHA1 and six digits', () {
      final hotp = Hotp(secret: rfcSecret);
      expect(hotp.algorithm, Algorithm.sha1);
      expect(hotp.digits, 6);
      expect(hotp.generate(0), '755224');
    });

    test('supports six through eight digits', () {
      for (final digits in [6, 7, 8]) {
        final hotp = Hotp(secret: rfcSecret, digits: digits);
        expect(hotp.generate(0).length, digits);
        expect(hotp.verify(hotp.generate(0), 0), 0);
      }
    });

    test('rejects unsupported digit counts without relying on assertions', () {
      for (final digits in [-1, 0, 5, 9, 100]) {
        expect(() => Hotp(secret: rfcSecret, digits: digits), throwsRangeError);
      }
    });

    test('requires nonempty bytes but permits short legacy keys', () {
      for (final secret in <List<int>>[
        [],
        [-1],
        [256],
        [0, 300],
      ]) {
        expect(() => Hotp(secret: secret), throwsArgumentError);
      }
      expect(Hotp(secret: [0, 255]).generate(0), matches(r'^[0-9]{6}$'));
    });

    test('snapshots the input before the first generation', () {
      final input = List<int>.of(rfcSecret);
      final hotp = Hotp(secret: input);
      input.fillRange(0, input.length, 0);
      input.clear();
      expect(hotp.secret, rfcSecret);
      expect(hotp.generate(0), '755224');
      expect(() => hotp.secret[0] = 0, throwsUnsupportedError);
      expect(() => hotp.secret.add(0), throwsUnsupportedError);
      expect(hotp.generate(1), '287082');
    });
  });

  group('verification', () {
    late Hotp hotp;
    setUp(() => hotp = Hotp(secret: rfcSecret));

    test('verification is exact rather than an implicit counter window', () {
      expect(hotp.verify('287082', 1), 1);
      expect(hotp.verify('287082', 0), isNull);
      expect(hotp.verify('287082', 2), isNull);
      expect(hotp.verify('000000', 1), isNull);
    });

    test('returns the matched counter from an inclusive forward window', () {
      expect(hotp.verify('755224', 0), 0);
      expect(hotp.verify('287082', 0), isNull);
      expect(hotp.verify('287082', 0, window: 1), 1);
      expect(hotp.verify('359152', 0, window: 1), isNull);
      expect(hotp.verify('359152', 0, window: 2), 2);
      expect(hotp.verify('755224', 1, window: 2), isNull);
    });

    test('successful verification does not advance stored state', () {
      expect(hotp.verify('287082', 0, window: 1), 1);
      expect(hotp.verify('287082', 0, window: 1), 1);
      expect(hotp.generate(0), '755224');
      expect(hotp.verify('755224', 0, window: 0), 0);
    });

    test('preserves leading zeros when verifying', () {
      expect(hotp.generate(30), '026920');
      expect(hotp.verify('026920', 30), 30);
      expect(hotp.verify('26920', 30), isNull);
    });

    test('malformed codes never match', () {
      for (final code in [
        '',
        '75522',
        '0755224',
        '755224\n',
        ' 755224',
        '75522a',
        '+55224',
        '７５５２２４',
        '٧٥٥٢٢٤',
      ]) {
        expect(hotp.verify(code, 0), isNull, reason: code);
        expect(hotp.verify(code, 0, window: 2), isNull, reason: code);
      }
    });

    test('rejects invalid counters even for malformed codes', () {
      expect(() => hotp.generate(-1), throwsRangeError);
      expect(() => hotp.verify('', -1), throwsRangeError);
      expect(() => hotp.verify('755224', -1, window: 1), throwsRangeError);
      if (identical(1, 1.0)) {
        final unsafeCounter = Hotp.maxCounter + 1;
        expect(() => hotp.generate(unsafeCounter), throwsRangeError);
        expect(() => hotp.verify('', unsafeCounter), throwsRangeError);
        expect(() => hotp.verify('755224', unsafeCounter), throwsRangeError);
      }
    });

    test('rejects negative and overflowing windows before matching', () {
      expect(() => hotp.verify('', 0, window: -1), throwsRangeError);
      expect(
        () => hotp.verify('', Hotp.maxCounter, window: 1),
        throwsRangeError,
      );
      expect(
        () => hotp.verify('', 1, window: Hotp.maxCounter),
        throwsRangeError,
      );
    });

    test('matching terminates at the largest supported counter', () {
      final maximum = Hotp.maxCounter;
      final code = hotp.generate(maximum);
      final different = code == '000000' ? '000001' : '000000';
      expect(hotp.verify(code, maximum), maximum);
      expect(hotp.verify(code, maximum - 1, window: 1), maximum);
      expect(hotp.verify(different, maximum), isNull);
    });
  });

  group('Base32', () {
    test('accepts RFC4648 padded and unpadded forms in either letter case', () {
      const vectors = {
        'MY======': 'f',
        'MZXQ====': 'fo',
        'MZXW6===': 'foo',
        'MZXW6YQ=': 'foob',
        'MZXW6YTB': 'fooba',
        'MZXW6YTBOI======': 'foobar',
      };
      for (final entry in vectors.entries) {
        final unpadded = entry.key.replaceAll('=', '');
        for (final value in [
          entry.key,
          unpadded,
          entry.key.toLowerCase(),
          unpadded.toLowerCase(),
        ]) {
          expect(Hotp.fromBase32(secret: value).secret, entry.value.codeUnits);
        }
      }
      expect(Hotp.fromBase32(secret: 'AA').secret, [0]);
      expect(Hotp.fromBase32(secret: 'AA======').secret, [0]);
    });

    test('preserves requested algorithm and digit count', () {
      final hotp = Hotp.fromBase32(
        secret: 'MY======',
        algorithm: Algorithm.sha512,
        digits: 8,
      );
      expect(hotp.algorithm, Algorithm.sha512);
      expect(hotp.digits, 8);
      expect(
        hotp.generate(0),
        Hotp(secret: [102], algorithm: Algorithm.sha512, digits: 8).generate(0),
      );
    });

    test('rejects invalid alphabet, padding, lengths, and unused bits', () {
      for (final value in [
        '',
        '=',
        'A',
        'AAA',
        'AAAAAA',
        'AB',
        'MZ======',
        'MZXR====',
        'MZXW7===',
        'MZXW6YR=',
        'AA=',
        'AA=======',
        'AAAAAAAA=',
        '=AA',
        'A=A',
        'AA======AA',
        ' AA',
        'AA ',
        'AA\n',
        'A A',
        '00',
        '11',
        '88',
        'A!',
        'ıA',
        'ſA',
      ]) {
        expect(
          () => Hotp.fromBase32(secret: value),
          throwsFormatException,
          reason: 'Must reject noncanonical Base32: $value',
        );
      }
    });

    test('Base32 errors do not expose the supplied secret', () {
      const secret = 'do-not-print-this-key!';
      try {
        Hotp.fromBase32(secret: secret);
        fail('Expected a FormatException');
      } on FormatException catch (error) {
        expect(error.source, isNull);
        expect(error.toString(), isNot(contains(secret)));
      }
    });
  });
}
