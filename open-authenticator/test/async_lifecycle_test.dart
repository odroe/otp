import 'dart:async';

import 'package:authenticator/entities/account.entity.dart';
import 'package:authenticator/home/scan.screen.dart';
import 'package:authenticator/home/widgets/account.card.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class FakeScanner extends MobileScannerPlatform {
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

const capture = BarcodeCapture(
  barcodes: [Barcode(format: BarcodeFormat.qrCode, rawValue: 'public test QR')],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final scenario in ['popped', 'covered', 'blocked']) {
    testWidgets('scanner ignores inactive capture: $scenario', (tester) async {
      final oldPlatform = MobileScannerPlatform.instance;
      MobileScannerPlatform.instance = FakeScanner();
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        CupertinoApp(navigatorKey: nav, home: const Text('root page')),
      );
      nav.currentState!.push(
        CupertinoPageRoute<void>(
          builder: (_) =>
              const CupertinoPageScaffold(child: Text('underlying page')),
        ),
      );
      await tester.pumpAndSettle();
      nav.currentState!.push(
        CupertinoPageRoute<String>(builder: (_) => const ScanScreen()),
      );
      await tester.pumpAndSettle();
      final detect = tester
          .widget<MobileScanner>(find.byType(MobileScanner))
          .onDetect!;
      if (scenario == 'popped') {
        nav.currentState!.pop();
        // Late camera event during the outgoing route transition.
        detect(capture);
        await tester.pumpAndSettle();
        expect(find.text('underlying page'), findsOneWidget);
        // Callback retained after disposal must also be harmless.
        detect(capture);
      } else if (scenario == 'covered') {
        nav.currentState!.push(
          CupertinoPageRoute<void>(builder: (_) => const Text('cover page')),
        );
        await tester.pumpAndSettle();
        detect(capture);
        await tester.pumpAndSettle();
        expect(find.text('cover page'), findsOneWidget);
      } else {
        final popScope = tester.widget<PopScope<String>>(
          find.byType(PopScope<String>),
        );
        // A vetoed pop notification must not permanently disable scanning.
        popScope.onPopInvokedWithResult!(false, null);
        detect(capture);
        await tester.pumpAndSettle();
        expect(find.text('underlying page'), findsOneWidget);
        expect(find.byType(ScanScreen), findsNothing);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      MobileScannerPlatform.instance = oldPlatform;
    });
  }

  {
    for (final unmount in [false, true]) {
      testWidgets('clipboard failure unmount=$unmount', (tester) async {
        final pending = Completer<void>();
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              await pending.future;
              throw PlatformException(
                code: 'denied',
                message: 'private diagnostic',
              );
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
        final account = AccountEntity()
          ..type = AccountType.TOTP
          ..issuer = 'Fixture'
          ..name = 'user'
          ..secret = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ'
          ..digits = 6
          ..period = 30;
        await tester.pumpWidget(CupertinoApp(home: AccountCard(account)));
        await tester.tap(find.textContaining(RegExp(r'^\d{3} \d{3}')));
        await tester.pump();
        if (unmount) await tester.pumpWidget(const SizedBox());
        pending.complete();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Copied'), findsNothing);
        if (!unmount) {
          expect(
            find.text('Unable to copy the code. Please try again.'),
            findsOneWidget,
          );
          final dialog = find.byType(CupertinoAlertDialog);
          expect(
            find.descendant(
              of: dialog,
              matching: find.textContaining(RegExp(r'\d{6}')),
            ),
            findsNothing,
          );
          expect(find.textContaining('private diagnostic'), findsNothing);
          expect(find.textContaining(account.secret), findsNothing);
        }
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
