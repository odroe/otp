import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Ignore other barcode types even when a capture also contains a QR code.
String? qrCodeValue(BarcodeCapture capture) {
  for (final barcode in capture.barcodes) {
    if (barcode.format == .qrCode && barcode.rawValue != null) {
      return barcode.rawValue;
    }
  }
  return null;
}

class const ScanScreen({super.key}) extends StatefulWidget {
  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState() extends State<ScanScreen> {
  bool completed = false;

  @override
  Widget build(BuildContext context) => PopScope<String>(
    onPopInvokedWithResult: (didPop, result) {
      if (didPop) completed = true;
    },
    child: CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Scan QR code')),
      child: SafeArea(
        child: MobileScanner(
          onDetect: (capture) {
            if (!mounted ||
                completed ||
                ModalRoute.of(context)?.isCurrent != true)
              return;
            final value = qrCodeValue(capture);
            if (value == null) return;
            completed = true;
            Navigator.of(context).pop(value);
          },
        ),
      ),
    ),
  );
}
