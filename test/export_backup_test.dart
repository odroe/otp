import 'dart:io';
import 'dart:typed_data';

import 'package:authenticator/backup/export_backup.dart';
import 'package:authenticator/backup/offline_backup.dart';
import 'package:authenticator/entities/account_code.dart';
import 'package:authenticator/entities/parse_account.dart';
import 'package:authenticator/home/export_backup.screen.dart';
import 'package:authenticator/repository.dart' as storage;
import 'package:authenticator/storage/account_store.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const secret = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ';
  test(
    'encrypted export verifies round-trip and preserves the source counter',
    () async {
      final account = accountFromFields(
        type: .HOTP,
        issuer: 'Acme',
        secret: secret,
        counter: '7',
      );
      Uint8List? received;
      final exporter = BackupExporter((bytes, filename) async {
        expect(filename, 'authenticator-backup.oab');
        received = Uint8List.fromList(bytes);
        return true;
      });
      expect(
        await exporter.export([
          BackupEntry('key', account),
        ], password: 'fixture password'),
        isTrue,
      );
      expect(account.counter, 7);
      final restored = await OfflineBackup.decode(
        received!,
        password: 'fixture password',
      );
      expect(restored.single.account.counter, 7);
      expect(accountCode(restored.single.account), accountCode(account));
    },
  );
  test('cancellation is not success and transient bytes are cleared', () async {
    Uint8List? transient;
    final exporter = BackupExporter((bytes, filename) async {
      transient = bytes;
      return false;
    });
    expect(await exporter.export([]), isFalse);
    expect(transient, isNotNull);
    expect(transient!.every((byte) => byte == 0), isTrue);
  });
  test('save failures propagate and transient bytes are cleared', () async {
    Uint8List? transient;
    final exporter = BackupExporter((bytes, filename) async {
      transient = bytes;
      throw StateError('disk full');
    });
    await expectLater(exporter.export([]), throwsStateError);
    expect(transient!.every((byte) => byte == 0), isTrue);
  });
  testWidgets('password export validates confirmation before saving', (
    tester,
  ) async {
    final dir = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('export-ui-'),
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
      'hotp',
      accountFromFields(
        type: .HOTP,
        issuer: 'Acme',
        secret: secret,
        counter: '7',
      ),
    );
    var calls = 0;
    String? usedPassword;
    List<BackupEntry>? usedSnapshot;
    await tester.pumpWidget(
      CupertinoApp(
        home: ExportBackupScreen(
          exportAction: (snapshot, password) async {
            calls++;
            usedSnapshot = snapshot;
            usedPassword = password;
            return true;
          },
        ),
      ),
    );
    await tester.tap(find.text('Choose destination'));
    await tester.pump();
    expect(
      find.text('Enter and confirm the same nonempty backup password.'),
      findsOneWidget,
    );
    expect(calls, 0);
    await tester.enterText(
      find.widgetWithText(CupertinoTextField, 'Backup password'),
      'fixture password',
    );
    await tester.enterText(
      find.widgetWithText(CupertinoTextField, 'Confirm backup password'),
      'fixture password',
    );
    await tester.ensureVisible(find.text('Choose destination'));
    await tester.tap(find.text('Choose destination'));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(
      find.text('Backup saved to the selected location. Keep it safe.'),
      findsOneWidget,
    );
    expect(calls, 1);
    expect(usedPassword, 'fixture password');
    expect(usedSnapshot!.single.account.counter, 7);
    expect(repo.values.single.counter, 7);
    await tester.pumpWidget(const SizedBox());
    repo.dispose();
    await tester.runAsync(() => dir.delete(recursive: true));
  });
  testWidgets('plaintext requires warning and cancellation is not success', (
    tester,
  ) async {
    final dir = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('export-cancel-'),
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
    var calls = 0;
    await tester.pumpWidget(
      CupertinoApp(
        home: ExportBackupScreen(
          exportAction: (snapshot, password) async {
            calls++;
            expect(password, isNull);
            return false;
          },
        ),
      ),
    );
    await tester.tap(find.text('Plaintext'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose destination'));
    await tester.pumpAndSettle();
    expect(find.text('Export without a password?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    await tester.tap(find.text('Choose destination'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export plaintext'));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Save cancelled.'), findsOneWidget);
    expect(
      find.text('Backup saved to the selected location. Keep it safe.'),
      findsNothing,
    );
    await tester.pumpWidget(const SizedBox());
    repo.dispose();
    await tester.runAsync(() => dir.delete(recursive: true));
  });
}
