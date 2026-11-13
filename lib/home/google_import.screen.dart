import 'dart:convert';

import 'package:cupertino_ui/cupertino_ui.dart';

import '../entities/account.entity.dart';
import '../import/google_migration.dart';
import '../repository.dart';
import 'scan.screen.dart';

class const GoogleImportScreen(final MigrationFragment initial, {super.key})
    extends StatefulWidget {
  @override
  State<GoogleImportScreen> createState() => _GoogleImportScreenState();
}

class _GoogleImportScreenState() extends State<GoogleImportScreen> {
  final batch = MigrationBatch();
  final selected = <int>{};
  String? error;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    batch.add(widget.initial);
    if (batch.complete) initializeSelection();
  }

  @override
  void dispose() {
    batch.clear();
    selected.clear();
    super.dispose();
  }

  String identity(AccountEntity account) =>
      jsonEncode([account.issuer, account.name]);
  bool exists(AccountEntity account) => accounts.entries.any(
    (entry) =>
        entry.value.issuer == account.issuer &&
        entry.value.name == account.name,
  );

  void initializeSelection() {
    final values = batch.accounts;
    final counts = <String, int>{};
    for (final value in values) {
      final id = identity(value);
      counts[id] = (counts[id] ?? 0) + 1;
    }
    for (var i = 0; i < values.length; i++) {
      if (!exists(values[i]) && counts[identity(values[i])] == 1)
        selected.add(i);
    }
  }

  Future<void> scanNext() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await Navigator.of(context)
          .push<String>(CupertinoPageRoute(builder: (_) => const ScanScreen()));
      if (!mounted || result == null) return;
      final added = batch.add(parseGoogleMigration(result));
      if (batch.complete) initializeSelection();
      setState(
        () => error = added ? null : 'This QR code has already been scanned.',
      );
    } on FormatException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) setState(() => error = 'Could not scan this QR code.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    if (busy || selected.isEmpty || !batch.complete) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final values = batch.accounts;
      await accounts.importNew([for (final index in selected) values[index]]);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted)
        setState(
          () => error =
              'Could not import accounts. Existing accounts were not changed.',
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final values = batch.complete ? batch.accounts : <AccountEntity>[];
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Import from Google'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!batch.complete) ...[
              Text('Scanned ${batch.received} of ${batch.expected} QR codes.'),
              const Text(
                'Scan all codes from the same export before importing.',
              ),
              CupertinoButton.filled(
                onPressed: busy ? null : scanNext,
                child: const Text('Scan next QR code'),
              ),
            ] else ...[
              const Text(
                'Choose accounts to import. Existing accounts cannot be replaced here.',
              ),
              for (var index = 0; index < values.length; index++)
                Builder(
                  builder: (context) {
                    final account = values[index];
                    final alreadyExists = exists(account);
                    final otherSelected = selected.any(
                      (other) =>
                          other != index &&
                          identity(values[other]) == identity(account),
                    );
                    return Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: .start,
                            children: [
                              Text(
                                account.issuer.isEmpty
                                    ? (account.name ?? '')
                                    : account.issuer,
                              ),
                              if (account.issuer.isNotEmpty &&
                                  account.name != null)
                                Text(account.name!),
                              Text(
                                '${account.type.name} · ${account.algorithm.name.toUpperCase()} · ${account.digits} digits',
                              ),
                              if (alreadyExists)
                                const Text('Already exists; skipped.'),
                              if (!alreadyExists && otherSelected)
                                const Text(
                                  'Another matching account is selected.',
                                ),
                            ],
                          ),
                        ),
                        CupertinoSwitch(
                          value: selected.contains(index),
                          onChanged: alreadyExists || otherSelected || busy
                              ? null
                              : (value) {
                                  setState(() {
                                    if (value) {
                                      selected.add(index);
                                    } else {
                                      selected.remove(index);
                                    }
                                  });
                                },
                        ),
                      ],
                    );
                  },
                ),
              CupertinoButton.filled(
                onPressed: busy || selected.isEmpty ? null : save,
                child: Text('Import ${selected.length} accounts'),
              ),
            ],
            if (error != null)
              Text(
                error!,
                style: const TextStyle(color: CupertinoColors.systemRed),
              ),
          ],
        ),
      ),
    );
  }
}
