import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../entities/account.entity.dart';
import 'widgets/account.card.dart';
import 'widgets/help.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// Accounts hive box.
  final Box<AccountEntity> accountsBox = Hive.box(AccountEntity.entityName);

  /// search key.
  String keywords = "";

  void onChangedKeywords(String keywords) {
    setState(() {
      this.keywords = keywords;
    });
  }

  Iterable<AccountEntity> searchInBox(Box<AccountEntity> box) =>
      box.values.where((element) {
        if (keywords.isEmpty) return true;
        // return false;
        return element.issuer.toLowerCase().contains(keywords.toLowerCase()) ||
            element.name!.toLowerCase().contains(keywords.toLowerCase());
      });

  void showAlert(String content) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        content: Text(content),
        actions: [
          CupertinoDialogAction(
            child: Text('OK'),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Future<void> scanQR() async {
    try {
      String response = await FlutterBarcodeScanner.scanBarcode(
        '#00a152',
        'Cancel',
        true,
        ScanMode.QR,
      );
      if (response == '-1') {
        return;
      }

      final Uri result = Uri.parse(response);
      final account = new AccountEntity()
        ..type = AccountType.TOTP
        ..name = result.path.split(':').length == 2
            ? result.path.split(':')[1]
            : result.path
        ..issuer = (result.queryParameters['issuer'] != null
            ? result.queryParameters['issuer']
            : result.path.split(':').length == 2
                ? result.path.split(':')[0]
                : result.path)!
        ..digits = result.queryParameters['digits'] != null
            ? int.parse(result.queryParameters['digits'] as String)
            : 6
        ..period = result.queryParameters['period'] == null
            ? 30
            : int.parse(result.queryParameters['period'] as String)
        ..secret = result.queryParameters['secret'] as String;
      if (result.path.split(':').length < 2 &&
          result.queryParameters['issuer'] != null &&
          account.name == account.issuer) {
        account.name = null;
      }

      if (account.secret.isEmpty) {
        showAlert('Incorrect QR code');
      }

      this.accountsBox.add(account);
      showAlert('Success');
    } on PlatformException {
      showAlert('Failed to start the QR code scanner');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: CupertinoPageScaffold(
        child: CustomScrollView(
          slivers: [
            CupertinoSliverNavigationBar(
              automaticallyImplyTitle: true,
              automaticallyImplyLeading: true,
              backgroundColor:
                  CupertinoTheme.of(context).scaffoldBackgroundColor,
              middle: Text("Authenticator"),
              trailing: CupertinoButton(
                padding: EdgeInsets.zero,
                child: Icon(CupertinoIcons.add),
                onPressed: scanQR,
              ),
              // _kNavBarEdgePadding
              padding: EdgeInsetsDirectional.only(
                start: 16.0,
                end: 16.0,
              ),
              largeTitle: Padding(
                // See _kNavBarEdgePadding
                padding: EdgeInsets.only(right: 16.0),
                child: CupertinoSearchTextField(
                  onChanged: onChangedKeywords,
                ),
              ),
            ),
            SliverPadding(padding: EdgeInsets.only(top: 12.0)),
            SliverToBoxAdapter(
              child: ValueListenableBuilder(
                valueListenable: accountsBox.listenable(),
                builder:
                    (BuildContext context, Box<AccountEntity> box, _widget) {
                  final accounts = searchInBox(box);
                  return ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: accounts.length,
                    itemBuilder: (BuildContext context, int index) {
                      return AccountCard(accounts.elementAt(index));
                    },
                  );
                },
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.symmetric(vertical: 12.0),
              sliver: SliverToBoxAdapter(child: Help()),
            ),
          ],
        ),
      ),
    );
  }
}
