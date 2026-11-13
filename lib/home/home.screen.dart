import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/services.dart';

import 'scan.screen.dart';
import 'manage_accounts.screen.dart';
import 'manual_account.screen.dart';
import 'google_import.screen.dart';
import '../import/google_migration.dart';

import '../entities/account.entity.dart';
import '../entities/parse_account.dart';
import '../repository.dart';
import 'widgets/account.card.dart';
import 'widgets/help.dart';

class const HomeScreen({super.key}) extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState() extends State<HomeScreen> {
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

  Future<void> chooseAdd() async {
    final choice = await showCupertinoModalPopup<String>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Add account'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, 'scan'),
            child: const Text('Scan QR code'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, 'manual'),
            child: const Text('Enter manually'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (!mounted) return;
    if (choice == 'scan') {
      await scanQR();
    } else if (choice == 'manual') {
      final account = await Navigator.of(context).push<AccountEntity>(
        CupertinoPageRoute(builder: (_) => const ManualAccountScreen()),
      );
      if (mounted && account != null) await reviewAndSave(account);
    }
  }

  Future<void> reviewAndSave(
    AccountEntity account, {
    String? labelIssuer,
  }) async {
    final mismatch = labelIssuer != null && labelIssuer != account.issuer;
    final accepted = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Review account'),
        content: Text(
          [
            'Service: ${account.issuer}',
            if (account.name != null) 'Account: ${account.name}',
            'Type: ${account.format == .steam ? 'Steam Guard' : account.type.name}',
            'Algorithm: ${account.algorithm.name.toUpperCase()}',
            if (account.format == .steam)
              'Output: 5 Steam characters'
            else
              'Digits: ${account.digits}',
            if (account.type == .TOTP)
              'Period: ${account.period} seconds'
            else
              'Counter: ${account.counter}',
            if (account.type == .HOTP && account.algorithm.name != 'sha1') 'SHA-256 and SHA-512 HOTP are extensions; check service compatibility.',
            if (mismatch)
              'The QR label service ($labelIssuer) differs from its issuer parameter.',
          ].join('\n'),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (!mounted || accepted != true) return;
    final String key;
    try {
      key = accounts.keyFor(account);
    } on StateError {
      if (mounted) {
        showAlert(
          'Multiple accounts have these labels. Edit their labels to distinguish them before replacing an account.',
        );
      }
      return;
    }
    final existing = accounts.get(key);
    if (existing != null) {
      final replace = await showCupertinoDialog<bool>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Account already exists'),
          content: const Text('Replace the existing account?'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Replace'),
            ),
          ],
        ),
      );
      if (!mounted || replace != true) return;
    }
    try {
      if (existing == null) {
        await accounts.addNew(key, account);
      } else {
        await accounts.replaceIfUnchanged(key, existing, account);
      }
    } catch (_) {
      if (mounted) showAlert('Could not save the account. Please try again.');
    }
  }

  Future<void> scanQR() async {
    if (scanning) return;
    setState(() => scanning = true);
    try {
      final response = await Navigator.of(context)
          .push<String>(CupertinoPageRoute(builder: (_) => const ScanScreen()));
      if (!mounted || response == null) return;
      if (response.startsWith('otpauth-migration:')) {
        final fragment = parseGoogleMigration(response);
        if (mounted)
          await Navigator.of(context).push(
            CupertinoPageRoute<void>(
              builder: (_) => GoogleImportScreen(fragment),
            ),
          );
        return;
      }
      final provisioning = parseProvisioning(response);
      await reviewAndSave(
        provisioning.account,
        labelIssuer: provisioning.labelIssuer,
      );
    } on FormatException catch (error) {
      if (mounted) showAlert(error.message);
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
              automaticallyImplyLeading: false,
              leading: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.of(context).push(
                  CupertinoPageRoute<void>(
                    builder: (_) => const ManageAccountsScreen(),
                  ),
                ),
                child: const Icon(
                  CupertinoIcons.slider_horizontal_3,
                  semanticLabel: 'Manage accounts',
                ),
              ),
              alwaysShowMiddle: false,
              backgroundColor: CupertinoTheme.of(context)
                  .scaffoldBackgroundColor,
              middle: Text("Authenticator"),
              trailing: CupertinoButton(
                padding: EdgeInsets.zero,
                child: Icon(CupertinoIcons.add, semanticLabel: 'Add account'),
                onPressed: scanning ? null : chooseAdd,
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
                    physics: const NeverScrollableScrollPhysics(),
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
