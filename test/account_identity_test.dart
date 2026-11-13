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
    test(
      'ambiguous matching labels never choose a replacement identity',
      () async {
        final first = fixture('Shared', 'same');
        final second = fixture('Shared', 'same')..secret = 'JBSWY3DPEHPK3PXP';
        await repository.put('first', first);
        await repository.put('second', second);
        expect(
          () => repository.keyFor(fixture('Shared', 'same')),
          throwsStateError,
        );
        expect(repository.get('first')!.secret, first.secret);
        expect(repository.get('second')!.secret, second.secret);
      },
    );
    test('empty and missing names cannot bypass ambiguity detection', () async {
      await repository.put('empty', fixture('Service', ''));
      expect(repository.keyFor(fixture('Service', null)), 'empty');
      expect(
        () =>
            repository.store.insertNewBatch({'new': fixture('Service', null)}),
        throwsStateError,
      );
      expect(repository.length, 1);
      await repository.put('missing', fixture('Service', null));
      expect(
        () => repository.keyFor(fixture('Service', null)),
        throwsStateError,
      );
      expect(repository.length, 2);
    });
  });

  testWidgets('ambiguous replacement explains how to disambiguate', (
    tester,
  ) async {
    final dir = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('auth-ambiguous-'),
    ))!;
    final repo = (await tester.runAsync(
      () async => storage.AccountRepository(
        await AccountStore.open(
          sqlitePath: '${dir.path}/db.sqlite3',
          legacyDirectory: dir.path,
          legacyLoader: () async => {},
        ),
      ),
    ))!;
    storage.accounts = repo;
    await repo.put('first', fixture('Shared', 'same'));
    await repo.put(
      'second',
      fixture('Shared', 'same')..secret = 'JBSWY3DPEHPK3PXP',
    );
    await tester.pumpWidget(const CupertinoApp(home: HomeScreen()));
    final dynamic state = tester.state(find.byType(HomeScreen));
    state.reviewAndSave(fixture('Shared', 'same'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Multiple accounts have these labels'),
      findsOneWidget,
    );
    expect(repo.get('first')!.secret, 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ');
    expect(repo.get('second')!.secret, 'JBSWY3DPEHPK3PXP');
    await tester.pumpWidget(const SizedBox());
    repo.dispose();
    await tester.runAsync(() => dir.delete(recursive: true));
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
    expect(
      tester.widget<ListView>(find.byType(ListView)).physics,
      isA<NeverScrollableScrollPhysics>(),
    );
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
