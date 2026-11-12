import 'dart:io';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:authenticator/entities/account.entity.dart';
import 'package:authenticator/repository.dart' as storage;
import 'package:authenticator/storage/account_store.dart';
import 'package:authenticator/home/widgets/account.card.dart';
import 'package:authenticator/home/home.screen.dart';

// RFC 6238 public test secret only. Never use a real user's OTP seed here.
AccountEntity account(String issuer, String? name) => AccountEntity()
  ..type = AccountType.TOTP
  ..issuer = issuer
  ..name = name
  ..secret = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ'
  ..digits = 6
  ..period = 30;

void main() {
  late Directory directory;
  late Box<AccountEntity> legacyBox;
  AccountStore? store;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('auth-regression-');
    Hive.init(directory.path);
    if (!Hive.isAdapterRegistered(0))
      Hive.registerAdapter(AccountTypeAdapter());
    if (!Hive.isAdapterRegistered(1))
      Hive.registerAdapter(AccountEntityAdapter());
    legacyBox = await Hive.openBox<AccountEntity>('accounts');
  });
  tearDown(() async {
    store?.close();
    store = null;
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test(
    'multiple accounts including a missing name survive repeated reopen',
    () async {
      final records = [
        account('First', 'alice'),
        account('Second', null),
        account('Third', 'bob'),
      ];
      for (final record in records) {
        await legacyBox.put('${record.issuer}:${record.name}', record);
      }
      for (var restart = 0; restart < 3; restart++) {
        await Hive.close();
        legacyBox = await Hive.openBox<AccountEntity>('accounts');
        expect(legacyBox.length, 3);
        expect(legacyBox.get('Second:null')!.name, isNull);
        expect(legacyBox.get('Second:null')!.secret, records[1].secret);
      }
    },
  );

  testWidgets('a persisted account with no optional name still renders', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await legacyBox.put('Second:null', account('Second', null));
      await Hive.close();
      legacyBox = await Hive.openBox<AccountEntity>('accounts');
      await Hive.close();
      store = await AccountStore.open(
        sqlitePath: '${directory.path}/accounts.sqlite3',
        legacyDirectory: directory.path,
      );
      storage.accounts = storage.AccountRepository(store!);
    });
    await tester.pumpWidget(
      CupertinoApp(home: AccountCard(store!.get('Second:null')!)),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Second'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('invalid legacy record does not crash or remove stored records', (
    tester,
  ) async {
    final invalid = account('Invalid', 'user')..period = 0;
    await tester.runAsync(() async {
      await legacyBox.put('Invalid:user', invalid);
      await Hive.close();
      store = await AccountStore.open(
        sqlitePath: '${directory.path}/accounts.sqlite3',
        legacyDirectory: directory.path,
      );
      storage.accounts = storage.AccountRepository(store!);
    });
    await tester.pumpWidget(CupertinoApp(home: AccountCard(invalid)));
    expect(tester.takeException(), isNull);
    expect(find.text('Unable to generate code'), findsOneWidget);
    expect(store!.length, 1);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('search handles an issuer-only account with a null name', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await legacyBox.put('Second:null', account('Second', null));
      await Hive.close();
      store = await AccountStore.open(
        sqlitePath: '${directory.path}/accounts.sqlite3',
        legacyDirectory: directory.path,
      );
      storage.accounts = storage.AccountRepository(store!);
    });
    await tester.pumpWidget(const CupertinoApp(home: HomeScreen()));
    await tester.pump();
    expect(find.text('Second'), findsOneWidget);
    // The navigation bar initially owns the tap to activate its search overlay.
    await tester.tapAt(tester.getCenter(find.byType(CupertinoSearchTextField)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(CupertinoSearchTextField), 'unmatched');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Second'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('lowercase legacy secret migrates unchanged and renders', (
    tester,
  ) async {
    final legacy = account('Lowercase', null);
    legacy.secret = legacy.secret.toLowerCase();
    await tester.runAsync(() async {
      await legacyBox.put('Lowercase:null', legacy);
      await Hive.close();
      store = await AccountStore.open(
        sqlitePath: '${directory.path}/accounts.sqlite3',
        legacyDirectory: directory.path,
      );
      storage.accounts = storage.AccountRepository(store!);
    });
    expect(store!.get('Lowercase:null')!.secret, legacy.secret);
    await tester.pumpWidget(
      CupertinoApp(home: AccountCard(store!.get('Lowercase:null')!)),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Unable to generate code'), findsNothing);
    expect(find.text('Lowercase'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('same-key replacement refreshes generator and period timer', (
    tester,
  ) async {
    final before = account('Replacement', 'user')..period = 60;
    final after = account('Replacement', 'user')
      ..period = 1
      ..digits = 8;
    const key = ValueKey('Replacement:user');
    await tester.pumpWidget(CupertinoApp(home: AccountCard(before, key: key)));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(CupertinoApp(home: AccountCard(after, key: key)));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    final codeTexts = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => (text.data ?? '').replaceAll(' ', ''));
    expect(codeTexts.any((text) => RegExp(r'^\d{8}$').hasMatch(text)), isTrue);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('empty legacy issuer with a valid name migrates and generates code', (
    tester,
  ) async {
    final legacy = account('', 'user');
    await tester.runAsync(() async {
      await legacyBox.put(':user', legacy);
      await Hive.close();
      store = await AccountStore.open(
        sqlitePath: '${directory.path}/accounts.sqlite3',
        legacyDirectory: directory.path,
      );
      storage.accounts = storage.AccountRepository(store!);
    });
    final restored = store!.get(':user')!;
    expect(restored.issuer, '');
    expect(restored.name, 'user');
    expect(restored.secret, legacy.secret);
    await tester.pumpWidget(CupertinoApp(home: AccountCard(restored)));
    expect(tester.takeException(), isNull);
    expect(find.text('Unable to generate code'), findsNothing);
    expect(find.text('user'), findsOneWidget);
    final codeTexts = tester.widgetList<Text>(find.byType(Text))
        .map((text) => (text.data ?? '').replaceAll(' ', ''));
    expect(codeTexts.any((text) => RegExp(r'^\d{6}$').hasMatch(text)), isTrue);
    await tester.pumpWidget(const SizedBox());
  });

}
