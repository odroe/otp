import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:ootp/ootp.dart';

void main() {
  test('sqlite3 native assets load and roll back a transaction', () {
    final database = sqlite3.openInMemory();
    try {
      database.execute(
        'CREATE TABLE synthetic (id INTEGER PRIMARY KEY, name TEXT)',
      );
      database.execute('BEGIN');
      database.execute("INSERT INTO synthetic (name) VALUES ('synthetic')");
      database.execute('ROLLBACK');
      expect(
        database
            .select('SELECT count(*) AS total FROM synthetic')
            .single['total'],
        0,
      );
    } finally {
      database.close();
    }
  });
  test('legacy OOTP compiles under the current Dart SDK', () {
    final generator = TOTP.secret(
      '12345678901234567890'.codeUnits,
      digits: 6,
      period: 30,
    );
    expect(generator.make(), matches(RegExp(r'^\d{6}$')));
  });
  test(
    'RFC 6238 SHA1 vectors through unchanged OOTP counter implementation',
    () {
      final generator = HOTP('12345678901234567890'.codeUnits);
      const vectors = <int, String>{
        59: '94287082',
        1111111109: '07081804',
        1111111111: '14050471',
        1234567890: '89005924',
        2000000000: '69279037',
        20000000000: '65353130',
      };
      for (final vector in vectors.entries) {
        expect(
          generator.make(counter: vector.key ~/ 30, digits: 8),
          vector.value,
        );
      }
    },
  );
}
