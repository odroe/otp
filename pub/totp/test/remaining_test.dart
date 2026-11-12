import 'package:test/test.dart';
import 'package:totp/totp.dart';

void main() {
  test('preserves precision at the largest JavaScript whole-second period', () {
    const period = Duration(seconds: 9007199254);
    final totp = Totp(secret: [1], period: period);
    final epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    expect(totp.remainingAt(epoch), period);
    for (final elapsed in [
      const Duration(microseconds: 1),
      const Duration(milliseconds: 1),
    ]) {
      expect(
        totp.remainingAt(epoch.add(elapsed)).inMicroseconds,
        9007199254000000 - elapsed.inMicroseconds,
      );
    }
  });

  test(
    'rejects inexact JavaScript periods without restricting native Duration',
    () {
      const period = Duration(seconds: 9007199255);
      if (identical(1, 1.0)) {
        expect(() => Totp(secret: [1], period: period), throwsArgumentError);
        expect(
          () => Totp.fromBase32(secret: 'AA', period: period),
          throwsArgumentError,
        );
      } else {
        final totp = Totp(secret: [1], period: period);
        final at = DateTime.fromMicrosecondsSinceEpoch(1, isUtc: true);
        expect(totp.remainingAt(at), period - const Duration(microseconds: 1));
      }
    },
  );

  for (final seconds in [1, 30, 60]) {
    group('remaining for a $seconds-second period', () {
      final period = Duration(seconds: seconds);
      final totp = Totp(secret: [1], period: period);
      test('preserves subsecond precision and resets at exact boundaries', () {
        final boundary = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
        expect(totp.remainingAt(boundary), period);
        expect(
          totp.remainingAt(boundary.add(const Duration(microseconds: 1))),
          period - const Duration(microseconds: 1),
        );
        expect(
          totp.remainingAt(boundary.add(const Duration(microseconds: 999999))),
          period - const Duration(microseconds: 999999),
        );
        expect(
          totp.remainingAt(boundary.subtract(const Duration(microseconds: 1))),
          const Duration(microseconds: 1),
        );
      });
      test('uses the same instant for local and UTC dates', () {
        final utc = DateTime.utc(2026, 1, 1, 0, 0, 1, 123, 456);
        expect(totp.remainingAt(utc), totp.remainingAt(utc.toLocal()));
      });
      test('preserves microseconds for large JS epoch timestamps', () {
        final boundary = DateTime.utc(2603, 10, 11, 11, 33);
        final at = boundary.add(const Duration(microseconds: 1));
        expect(totp.remainingAt(at), period - const Duration(microseconds: 1));
      });
      test('works at the maximum supported DateTime without overflow', () {
        final at = DateTime.fromMillisecondsSinceEpoch(8640000000000000);
        expect(totp.remainingAt(at), period);
      });
      test('current remaining lies between surrounding observations', () {
        final before = totp.remainingAt(DateTime.now());
        final value = totp.remaining;
        final after = totp.remainingAt(DateTime.now());
        expect(value, greaterThan(Duration.zero));
        expect(value, lessThanOrEqualTo(period));
        if (after <= before) {
          expect(value, lessThanOrEqualTo(before));
          expect(value, greaterThanOrEqualTo(after));
        }
      });
    });
  }
}
