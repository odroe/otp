import 'package:test/test.dart';
import 'package:totp/totp.dart';

void main() {
  final secret = '12345678901234567890'.codeUnits;

  for (final period in [30, 60]) {
    group('remaining with a $period-second period', () {
      final totp = Totp(secret: secret, period: period);
      final boundary = DateTime.fromMillisecondsSinceEpoch(
        period * 1000 * 100,
        isUtc: true,
      );

      test('starts at the full period and counts down', () {
        for (var second = 0; second < period; second++) {
          expect(
            totp.remainingAt(boundary.add(Duration(seconds: second))),
            period - second,
          );
        }
      });

      test('rounds partial seconds up and resets on the next boundary', () {
        expect(
          totp.remainingAt(boundary.add(const Duration(milliseconds: 1))),
          period,
        );
        expect(
          totp.remainingAt(
            boundary.add(Duration(milliseconds: period * 1000 - 1)),
          ),
          1,
        );
        expect(
          totp.remainingAt(boundary.add(Duration(seconds: period))),
          period,
        );
      });

      test('uses the same instant for local and UTC DateTime values', () {
        final instant = boundary.add(const Duration(seconds: 7));
        expect(totp.remainingAt(instant.toLocal()), totp.remainingAt(instant));
      });

      test('getter is bounded by the times surrounding the call', () {
        final before = totp.remainingAt(DateTime.now());
        final remaining = totp.remaining;
        final after = totp.remainingAt(DateTime.now());
        // A second or period boundary may occur during the getter call.
        final possible = <int>{before};
        var value = before;
        while (value != after) {
          value = value == 1 ? period : value - 1;
          possible.add(value);
        }
        expect(remaining, isIn(possible));
      });
    });
  }
}
