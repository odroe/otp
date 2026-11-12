import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:hotp/hotp.dart';
import 'package:totp/totp.dart' show Totp;

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
  test('workspace TOTP generates codes under the current Dart SDK', () {
    final generator = Totp(
      secret: '12345678901234567890'.codeUnits,
      algorithm: .sha1,
      digits: 6,
      period: const Duration(seconds: 30),
    );
    expect(generator.generate(), matches(RegExp(r'^\d{6}$')));
  });
  test('TOTP uses floor rather than rounding near a period boundary', () {
    final generator = Totp(secret: '12345678901234567890'.codeUnits);
    expect(
      generator.generate(at: DateTime.fromMillisecondsSinceEpoch(29999)),
      '755224',
    );
    expect(
      generator.generate(at: DateTime.fromMillisecondsSinceEpoch(30000)),
      '287082',
    );
    expect(
      generator.generate(at: DateTime.fromMillisecondsSinceEpoch(59000)),
      '287082',
    );
  });
  test('RFC 6238 SHA1 vectors through workspace HOTP and TOTP', () {
    final generator = Hotp(secret: '12345678901234567890'.codeUnits, digits: 8);
    final timed = Totp(
      secret: '12345678901234567890'.codeUnits,
      algorithm: .sha1,
      digits: 8,
    );
    const vectors = <int, String>{
      59: '94287082',
      1111111109: '07081804',
      1111111111: '14050471',
      1234567890: '89005924',
      2000000000: '69279037',
      20000000000: '65353130',
    };
    for (final vector in vectors.entries) {
      expect(generator.generate(vector.key ~/ 30), vector.value);
      expect(
        timed.generate(
          at: DateTime.fromMillisecondsSinceEpoch(
            vector.key * 1000,
            isUtc: true,
          ),
        ),
        vector.value,
      );
    }
  });
}
