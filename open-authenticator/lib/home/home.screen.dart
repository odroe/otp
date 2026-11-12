import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import 'scan.screen.dart';

import '../entities/account.entity.dart';
import '../entities/parse_account.dart';
import '../repository.dart';
import 'widgets/account.card.dart';
import 'widgets/help.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// search key.
  String keywords = "";
  bool scanning = false;

  void onChangedKeywords(String keywords) {
    setState(() {
      this.keywords = keywords;
    });
  }

  Iterable<MapEntry<String, AccountEntity>> searchAccounts() =>
      accounts.entries.where((entry) {
        final element = entry.value;
        if (keywords.isEmpty) return true;
        return element.issuer.toLowerCase().contains(keywords.toLowerCase()) ||
            (element.name ?? '').toLowerCase().contains(keywords.toLowerCase());
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
    if (scanning) return;
    setState(() => scanning = true);
    try {
      final response = await Navigator.of(
        context,
      ).push<String>(CupertinoPageRoute(builder: (_) => const ScanScreen()));
      if (!mounted || response == null) return;

      final account = parseAccount(response);

      final key = "${account.issuer}:${account.name}";
      if (accounts.containsKey(key)) {
        return await showCupertinoDialog(
          context: context,
          builder: (context) {
            return CupertinoAlertDialog(
              title: Text('Warn'),
              content: Text(
                'The account already exists, it will be overwritten if it continues.',
              ),
              actions: [
                CupertinoDialogAction(
                  child: Text('Cancel'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                CupertinoDialogAction(
                  child: Text('Update'),
                  onPressed: () async {
                    try {
                      await accounts.put(key, account);
                      if (mounted) Navigator.of(context).pop();
                    } catch (_) {
                      if (mounted)
                        showAlert(
                          'Could not save the account. Please try again.',
                        );
                    }
                  },
                ),
              ],
            );
          },
        );
      }

      await accounts.put(key, account);
    } on FormatException {
      if (mounted) showAlert('Invalid or unsupported authentication QR code');
    } on PlatformException {
      if (mounted) showAlert('Failed to start the QR code scanner');
    } catch (_) {
      if (mounted) showAlert('Could not save the account. Please try again.');
    } finally {
      if (mounted) setState(() => scanning = false);
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
            CupertinoSliverNavigationBar.search(
              automaticallyImplyTitle: true,
              automaticallyImplyLeading: true,
              alwaysShowMiddle: false,
              backgroundColor: CupertinoTheme.of(
                context,
              ).scaffoldBackgroundColor,
              middle: Text("Authenticator"),
              trailing: CupertinoButton(
                padding: EdgeInsets.zero,
                child: Icon(CupertinoIcons.add),
                onPressed: scanning ? null : scanQR,
              ),
              // _kNavBarEdgePadding
              padding: EdgeInsetsDirectional.only(start: 16.0, end: 16.0),
              largeTitle: const Text('Authenticator'),
              searchField: Padding(
                // See _kNavBarEdgePadding
                padding: EdgeInsets.only(right: 16.0),
                child: CupertinoSearchTextField(onChanged: onChangedKeywords),
              ),
            ),
            SliverPadding(padding: EdgeInsets.only(top: 12.0)),
            SliverToBoxAdapter(
              child: AnimatedBuilder(
                animation: accounts,
                builder: (BuildContext context, _widget) {
                  final matches = searchAccounts().toList();
                  return ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: matches.length,
                    itemBuilder: (BuildContext context, int index) {
                      final entry = matches[index];
                      return AccountCard(
                        entry.value,
                        accountKey: entry.key,
                        key: ValueKey(entry.key),
                      );
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
