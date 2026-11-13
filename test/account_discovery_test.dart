import 'dart:io';
import 'dart:ui' show SemanticsAction;

import 'package:authenticator/entities/parse_account.dart';
import 'package:authenticator/home/home.screen.dart';
import 'package:authenticator/home/widgets/account.card.dart';
import 'package:authenticator/repository.dart' as storage;
import 'package:authenticator/storage/account_store.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('empty and no results are distinct and query can be cleared', (
    tester,
  ) async {
    final dir = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('account-search-'),
    ))!;
    final repo = (await tester.runAsync(
      () async => storage.AccountRepository(
        await AccountStore.open(
          sqlitePath: '${dir.path}/accounts.sqlite3',
          legacyDirectory: dir.path,
          legacyLoader: () async => {},
        ),
      ),
    ))!;
    storage.accounts = repo;
    await tester.pumpWidget(const CupertinoApp(home: HomeScreen()));
    await tester.pump();
    expect(find.text('No accounts yet.'), findsOneWidget);
    expect(find.text('Add an account'), findsOneWidget);
    await repo.put(
      'one',
      accountFromFields(
        type: .TOTP,
        issuer: 'Example',
        name: 'Alice',
        secret: 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ',
      ),
    );
    await tester.pump();
    expect(find.text('No accounts yet.'), findsNothing);
    tester
        .widget<CupertinoSearchTextField>(find.byType(CupertinoSearchTextField))
        .onChanged!('missing');
    await tester.pump();
    expect(find.text('No matching accounts.'), findsOneWidget);
    await tester.tap(find.text('Clear search'));
    await tester.pump();
    expect(find.text('No matching accounts.'), findsNothing);
    expect(find.text('Example'), findsOneWidget);
    final search = tester.widget<CupertinoSearchTextField>(
      find.byType(CupertinoSearchTextField),
    );
    search.onChanged!('aLiCe');
    await tester.pump();
    expect(find.text('Example'), findsOneWidget);
    search.onChanged!('unknown');
    await tester.pump();
    expect(find.text('No matching accounts.'), findsOneWidget);
    search.onChanged!('');
    await tester.pump();
    final semantics = tester.ensureSemantics();
    await tester.pump();
    final code = find.bySemanticsLabel(
      RegExp(r'.*Code .* Double tap to copy\.'),
    );
    expect(code, findsOneWidget);
    expect(
      tester
          .getSemantics(code)
          .getSemanticsData()
          .hasAction(SemanticsAction.tap),
      isTrue,
    );
    var copied = false;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') copied = true;
        return null;
      },
    );
    final node = tester.getSemantics(code);
    node.owner!.performAction(node.id, SemanticsAction.tap);
    await tester.pump();
    expect(copied, isTrue);
    copied = false;
    final text = find.descendant(of: code, matching: find.byType(Text)).first;
    Focus.of(tester.element(text)).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(copied, isTrue);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
    semantics.dispose();
    await tester.pumpWidget(const SizedBox());
    repo.dispose();
    await tester.runAsync(() => dir.delete(recursive: true));
  });
  testWidgets(
    'long account labels remain usable at large text size on a narrow screen',
    (tester) async {
      final dir = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('account-layout-'),
      ))!;
      final repo = (await tester.runAsync(
        () async => storage.AccountRepository(
          await AccountStore.open(
            sqlitePath: '${dir.path}/accounts.sqlite3',
            legacyDirectory: dir.path,
            legacyLoader: () async => {},
          ),
        ),
      ))!;
      storage.accounts = repo;
      await repo.put(
        'one',
        accountFromFields(
          type: .TOTP,
          issuer: 'A very long issuer name 测试测试测试测试测试测试',
          name: 'A very long account name alice@example.example.example',
          secret: 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ',
        ),
      );
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        CupertinoApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(3.2)),
            child: child!,
          ),
          home: const HomeScreen(),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(
        find.text('A very long issuer name 测试测试测试测试测试测试'),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      tester.view.physicalSize = const Size(600, 450);
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      repo.dispose();
      await tester.runAsync(() => dir.delete(recursive: true));
    },
  );
  testWidgets('large account collections are built lazily', (tester) async {
    final dir = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('account-many-'),
    ))!;
    final repo = (await tester.runAsync(
      () async => storage.AccountRepository(
        await AccountStore.open(
          sqlitePath: '${dir.path}/accounts.sqlite3',
          legacyDirectory: dir.path,
          legacyLoader: () async => {},
        ),
      ),
    ))!;
    storage.accounts = repo;
    for (var i = 0; i < 100; i++) {
      await repo.put(
        'item-$i',
        accountFromFields(
          type: .TOTP,
          issuer: 'Service $i',
          secret: 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ',
        ),
      );
    }
    await tester.pumpWidget(const CupertinoApp(home: HomeScreen()));
    await tester.pump();
    expect(find.byType(AccountCard).evaluate().length, lessThan(100));
    await tester.pumpWidget(const SizedBox());
    repo.dispose();
    await tester.runAsync(() => dir.delete(recursive: true));
  });
  testWidgets('search matches Unicode names and preserves duplicate issuers', (
    tester,
  ) async {
    final dir = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('account-unicode-'),
    ))!;
    final repo = (await tester.runAsync(
      () async => storage.AccountRepository(
        await AccountStore.open(
          sqlitePath: '${dir.path}/accounts.sqlite3',
          legacyDirectory: dir.path,
          legacyLoader: () async => {},
        ),
      ),
    ))!;
    storage.accounts = repo;
    for (final name in ['小明', '小红']) {
      await repo.put(
        name,
        accountFromFields(
          type: .TOTP,
          issuer: '服务',
          name: name,
          secret: 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ',
        ),
      );
    }
    await tester.pumpWidget(const CupertinoApp(home: HomeScreen()));
    await tester.pump();
    final field = tester.widget<CupertinoSearchTextField>(
      find.byType(CupertinoSearchTextField),
    );
    field.onChanged!('服务');
    await tester.pump();
    expect(find.text('服务'), findsNWidgets(2));
    field.onChanged!('小明');
    await tester.pump();
    expect(find.text('小明'), findsOneWidget);
    expect(find.text('小红'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    repo.dispose();
    await tester.runAsync(() => dir.delete(recursive: true));
  });
}
