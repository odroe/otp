import 'dart:io';

import 'package:authenticator/entities/parse_account.dart';
import 'package:authenticator/home/manage_accounts.screen.dart';
import 'package:authenticator/repository.dart' as storage;
import 'package:authenticator/storage/account_store.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('edit labels and move account without changing HOTP counter', (
    tester,
  ) async {
    final dir = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('manage-accounts-'),
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
    await repo.put(
      'a',
      accountFromFields(
        type: .HOTP,
        issuer: 'Alpha',
        name: 'alice',
        counter: '7',
        secret: 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ',
      ),
    );
    await repo.put(
      'b',
      accountFromFields(
        type: .TOTP,
        issuer: 'Beta',
        secret: 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ',
      ),
    );
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      CupertinoApp(navigatorKey: nav, home: const ManageAccountsScreen()),
    );
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Move Beta, account 2 of 2 up'));
    await tester.pumpAndSettle();
    expect(repo.store.keys.toList(), ['b', 'a']);
    final drag = find.byType(ReorderableDragStartListener).first;
    final gesture = await tester.startGesture(tester.getCenter(drag));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 20));
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.moveBy(const Offset(0, 70));
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.moveBy(const Offset(0, 70));
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(repo.store.keys.toList(), ['a', 'b']);
    await tester.tap(find.bySemanticsLabel('Move Beta, account 2 of 2 up'));
    await tester.pumpAndSettle();
    expect(repo.store.keys.toList(), ['b', 'a']);
    await tester.tap(
      find.bySemanticsLabel('Edit Alpha, alice, account 2 of 2'),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(CupertinoTextField, 'Service'),
      '',
    );
    await tester.enterText(
      find.widgetWithText(CupertinoTextField, 'Account'),
      '',
    );
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(
      find.text('Enter a label no longer than 1024 characters.'),
      findsOneWidget,
    );
    expect(repo.get('a')!.issuer, 'Alpha');
    await tester.enterText(
      find.widgetWithText(CupertinoTextField, 'Service'),
      'x' * 1025,
    );
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(
      find.text('Enter a label no longer than 1024 characters.'),
      findsOneWidget,
    );
    expect(repo.get('a')!.issuer, 'Alpha');
    await tester.enterText(
      find.widgetWithText(CupertinoTextField, 'Service'),
      'Unsaved',
    );
    nav.currentState!.pop();
    await tester.pumpAndSettle();
    expect(repo.get('a')!.issuer, 'Alpha');
    await tester.tap(
      find.bySemanticsLabel('Edit Alpha, alice, account 2 of 2'),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(CupertinoTextField, 'Service'),
      'Changed',
    );
    await tester.enterText(
      find.widgetWithText(CupertinoTextField, 'Account'),
      '新名称',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(repo.get('a')!.issuer, 'Changed');
    expect(repo.get('a')!.name, '新名称');
    expect(repo.get('a')!.counter, 7);
    expect(repo.store.keys.toList(), ['b', 'a']);
    await tester.pumpWidget(const SizedBox());
    repo.dispose();
    await tester.runAsync(() => dir.delete(recursive: true));
  });
}
