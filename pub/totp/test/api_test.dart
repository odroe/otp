import 'package:test/test.dart';
import 'package:totp/totp.dart';

void main() {
  final secret = '12345678901234567890'.codeUnits;
  final totp = Totp(secret: secret);
  DateTime step(int counter) =>
      DateTime.fromMillisecondsSinceEpoch(counter * 30000, isUtc: true);

  test('floors Unix time and changes step exactly at the boundary', () {
    expect(
      totp.generate(at: step(1).subtract(const Duration(microseconds: 1))),
      '755224',
    );
    expect(totp.generate(at: step(1)), '287082');
    expect(
      totp.generate(at: step(1).add(const Duration(microseconds: 1))),
      '287082',
    );
    expect(totp.verify('287082', at: step(1)), 1);
    expect(totp.verify('287082', at: step(1).toLocal()), 1);
  });

  test(
    'defaults to an exact window and supports both directions explicitly',
    () {
      expect(totp.verify('755224', at: step(1)), isNull);
      expect(totp.verify('359152', at: step(1)), isNull);
      expect(totp.verify('755224', at: step(1), window: 1), 0);
      expect(totp.verify('359152', at: step(1), window: 1), 2);
      expect(totp.verify('969429', at: step(1), window: 1), isNull);
      expect(totp.verify('969429', at: step(1), window: 2), 3);
      expect(totp.verify('755224', at: step(0), window: 1), 0);
      expect(totp.verify('287082', at: step(0), window: 1), 1);
      expect(totp.verify('000000', at: step(0), window: 2), isNull);
    },
  );

  test('prefers current then nearest then past for duplicate code matches', () {
    // Independently computed with Python hmac/SHA1, RFC4226 truncation.
    expect(totp.generate(at: step(2386)), '709847');
    expect(totp.generate(at: step(2394)), '709847');
    expect(totp.verify('709847', at: step(2390), window: 4), 2386);
    expect(totp.verify('709847', at: step(2391), window: 5), 2394);
    expect(totp.verify('709847', at: step(2394), window: 8), 2394);
  });

  test('does not consume codes or update application state', () {
    expect(totp.verify('287082', at: step(1)), 1);
    expect(totp.verify('287082', at: step(1)), 1);
    expect(totp.generate(at: step(0)), '755224');
  });

  test('omitted time uses an instant within the call', () {
    final before = DateTime.now();
    final code = totp.generate();
    final after = DateTime.now();
    expect([
      totp.generate(at: before),
      totp.generate(at: after),
    ], contains(code));
    final current = totp.verify(code, window: 1);
    expect(current, isNotNull);
    expect(
      current,
      inInclusiveRange(
        before.millisecondsSinceEpoch ~/ 30000,
        after.millisecondsSinceEpoch ~/ 30000,
      ),
    );
  });

  test('rejects malformed decimal codes without searching', () {
    for (final code in [
      '',
      '28708',
      '0287082',
      '287082\n',
      ' 287082',
      '２８７０８２',
      '28708a',
    ]) {
      expect(totp.verify(code, at: step(1), window: 1), isNull);
    }
  });

  test('validates window even when code is malformed', () {
    expect(() => totp.verify('', at: step(0), window: -1), throwsRangeError);
    if (identical(1, 1.0)) {
      expect(
        () => totp.verify('', at: step(0), window: 9007199254740992),
        throwsRangeError,
      );
    }
  });

  test('rejects timestamps before the Unix epoch including a microsecond', () {
    for (final time in [
      DateTime.utc(1969),
      step(0).subtract(const Duration(microseconds: 1)),
    ]) {
      expect(() => totp.generate(at: time), throwsArgumentError);
      expect(() => totp.verify('', at: time), throwsArgumentError);
      expect(() => totp.remainingAt(time), throwsArgumentError);
    }
  });

  test('requires positive whole-second periods through either constructor', () {
    for (final period in [
      Duration.zero,
      const Duration(seconds: -1),
      const Duration(microseconds: 1),
      const Duration(milliseconds: 1500),
    ]) {
      expect(() => Totp(secret: secret, period: period), throwsArgumentError);
      expect(
        () => Totp.fromBase32(secret: 'MY======', period: period),
        throwsArgumentError,
      );
    }
  });

  test('requires nonempty byte keys and six through eight digits', () {
    for (final key in <List<int>>[
      [],
      [-1],
      [256],
    ]) {
      expect(() => Totp(secret: key), throwsArgumentError);
    }
    for (final digits in [5, 9]) {
      expect(() => Totp(secret: secret, digits: digits), throwsRangeError);
      expect(
        () => Totp.fromBase32(secret: 'MY======', digits: digits),
        throwsRangeError,
      );
    }
  });

  test('preserves custom settings through the Base32 factory', () {
    final encoded = Totp.fromBase32(
      secret: 'my======',
      algorithm: .sha512,
      digits: 8,
      period: const Duration(seconds: 60),
    );
    final raw = Totp(
      secret: [102],
      algorithm: .sha512,
      digits: 8,
      period: const Duration(seconds: 60),
    );
    expect(encoded.secret, [102]);
    expect(encoded.algorithm, Algorithm.sha512);
    expect(encoded.digits, 8);
    expect(encoded.period, const Duration(seconds: 60));
    expect(encoded.generate(at: step(1)), raw.generate(at: step(1)));
    expect(Totp.fromBase32(secret: 'my').secret, [102]);
  });

  test('rejects noncanonical or non-ASCII Base32 without leaking key', () {
    for (final key in [
      '',
      'MY\n',
      'MY ',
      'MZ======',
      'MY=',
      'A',
      'ıA',
      'ſA',
      '00',
    ]) {
      expect(() => Totp.fromBase32(secret: key), throwsFormatException);
    }
    const key = 'private-invalid-key!';
    try {
      Totp.fromBase32(secret: key);
      fail('Expected invalid key to throw');
    } on FormatException catch (error) {
      expect(error.source, isNull);
      expect(error.toString(), isNot(contains(key)));
    }
  });
}
