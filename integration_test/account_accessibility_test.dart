import 'dart:io';
import 'dart:ui' show SemanticsAction;

import 'package:authenticator/entities/parse_account.dart';
import 'package:authenticator/home/home.screen.dart';
import 'package:authenticator/repository.dart' as storage;
import 'package:authenticator/storage/account_store.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('account code exposes a copy action on device', (tester) async {
    final temp = await getTemporaryDirectory();
    final dir = await Directory('${temp.path}/account-accessibility-test')
        .create(recursive: true);
    final repo = storage.AccountRepository(
      await AccountStore.open(
        sqlitePath: '${dir.path}/test.sqlite3',
        legacyDirectory: dir.path,
        legacyLoader: () async => {},
      ),
    );
    storage.accounts = repo;
    await repo.put(
      'fixture',
      accountFromFields(
        type: .TOTP,
        issuer: 'Public fixture',
        secret: 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ',
      ),
    );
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(const CupertinoApp(home: HomeScreen()));
    await tester.pumpAndSettle();
    final code = find.bySemanticsLabel(RegExp(r'Code .* Double tap to copy\.'));
    expect(code, findsOneWidget);
    expect(
      tester
          .getSemantics(code)
          .getSemanticsData()
          .hasAction(SemanticsAction.tap),
      isTrue,
    );
    semantics.dispose();
    await tester.pumpWidget(const SizedBox());
    repo.dispose();
    await dir.delete(recursive: true);
  });
}
