import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../lib/entities/account.entity.dart';
import '../../lib/storage/account_store.dart';

AccountEntity synthetic(String issuer, {String? name, int period = 30}) =>
    AccountEntity()
      ..type = AccountType.TOTP
      ..issuer = issuer
      ..name = name
      // Public RFC test seed, never a user's authentication secret.
      ..secret = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ'
      ..digits = 6
      ..period = period;

void main() {
  late Directory directory;
  late String sqlitePath;
  final opened = <AccountStore>[];

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('auth-storage-test-');
    sqlitePath = '${directory.path}/accounts.sqlite3';
    Hive.init(directory.path);
    if (!Hive.isAdapterRegistered(0))
      Hive.registerAdapter(AccountTypeAdapter());
    if (!Hive.isAdapterRegistered(1))
      Hive.registerAdapter(AccountEntityAdapter());
  });
  tearDown(() async {
    for (final store in opened) {
      store.close();
    }
    opened.clear();
    await Hive.close();
    await directory.delete(recursive: true);
  });

  Future<AccountStore> open({LegacyAccountLoader? loader}) async {
    final store = await AccountStore.open(
      sqlitePath: sqlitePath,
      legacyDirectory: directory.path,
      legacyLoader: loader,
    );
    opened.add(store);
    return store;
  }

  Future<void> seed(Map<dynamic, AccountEntity> values) async {
    final box = await Hive.openBox<AccountEntity>('accounts');
    for (final entry in values.entries) {
      await box.put(entry.key, entry.value);
    }
    await Hive.close();
  }

  test(
    'adds OTP fields to existing SQLite without changing old records',
    () async {
      final db = sqlite3.open(sqlitePath);
      db.execute('''CREATE TABLE accounts (
      account_key TEXT PRIMARY KEY NOT NULL, account_type INTEGER NOT NULL,
      issuer TEXT NOT NULL, name TEXT, secret TEXT NOT NULL,
      digits INTEGER NOT NULL, period INTEGER NOT NULL
    )''');
      db.execute(
        'CREATE TABLE storage_metadata (key TEXT PRIMARY KEY NOT NULL, value TEXT NOT NULL)',
      );
      db.execute(
        "INSERT INTO storage_metadata VALUES ('hive_import_v1', 'complete')",
      );
      db.execute('INSERT INTO accounts VALUES (?, ?, ?, ?, ?, ?, ?)', [
        'legacy',
        AccountType.TOTP.index,
        'Acme',
        'alice',
        'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ',
        8,
        60,
      ]);
      db.close();
      final store = await open(
        loader: () async => throw StateError('unexpected import'),
      );
      final account = store.get('legacy')!;
      expect(account.issuer, 'Acme');
      expect(account.name, 'alice');
      expect(account.digits, 8);
      expect(account.period, 60);
      expect(account.algorithm.name, 'sha1');
      expect(account.counter, isNull);
    },
  );

  test('HOTP advance persists and rejects a stale counter', () async {
    final store = await open(loader: () async => {});
    final account = synthetic('Acme')
      ..type = AccountType.HOTP
      ..counter = 7;
    store.put('hotp', account);
    store.advanceHotp('hotp', 7);
    expect(() => store.advanceHotp('hotp', 7), throwsStateError);
    expect(store.get('hotp')!.counter, 8);
  });

  test('failed HOTP writes leave the counter unchanged', () async {
    final store = await open(loader: () async => {});
    final account = synthetic('Acme')
      ..type = AccountType.HOTP
      ..counter = 7;
    store.put('hotp', account);
    final other = sqlite3.open(sqlitePath);
    other.execute('''CREATE TRIGGER reject_advance BEFORE UPDATE ON accounts
      BEGIN SELECT RAISE(ABORT, 'simulated write failure'); END''');
    other.close();
    expect(() => store.advanceHotp('hotp', 7), throwsA(isA<SqliteException>()));
    expect(store.get('hotp')!.counter, 7);
  });

  test('advancement rejects a replaced account at the same counter', () async {
    final store = await open(loader: () async => {});
    final original = synthetic('Acme')
      ..type = AccountType.HOTP
      ..counter = 7;
    store.put('hotp', original);
    final replacement = synthetic('Acme')
      ..type = AccountType.HOTP
      ..counter = 7
      ..secret = 'JBSWY3DPEHPK3PXP';
    store.put('hotp', replacement);
    expect(
      () => store.advanceHotp('hotp', 7, expectedAccount: original),
      throwsStateError,
    );
    expect(store.get('hotp')!.counter, 7);
  });

  test('batch insert rolls back if any identity conflicts', () async {
    final store = await open(loader: () async => {});
    store.put('existing', synthetic('Acme', name: 'alice'));
    expect(
      () => store.insertNewBatch({
        'new': synthetic('Other', name: 'bob'),
        'conflict': synthetic('Acme', name: 'alice'),
      }),
      throwsStateError,
    );
    expect(store.length, 1);
    expect(store.get('new'), isNull);
    expect(store.get('existing')!.issuer, 'Acme');
  });

  test(
    'migrates actual Hive 2.0.4 fixture without changing source bytes',
    () async {
      // Generated with Hive 2.0.4 + the historical adapters on Dart 2.19.6.
      // Embedded so compatibility does not depend on a separately copied file.
      // All three records contain the public RFC test seed, not user data.
      final original = base64Decode(
        'egAAAAETUkZDIEZpeHR1cmUgMDp1c2VyMCEGACABAQQNAAAAUkZDIEZpeHR1cmUgMAIEBQAAAHVzZXIwAwQgAAAAR0VaREdOQlZHWTNUUU9KUUdFWkRHTkJWR1kzVFFPSlEEAQAAAAAAABhABQEAAAAAAAA+QMkxd3NwAAAAARJSRkMgRml4dHVyZSAxOm51bGwhBgAgAQEEDQAAAFJGQyBGaXh0dXJlIDECAAMEIAAAAEdFWkRHTkJWR1kzVFFPSlFHRVpER05CVkdZM1RRT0pRBAEAAAAAAAAYQAUBAAAAAAAAPkCPjue/egAAAAETUkZDIEZpeHR1cmUgMjp1c2VyMiEGACABAQQNAAAAUkZDIEZpeHR1cmUgMgIEBQAAAHVzZXIyAwQgAAAAR0VaREdOQlZHWTNUUU9KUUdFWkRHTkJWR1kzVFFPSlEEAQAAAAAAABhABQEAAAAAAAA+QHMKaDA=',
      );
      final source = File('${directory.path}/accounts.hive');
      await source.writeAsBytes(original, flush: true);
      final store = await open();
      expect(store.length, 3);
      for (var index = 0; index < 3; index++) {
        final name = index == 1 ? null : 'user$index';
        final record = store.get('RFC Fixture $index:$name');
        expect(record, isNotNull);
        expect(record!.type, AccountType.TOTP);
        expect(record.issuer, 'RFC Fixture $index');
        expect(record.name, name);
        expect(record.secret, 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ');
        expect(record.digits, 6);
        expect(record.period, 30);
      }
      expect(await source.readAsBytes(), original);
    },
  );

  test(
    'migrates multiple records and nullable names without altering Hive bytes',
    () async {
      await seed({
        'First:a': synthetic('First', name: 'a'),
        'Second:null': synthetic('Second'),
        'Third:b': synthetic('Third', name: 'b'),
      });
      final original = await File('${directory.path}/accounts.hive')
          .readAsBytes();
      final store = await open();
      expect(store.length, 3);
      expect(store.get('Second:null')!.name, isNull);
      expect(store.get('First:a')!.issuer, 'First');
      expect(
        await File('${directory.path}/accounts.hive').readAsBytes(),
        original,
      );
      expect(
        Directory('${directory.path}/.account-migration').existsSync(),
        isFalse,
      );
    },
  );

  test('preserves malformed legacy values for per-item UI handling', () async {
    final record = synthetic('Invalid', period: 0)
      ..secret = ''
      ..digits = -2;
    await seed({'Invalid:null': record});
    final store = await open();
    expect(store.get('Invalid:null')!.period, 0);
    expect(store.get('Invalid:null')!.secret, '');
    expect(store.get('Invalid:null')!.digits, -2);
  });

  test(
    'new installs and repeated reopen persist SQLite updates and deletes',
    () async {
      var store = await open();
      expect(store.length, 0);
      store.put('A:null', synthetic('A'));
      store.put('B:null', synthetic('B'));
      store.put('A:null', synthetic('A', name: 'updated'));
      store.delete('B:null');
      for (var restart = 0; restart < 3; restart++) {
        store.close();
        opened.remove(store);
        store = await open();
        expect(store.length, 1);
        expect(store.get('A:null')!.name, 'updated');
      }
    },
  );

  test(
    'completed migration never reimports deleted or stale Hive records',
    () async {
      await seed({'A:null': synthetic('A')});
      var store = await open();
      store.delete('A:null');
      store.put('B:null', synthetic('B'));
      store.close();
      opened.remove(store);
      store = await open(
        loader: () async => throw StateError('must not read legacy again'),
      );
      expect(store.containsKey('A:null'), isFalse);
      expect(store.containsKey('B:null'), isTrue);
    },
  );

  test('corrupt Hive fails closed, leaves bytes intact, and retries after source repair', () async {
    await seed({'A:null': synthetic('A')});
    final source = File('${directory.path}/accounts.hive');
    final original = await source.readAsBytes();
    final corrupt = [...original, 1, 2, 3];
    await source.writeAsBytes(corrupt, flush: true);
    await expectLater(open(), throwsA(anything));
    expect(await source.readAsBytes(), corrupt);
    await source.writeAsBytes(original, flush: true); // synthetic fixture only
    final store = await open();
    expect(store.length, 1);
  });

  test('both original Hive and compaction files remain untouched', () async {
    await seed({'A:null': synthetic('A')});
    final original = await File('${directory.path}/accounts.hive')
        .readAsBytes();
    final compacted = File('${directory.path}/accounts.hivec');
    await compacted.writeAsBytes(original, flush: true);
    await open();
    expect(await compacted.readAsBytes(), original);
    expect(
      await File('${directory.path}/accounts.hive').readAsBytes(),
      original,
    );
  });

  test(
    'compaction-only original is read from copy without renaming original',
    () async {
      await seed({'A:null': synthetic('A')});
      final source = File('${directory.path}/accounts.hive');
      final original = await source.readAsBytes();
      await source.rename(
        '${directory.path}/accounts.hivec',
      ); // synthetic fixture only
      final store = await open();
      expect(store.length, 1);
      expect(await source.exists(), isFalse);
      expect(
        await File('${directory.path}/accounts.hivec').readAsBytes(),
        original,
      );
    },
  );

  test(
    'non-string legacy keys block rather than silently change identity',
    () async {
      await seed({42: synthetic('A')});
      final original = await File('${directory.path}/accounts.hive')
          .readAsBytes();
      await expectLater(open(), throwsStateError);
      expect(
        await File('${directory.path}/accounts.hive').readAsBytes(),
        original,
      );
    },
  );

  test(
    'mid-insert failure rolls back all records and marker, then retry succeeds',
    () async {
      await expectLater(
        open(
          loader: () async => {'good': synthetic('A'), 'bad': AccountEntity()},
        ),
        throwsA(anything),
      );
      final db = sqlite3.open(sqlitePath);
      expect(db.select('SELECT COUNT(*) AS n FROM accounts').single['n'], 0);
      expect(db.select('SELECT * FROM storage_metadata'), isEmpty);
      db.close();
      final store = await open(loader: () async => {'good': synthetic('A')});
      expect(store.length, 1);
    },
  );

  test(
    'restart after import commit verifies existing records without duplication',
    () async {
      await seed({'A:null': synthetic('A')});
      var store = await open();
      store.close();
      opened.remove(store);
      final db = sqlite3.open(sqlitePath);
      db.execute("UPDATE storage_metadata SET value='imported'");
      db.close();
      store = await open();
      expect(store.length, 1);
    },
  );

  test(
    'unverified import mismatch blocks switch without overwriting either store',
    () async {
      await seed({'A:null': synthetic('A')});
      var store = await open();
      store.close();
      opened.remove(store);
      final db = sqlite3.open(sqlitePath);
      db.execute("UPDATE storage_metadata SET value='imported'");
      db.execute("UPDATE accounts SET issuer='changed'");
      db.close();
      await expectLater(open(), throwsStateError);
      final check = sqlite3.open(sqlitePath);
      expect(
        check.select('SELECT issuer FROM accounts').single['issuer'],
        'changed',
      );
      expect(
        check.select('SELECT value FROM storage_metadata').single['value'],
        'imported',
      );
      check.close();
    },
  );

  test(
    'adds Steam format to the previous schema without changing counters',
    () async {
      final db = sqlite3.open(sqlitePath);
      db.execute('''CREATE TABLE accounts (
      account_key TEXT PRIMARY KEY NOT NULL, account_type INTEGER NOT NULL,
      issuer TEXT NOT NULL, name TEXT, secret TEXT NOT NULL, digits INTEGER NOT NULL,
      period INTEGER NOT NULL, algorithm TEXT NOT NULL, counter INTEGER
    )''');
      db.execute(
        'CREATE TABLE storage_metadata (key TEXT PRIMARY KEY NOT NULL, value TEXT NOT NULL)',
      );
      db.execute(
        "INSERT INTO storage_metadata VALUES ('hive_import_v1', 'complete')",
      );
      db.execute('INSERT INTO accounts VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)', [
        'old',
        AccountType.HOTP.index,
        'Acme',
        'alice',
        'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ',
        8,
        30,
        'sha256',
        42,
      ]);
      db.close();
      final store = await open(
        loader: () async => throw StateError('unexpected import'),
      );
      final account = store.get('old')!;
      expect(account.format, OtpFormat.decimal);
      expect(account.counter, 42);
      expect(account.algorithm.name, 'sha256');
      expect(account.digits, 8);
    },
  );

  test('unknown unmarked SQLite records are never overwritten', () async {
    var store = await open();
    store.put('existing', synthetic('Existing'));
    store.close();
    opened.remove(store);
    final db = sqlite3.open(sqlitePath);
    db.execute('DELETE FROM storage_metadata');
    db.close();
    await expectLater(open(), throwsStateError);
  });
}
