import 'dart:async';
import 'dart:io';

import 'package:authenticator/entities/account.entity.dart';
import 'package:authenticator/home/home.screen.dart';
import 'package:authenticator/home/scan.screen.dart';
import 'package:authenticator/home/widgets/account.card.dart';
import 'package:authenticator/home/widgets/help.dart';
import 'package:authenticator/repository.dart' as repository;
import 'package:authenticator/storage/account_store.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

AccountEntity fixture({int digits = 6}) => AccountEntity()
  ..type = AccountType.TOTP
  ..issuer = 'Public test'
  ..name = 'user'
  ..secret = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ'
  ..digits = digits
  ..period = 30;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('mixed captures select QR only, skipping missing values', () {
    expect(
      qrCodeValue(
        const BarcodeCapture(
          barcodes: [
            Barcode(format: BarcodeFormat.code128, rawValue: 'not QR'),
            Barcode(format: BarcodeFormat.qrCode),
            Barcode(format: BarcodeFormat.qrCode, rawValue: 'QR value'),
          ],
        ),
      ),
      'QR value',
    );
    expect(
      qrCodeValue(
        const BarcodeCapture(
          barcodes: [
            Barcode(format: BarcodeFormat.code128, rawValue: 'not QR'),
          ],
        ),
      ),
      isNull,
    );
    expect(qrCodeValue(const BarcodeCapture()), isNull);
  });

  testWidgets('add and delete controls have meaningful semantics', (
    tester,
  ) async {
    final directory = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('auth-ui-review-'),
    ))!;
    late AccountStore store;
    await tester.runAsync(() async {
      store = await AccountStore.open(
        sqlitePath: '${directory.path}/accounts.sqlite3',
        legacyDirectory: directory.path,
      );
    });
    repository.accounts = repository.AccountRepository(store);
    await repository.accounts.put('fixture', fixture());
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(const CupertinoApp(home: HomeScreen()));
    expect(find.bySemanticsLabel('Add account'), findsOneWidget);
    expect(find.bySemanticsLabel('Delete account'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    semantics.dispose();
    repository.accounts.dispose();
    await tester.runAsync(() => directory.delete(recursive: true));
  });

  for (final unmount in [false, true]) {
    testWidgets(
      unmount
          ? 'pending clipboard completion is safe after card unmounts'
          : 'copy confirmation reuses the exact captured code',
      (tester) async {
        final pending = Completer<void>();
        String? copied;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              copied = (call.arguments as Map)['text'] as String;
              await pending.future;
            }
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        await tester.pumpWidget(
          CupertinoApp(
            home: AccountCard(fixture(), key: const ValueKey('card')),
          ),
        );
        final codeFinder = find.textContaining(RegExp(r'^\d{3} \d{3}'));
        final displayed = tester
            .widget<Text>(codeFinder)
            .data!
            .replaceAll(' ', '');
        await tester.tap(codeFinder);
        await tester.pump();
        expect(copied, matches(RegExp(r'^\d{6}$')));
        expect(copied, displayed);
        if (unmount) {
          await tester.pumpWidget(const SizedBox());
        } else {
          // Changing OTP while clipboard is pending must not alter the copy.
          await tester.pumpWidget(
            CupertinoApp(
              home: AccountCard(
                fixture(digits: 8),
                key: const ValueKey('card'),
              ),
            ),
          );
        }
        pending.complete();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
        if (!unmount) {
          expect(find.textContaining('Copied'), findsNothing);
          expect(find.byType(CupertinoAlertDialog), findsNothing);
        }
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('copy uses the displayed code at a time boundary', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData')
          copied = (call.arguments as Map)['text'] as String;
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    var instant = DateTime.fromMillisecondsSinceEpoch(59000, isUtc: true);
    await tester.pumpWidget(
      CupertinoApp(home: AccountCard(fixture(), clock: () => instant)),
    );
    expect(find.text('287 082 '), findsOneWidget);
    instant = DateTime.fromMillisecondsSinceEpoch(60000, isUtc: true);
    await tester.tap(find.text('287 082 '));
    await tester.pump();
    expect(copied, '287082');
    expect(find.text('Copied 287082'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('359 152 '), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('HOTP controls remain laid out at large text size', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final account = fixture(digits: 8)
      ..type = AccountType.HOTP
      ..counter = 1;
    await tester.pumpWidget(
      CupertinoApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: AccountCard(account, accountKey: 'hotp'),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Next code'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  for (final throws in [false, true]) {
    testWidgets(
      'help fallback handles ${throws ? "PlatformException" : "false"}',
      (tester) async {
        const channel = MethodChannel('plugins.flutter.io/url_launcher');
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          (_) async {
            if (throws) throw PlatformException(code: 'launch_failed');
            return false;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            null,
          ),
        );
        await tester.pumpWidget(const CupertinoApp(home: Help()));
        await tester.tap(
          find.text('Do you want to setup Authenticator or get help?'),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.text('Unable to open external help address'),
          findsOneWidget,
        );
        expect(find.text('Copy URL'), findsOneWidget);
      },
    );
  }
}
