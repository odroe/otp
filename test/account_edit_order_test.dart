import 'dart:io';

import 'package:authenticator/entities/parse_account.dart';
import 'package:authenticator/storage/account_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test(
    'labels and order persist without changing stable identity or HOTP state',
    () async {
      final dir = await Directory.systemTemp.createTemp('auth-edit-order-');
      Future<AccountStore> open() => AccountStore.open(
        sqlitePath: '${dir.path}/db.sqlite3',
        legacyDirectory: dir.path,
        legacyLoader: () async => {},
      );
      var store = await open();
      final a = accountFromFields(
        type: .HOTP,
        issuer: 'One',
        name: 'Alice',
        secret: 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ',
        counter: '7',
      );
      final b = accountFromFields(
        type: .TOTP,
        issuer: 'Two',
        secret: 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ',
      );
      store.put('stable-a', a);
      store.put('stable-b', b);
      store.updateLabels('stable-a', 'New', '小明', expected: a);
      expect(
        () => store.updateLabels('stable-a', 'Wrong', null, expected: a),
        throwsStateError,
      );
      store.reorder(['stable-b', 'stable-a']);
      expect(() => store.reorder(['stable-a', 'stable-a']), throwsStateError);
      expect(store.keys.toList(), ['stable-b', 'stable-a']);
      store.close();
      store = await open();
      expect(store.keys.toList(), ['stable-b', 'stable-a']);
      final restored = store.get('stable-a')!;
      expect(restored.issuer, 'New');
      expect(restored.name, '小明');
      expect(restored.secret, a.secret);
      expect(restored.counter, 7);
      expect(restored.algorithm, a.algorithm);
      final c = accountFromFields(
        type: .TOTP,
        issuer: 'Three',
        secret: a.secret,
      );
      store.put('stable-c', c);
      expect(store.keys.toList(), ['stable-b', 'stable-a', 'stable-c']);
      store.delete('stable-a');
      store.put('stable-a', a);
      expect(store.keys.toList(), ['stable-b', 'stable-c', 'stable-a']);
      store.close();
      await dir.delete(recursive: true);
    },
  );
  test('a failed order write rolls back the whole previous order', () async {
    final dir = await Directory.systemTemp.createTemp('auth-order-failure-');
    final path = '${dir.path}/db.sqlite3';
    final store = await AccountStore.open(
      sqlitePath: path,
      legacyDirectory: dir.path,
      legacyLoader: () async => {},
    );
    final account = accountFromFields(
      type: .TOTP,
      issuer: 'Service',
      secret: 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ',
    );
    store.put('a', account);
    store.put('b', account);
    store.reorder(['b', 'a']);
    final other = sqlite3.open(path);
    other.execute(
      "CREATE TRIGGER reject_order BEFORE INSERT ON account_order WHEN NEW.account_key = 'a' BEGIN SELECT RAISE(ABORT, 'test failure'); END",
    );
    other.close();
    expect(() => store.reorder(['a', 'b']), throwsA(isA<SqliteException>()));
    expect(store.keys.toList(), ['b', 'a']);
    store.close();
    final reopened = await AccountStore.open(
      sqlitePath: path,
      legacyDirectory: dir.path,
      legacyLoader: () async => {},
    );
    expect(reopened.keys.toList(), ['b', 'a']);
    reopened.close();
    await dir.delete(recursive: true);
  });
  test(
    'editing tolerates counter advancement but rejects a replaced account',
    () async {
      final dir = await Directory.systemTemp.createTemp('auth-edit-stale-');
      final store = await AccountStore.open(
        sqlitePath: '${dir.path}/db.sqlite3',
        legacyDirectory: dir.path,
        legacyLoader: () async => {},
      );
      final original = accountFromFields(
        type: .HOTP,
        issuer: 'Service',
        name: 'alice',
        counter: '7',
        secret: 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ',
      );
      store.put('id', original);
      store.advanceHotp('id', 7, expectedAccount: original);
      store.updateLabels('id', 'Renamed', 'alice', expected: original);
      expect(store.get('id')!.counter, 8);
      final stale = store.get('id')!;
      final replacement = accountFromFields(
        type: .HOTP,
        issuer: 'Renamed',
        name: 'alice',
        counter: '1',
        secret: 'JBSWY3DPEHPK3PXP',
      );
      store.put('id', replacement);
      expect(
        () => store.updateLabels('id', 'Wrong', null, expected: stale),
        throwsStateError,
      );
      expect(store.get('id')!.secret, replacement.secret);
      expect(store.get('id')!.issuer, 'Renamed');
      store.close();
      await dir.delete(recursive: true);
    },
  );
  test('existing SQLite accounts retain their order when order metadata is introduced', () async {
    final dir = await Directory.systemTemp.createTemp('auth-order-legacy-');
    final path = '${dir.path}/db.sqlite3';
    final old = sqlite3.open(path);
    old.execute(
      'CREATE TABLE accounts (account_key TEXT PRIMARY KEY NOT NULL, account_type INTEGER NOT NULL, issuer TEXT NOT NULL, name TEXT, secret TEXT NOT NULL, digits INTEGER NOT NULL, period INTEGER NOT NULL)',
    );
    old.execute(
      'CREATE TABLE storage_metadata (key TEXT PRIMARY KEY NOT NULL, value TEXT NOT NULL)',
    );
    old.execute(
      "INSERT INTO storage_metadata VALUES ('hive_import_v1', 'complete')",
    );
    for (final key in ['z', 'a']) {
      old.execute('INSERT INTO accounts VALUES (?, 1, ?, NULL, ?, 6, 30)', [
        key,
        key,
        'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ',
      ]);
    }
    old.close();
    final store = await AccountStore.open(
      sqlitePath: path,
      legacyDirectory: dir.path,
      legacyLoader: () async => {},
    );
    expect(store.keys.toList(), ['z', 'a']);
    store.reorder(['a', 'z']);
    expect(store.keys.toList(), ['a', 'z']);
    expect(store.get('z')!.secret, 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ');
    store.close();
    await dir.delete(recursive: true);
  });
}
