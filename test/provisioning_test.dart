import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:authenticator/entities/account_code.dart';
import 'package:authenticator/entities/parse_account.dart';
import 'package:authenticator/home/home.screen.dart';
import 'package:authenticator/repository.dart' as storage;
import 'package:authenticator/storage/account_store.dart';
import 'package:base32/base32.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class FakeScanner() extends MobileScannerPlatform {
  @override
  Stream<BarcodeCapture?> get barcodesStream => const Stream.empty();
  @override
  Stream<TorchState> get torchStateStream => const Stream.empty();
  @override
  Stream<double> get zoomScaleStateStream => const Stream.empty();
  @override
  Widget buildCameraView() => const SizedBox();
  @override
  Future<MobileScannerViewAttributes> start(StartOptions options) async =>
      const MobileScannerViewAttributes(
        cameraDirection: CameraFacing.back,
        currentTorchMode: TorchState.off,
        size: Size(400, 400),
      );
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
  @override
  Future<void> updateScanWindow(Rect? window) async {}
}

void main() {
  const secret = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ';
  test('HOTP matches RFC 4226 counter 1', () {
    final account = parseAccount(
      'otpauth://hotp/Acme:user?secret=$secret&counter=1',
    );
    expect(accountCode(account), '287082');
  });
  test('QR and manual entry produce equivalent configuration', () {
    final scanned = parseAccount(
      'otpauth://hotp/Acme:user?secret=$secret&counter=5&algorithm=SHA512&digits=7',
    );
    final manual = accountFromFields(
      type: .HOTP,
      issuer: 'Acme',
      name: 'user',
      secret: secret,
      counter: '5',
      algorithm: 'SHA512',
      digits: '7',
    );
    expect(accountCode(scanned), accountCode(manual));
    expect(scanned.counter, manual.counter);
    expect(scanned.algorithm, manual.algorithm);
  });
  test(
    'TOTP uses the instant and advances precisely at the period boundary',
    () {
      final a = parseAccount('otpauth://totp/Acme?secret=$secret&digits=8');
      final before = DateTime.fromMillisecondsSinceEpoch(59999, isUtc: true);
      final at = DateTime.fromMillisecondsSinceEpoch(60000, isUtc: true);
      expect(accountCode(a, at: before), '94287082');
      expect(accountCode(a, at: at), '37359152');
      expect(accountCode(a, at: at.toLocal()), accountCode(a, at: at));
    },
  );
  test('TOTP supports RFC timestamps beyond 2038', () {
    final account = parseAccount('otpauth://totp/Acme?secret=$secret&digits=8');
    expect(
      accountCode(
        account,
        at: DateTime.fromMillisecondsSinceEpoch(
          20000000000 * 1000,
          isUtc: true,
        ),
      ),
      '65353130',
    );
  });
  for (final (algorithm, key, expected) in [
    ('SHA1', '12345678901234567890', '94287082'),
    ('SHA256', '12345678901234567890123456789012', '46119246'),
    (
      'SHA512',
      '1234567890123456789012345678901234567890123456789012345678901234',
      '90693936',
    ),
  ]) {
    test('TOTP $algorithm matches RFC 6238 at 59 seconds', () {
      final encoded = base32.encode(Uint8List.fromList(ascii.encode(key)));
      final account = parseAccount(
        'otpauth://totp/Acme?secret=$encoded&algorithm=$algorithm&digits=8',
      );
      expect(
        accountCode(
          account,
          at: DateTime.fromMillisecondsSinceEpoch(59000, isUtc: true),
        ),
        expected,
      );
    });
  }
  testWidgets('manual HOTP preview, save, advance and reopen', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final dir = await tester.runAsync(
      () => Directory.systemTemp.createTemp('auth-provision-'),
    );
    var repo = await tester.runAsync(
      () async => storage.AccountRepository(
        await AccountStore.open(
          sqlitePath: '${dir!.path}/accounts.sqlite3',
          legacyDirectory: dir.path,
          legacyLoader: () async => {},
        ),
      ),
    );
    final directory = dir!;
    var repository = repo!;
    storage.accounts = repository;
    await tester.pumpWidget(const CupertinoApp(home: HomeScreen()));
    await tester.tap(find.bySemanticsLabel('Add account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enter manually'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('HOTP'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(CupertinoTextField, 'Service / issuer'),
      'Acme',
    );
    await tester.enterText(
      find.widgetWithText(CupertinoTextField, 'Base32 secret'),
      secret,
    );
    await tester.enterText(
      find.widgetWithText(CupertinoTextField, 'Initial counter'),
      '1',
    );
    await tester.enterText(
      find.widgetWithText(CupertinoTextField, 'Digits (6–8)'),
      '8',
    );
    await tester.ensureVisible(find.text('Review'));
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    expect(find.text('Review account'), findsOneWidget);
    expect(repository.length, 0);
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(repository.length, 1);
    expect(find.text('942 870 82'), findsOneWidget);
    expect(repository.values.single.counter, 1);
    await tester.tap(find.text('Next code'));
    await tester.pumpAndSettle();
    expect(repository.values.single.counter, 2);
    await tester.tap(find.bySemanticsLabel('Add account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enter manually'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(CupertinoTextField, 'Service / issuer'),
      'Acme',
    );
    await tester.enterText(
      find.widgetWithText(CupertinoTextField, 'Base32 secret'),
      secret,
    );
    await tester.ensureVisible(find.text('Review'));
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(CupertinoAlertDialog),
        matching: find.text('Add'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Account already exists'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(CupertinoAlertDialog),
        matching: find.text('Cancel'),
      ),
    );
    await tester.pumpAndSettle();
    expect(repository.length, 1);
    expect(repository.values.single.counter, 2);
    await tester.pumpWidget(const SizedBox());
    repository.dispose();
    repository = (await tester.runAsync(
      () async => storage.AccountRepository(
        await AccountStore.open(
          sqlitePath: '${directory.path}/accounts.sqlite3',
          legacyDirectory: directory.path,
          legacyLoader: () async => {},
        ),
      ),
    ))!;
    expect(repository.values.single.counter, 2);
    expect(accountCode(repository.values.single), '37359152');
    repository.dispose();
    await tester.runAsync(() => directory.delete(recursive: true));
  });
  testWidgets('QR preview cancellation never persists an account', (
    tester,
  ) async {
    final directory = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('auth-scan-'),
    ))!;
    final repo = (await tester.runAsync(
      () async => storage.AccountRepository(
        await AccountStore.open(
          sqlitePath: '${directory.path}/accounts.sqlite3',
          legacyDirectory: directory.path,
          legacyLoader: () async => {},
        ),
      ),
    ))!;
    final oldPlatform = MobileScannerPlatform.instance;
    MobileScannerPlatform.instance = FakeScanner();
    storage.accounts = repo;
    await tester.pumpWidget(const CupertinoApp(home: HomeScreen()));
    await tester.tap(find.bySemanticsLabel('Add account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Scan QR code'));
    await tester.pumpAndSettle();
    tester.widget<MobileScanner>(find.byType(MobileScanner)).onDetect!(
      const BarcodeCapture(
        barcodes: [
          Barcode(
            format: BarcodeFormat.qrCode,
            rawValue:
                'otpauth://totp/Acme:user?secret=$secret&algorithm=SHA256&digits=8&period=60',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Review account'), findsOneWidget);
    expect(repo.length, 0);
    await tester.tap(
      find.descendant(
        of: find.byType(CupertinoAlertDialog),
        matching: find.text('Cancel'),
      ),
    );
    await tester.pumpAndSettle();
    expect(repo.length, 0);
    await tester.tap(find.bySemanticsLabel('Add account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Scan QR code'));
    await tester.pumpAndSettle();
    tester.widget<MobileScanner>(find.byType(MobileScanner)).onDetect!(
      const BarcodeCapture(
        barcodes: [
          Barcode(
            format: BarcodeFormat.qrCode,
            rawValue:
                'otpauth://totp/Acme:user?secret=$secret&algorithm=SHA256&digits=8&period=60',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(CupertinoAlertDialog),
        matching: find.text('Add'),
      ),
    );
    await tester.pumpAndSettle();
    expect(repo.values.single.algorithm.name, 'sha256');
    expect(repo.values.single.digits, 8);
    expect(repo.values.single.period, 60);
    await tester.pumpWidget(const SizedBox());
    MobileScannerPlatform.instance = oldPlatform;
    repo.dispose();
    final reopened = (await tester.runAsync(
      () async => AccountStore.open(
        sqlitePath: '${directory.path}/accounts.sqlite3',
        legacyDirectory: directory.path,
        legacyLoader: () async => {},
      ),
    ))!;
    expect(reopened.values.single.algorithm.name, 'sha256');
    expect(reopened.values.single.period, 60);
    reopened.close();
    await tester.runAsync(() => directory.delete(recursive: true));
  });
}
