import 'package:flutter/cupertino.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  bool completed = false;

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    navigationBar: const CupertinoNavigationBar(middle: Text('Scan QR code')),
    child: SafeArea(
      child: MobileScanner(
        onDetect: (capture) {
          if (completed) return;
          for (final barcode in capture.barcodes) {
            final value = barcode.rawValue;
            if (value != null) {
              completed = true;
              Navigator.of(context).pop(value);
              break;
            }
          }
        },
      ),
    ),
  );
}
