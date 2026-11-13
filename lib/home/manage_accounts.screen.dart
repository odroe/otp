import 'package:cupertino_ui/cupertino_ui.dart';

import '../entities/account.entity.dart';
import '../repository.dart';

class const ManageAccountsScreen({super.key}) extends StatefulWidget {
  @override
  State<ManageAccountsScreen> createState() => _ManageAccountsScreenState();
}

class _ManageAccountsScreenState() extends State<ManageAccountsScreen> {
  bool busy = false;
  String? error;

  Future<void> move(List<String> keys, int from, int to) async {
    if (busy || from == to || to < 0 || to >= keys.length) return;
    final next = [...keys];
    next.insert(to, next.removeAt(from));
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await accounts.reorder(next);
    } catch (_) {
      if (mounted)
        setState(
          () => error = 'Could not change the order. Reload and try again.',
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    navigationBar: const CupertinoNavigationBar(
      middle: Text('Manage accounts'),
    ),
    child: SafeArea(
      child: AnimatedBuilder(
        animation: accounts,
        builder: (context, _) {
          final entries = accounts.entries.toList();
          final keys = entries.map((e) => e.key).toList();
          return Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'All accounts. Drag or use the move buttons to change the order.',
                ),
              ),
              if (error != null) Text(error!),
              Expanded(
                child: ReorderableList(
                  itemCount: entries.length,
                  onReorderItem: (from, to) => move(keys, from, to),
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    final name = entry.value.name;
                    final label = [
                      entry.value.issuer,
                      if (name != null && name.isNotEmpty) name,
                    ].where((part) => part.isNotEmpty).join(', ');
                    final accessibleLabel =
                        '$label, account ${index + 1} of ${entries.length}';
                    return Container(
                      key: ValueKey(entry.key),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Expanded(child: Text(label)),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: busy || index == 0
                                ? null
                                : () => move(keys, index, index - 1),
                            child: Icon(
                              CupertinoIcons.arrow_up,
                              semanticLabel: 'Move $accessibleLabel up',
                            ),
                          ),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: busy || index == entries.length - 1
                                ? null
                                : () => move(keys, index, index + 1),
                            child: Icon(
                              CupertinoIcons.arrow_down,
                              semanticLabel: 'Move $accessibleLabel down',
                            ),
                          ),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: busy
                                ? null
                                : () => Navigator.of(context).push(
                                    CupertinoPageRoute<void>(
                                      builder: (_) => EditAccountLabelsScreen(
                                        entry.key,
                                        entry.value,
                                      ),
                                    ),
                                  ),
                            child: Icon(
                              CupertinoIcons.pencil,
                              semanticLabel: 'Edit $accessibleLabel',
                            ),
                          ),
                          ReorderableDragStartListener(
                            index: index,
                            enabled: !busy,
                            child: const Padding(
                              padding: EdgeInsets.all(12),
                              child: Icon(CupertinoIcons.line_horizontal_3),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class const EditAccountLabelsScreen(
  final String accountKey,
  final AccountEntity account, {
  super.key,
}) extends StatefulWidget {
  @override
  State<EditAccountLabelsScreen> createState() =>
      _EditAccountLabelsScreenState();
}

class _EditAccountLabelsScreenState() extends State<EditAccountLabelsScreen> {
  late final TextEditingController issuer = TextEditingController(
    text: widget.account.issuer,
  );
  late final TextEditingController name = TextEditingController(
    text: widget.account.name ?? '',
  );
  bool busy = false;
  String? error;

  @override
  void dispose() {
    issuer.dispose();
    name.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (busy) return;
    final service = issuer.text.trim();
    final account = name.text.trim();
    if ((service.isEmpty && account.isEmpty) ||
        service.length > 1024 ||
        account.length > 1024) {
      setState(() => error = 'Enter a label no longer than 1024 characters.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await accounts.updateLabels(
        widget.accountKey,
        service,
        account.isEmpty ? null : account,
        expected: widget.account,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted)
        setState(
          () => error = 'Could not save labels. The account may have changed.',
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    navigationBar: const CupertinoNavigationBar(middle: Text('Edit labels')),
    child: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Changing labels does not change the secret or verification settings.',
          ),
          CupertinoTextField(
            controller: issuer,
            enabled: !busy,
            placeholder: 'Service',
          ),
          CupertinoTextField(
            controller: name,
            enabled: !busy,
            placeholder: 'Account',
          ),
          if (error != null) Text(error!),
          CupertinoButton(
            onPressed: busy ? null : save,
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}
