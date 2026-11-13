import 'dart:convert';
import 'dart:io';

import 'package:authenticator/entities/account.entity.dart';
import 'package:authenticator/home/home.screen.dart';
import 'package:authenticator/repository.dart' as storage;
import 'package:authenticator/storage/account_store.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';

AccountEntity fixture(String issuer, String? name) => AccountEntity()
  ..type = AccountType.TOTP
  ..issuer = issuer
  ..name = name
  ..secret = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ'
  ..digits = 6
  ..period = 30;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('account identity', () {
    late Directory directory;
    late storage.AccountRepository repository;
    setUp(() async {
      directory = await Directory.systemTemp.createTemp('auth-identity-');
      repository = storage.AccountRepository(
        await AccountStore.open(
          sqlitePath: '${directory.path}/accounts.sqlite3',
          legacyDirectory: directory.path,
        ),
      );
    });
    tearDown(() async {
      repository.dispose();
      await directory.delete(recursive: true);
    });

    test('missing name and literal null never share a key', () async {
      final absent = fixture('Issuer', null);
      final literal = fixture('Issuer', 'null');
      final absentKey = repository.keyFor(absent);
      await repository.put(absentKey, absent);
      final literalKey = repository.keyFor(literal);
      expect(literalKey, isNot(absentKey));
      await repository.put(literalKey, literal);
      expect(repository.length, 2);
      expect(repository.get(absentKey)!.name, isNull);
      expect(repository.get(literalKey)!.name, 'null');
    });

    test('colon combinations never share a key', () async {
      final first = fixture('a:b', 'c');
      final second = fixture('a', 'b:c');
      final firstKey = repository.keyFor(first);
      await repository.put(firstKey, first);
      final secondKey = repository.keyFor(second);
      expect(secondKey, isNot(firstKey));
      await repository.put(secondKey, second);
      expect(repository.length, 2);
      expect(repository.get(firstKey)!.issuer, 'a:b');
    });

    test('same fields update legacy key without rewriting it or adding a copy', () async {
      await repository.put('Issuer:null', fixture('Issuer', null));
      final replacement = fixture('Issuer', null)..digits = 8;
      final key = repository.keyFor(replacement);
      expect(key, 'Issuer:null');
      expect(repository.containsKey(key), isTrue); // Existing Update prompt.
      await repository.put(key, replacement);
      expect(repository.length, 1);
      expect(repository.get('Issuer:null')!.digits, 8);
      // A distinct name that collided under the old encoding remains separate.
      final different = fixture('Issuer', 'null');
      expect(repository.containsKey(repository.keyFor(different)), isFalse);
    });

    test(
      'arbitrary legacy keys cannot be overwritten by generated keys',
      () async {
        final incoming = fixture('New', 'user');
        final base = jsonEncode([incoming.issuer, incoming.name]);
        await repository.put(base, fixture('Old', 'one'));
        await repository.put('$base#1', fixture('Old', 'two'));
        final key = repository.keyFor(incoming);
        expect(key, '$base#2');
        await repository.put(key, incoming);
        expect(repository.length, 3);
        expect(repository.get(base)!.issuer, 'Old');
        expect(repository.get('$base#1')!.name, 'two');
        expect(repository.keyFor(incoming), key);
      },
    );
  });

  testWidgets('dragging a card scrolls the whole page to the last account', (
    tester,
  ) async {
    final directory = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('auth-scroll-'),
    ))!;
    late storage.AccountRepository repository;
    await tester.runAsync(() async {
      repository = storage.AccountRepository(
        await AccountStore.open(
          sqlitePath: '${directory.path}/accounts.sqlite3',
          legacyDirectory: directory.path,
        ),
      );
      for (var index = 0; index < 25; index++) {
        final account = fixture('Account $index', 'user');
        await repository.put(repository.keyFor(account), account);
      }
    });
    storage.accounts = repository;
    await tester.pumpWidget(const CupertinoApp(home: HomeScreen()));
    expect(find.byType(SliverList), findsOneWidget);
    // Start within the account list and verify the outer page remains scrollable.
    for (var drag = 0; drag < 15; drag++) {
      await tester.dragFrom(const Offset(180, 450), const Offset(0, -500));
      await tester.pump(const Duration(milliseconds: 300));
    }
    await tester.pumpAndSettle();
    expect(find.text('Account 24').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    repository.dispose();
    await tester.runAsync(() => directory.delete(recursive: true));
  });
}
