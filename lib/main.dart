import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'repository.dart';
import 'storage/account_store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Startup());
}

class const Startup({super.key}) extends StatefulWidget {
  @override
  State<Startup> createState() => _StartupState();
}

class _StartupState extends State<Startup> {
  bool loading = true;
  bool ready = false;
  bool opening = false;

  @override
  void initState() {
    super.initState();
    openStorage();
  }

  Future<void> openStorage() async {
    if (opening) return;
    opening = true;
    setState(() => loading = true);
    try {
      // Hive.initFlutter historically used this same directory on iOS/Android.
      final directory = await getApplicationDocumentsDirectory();
      final store = await AccountStore.open(
        sqlitePath: '${directory.path}/accounts.sqlite3',
        legacyDirectory: directory.path,
      );
      if (!mounted) {
        store.close();
        return;
      }
      accounts = AccountRepository(store);
      if (mounted) setState(() => ready = true);
    } catch (_) {
      // Never render an empty vault or delete old data after an open/migration error.
      if (mounted) setState(() => ready = false);
    } finally {
      opening = false;
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ready) return Application();
    return CupertinoApp(
      home: CupertinoPageScaffold(
        navigationBar: const CupertinoNavigationBar(
          middle: Text('Authenticator'),
        ),
        child: SafeArea(
          child: Center(
            child: loading
                ? const CupertinoActivityIndicator()
                : Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Could not open your accounts. Your original data has not been removed. Do not uninstall the app.',
                        ),
                        CupertinoButton(
                          onPressed: openStorage,
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
