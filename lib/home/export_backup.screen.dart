import 'dart:convert';

import 'package:cupertino_ui/cupertino_ui.dart';

import '../backup/export_backup.dart';
import '../backup/offline_backup.dart';
import '../repository.dart';

typedef BackupExportAction = Future<bool> Function(
  List<BackupEntry> snapshot,
  String? password,
);

class const ExportBackupScreen({
  super.key,
  final BackupExportAction? exportAction,
}) extends StatefulWidget {
  @override
  State<ExportBackupScreen> createState() => _ExportBackupScreenState();
}

class _ExportBackupScreenState() extends State<ExportBackupScreen> {
  final password = TextEditingController();
  final confirmation = TextEditingController();
  bool protected = true;
  bool busy = false;
  String? message;

  @override
  void dispose() {
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  Future<void> export() async {
    if (busy) return;
    if (protected &&
        (password.text.isEmpty || password.text != confirmation.text)) {
      setState(
        () => message = 'Enter and confirm the same nonempty backup password.',
      );
      return;
    }
    if (protected && utf8.encode(password.text).length > 1024) {
      setState(() => message = 'Backup password is too long.');
      return;
    }
    if (!protected) {
      final confirmed = await showCupertinoDialog<bool>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Export without a password?'),
          content: const Text(
            'Anyone with this file can read your account secrets and generate codes. Its checksum cannot detect intentional changes.',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Export plaintext'),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) return;
    }
    setState(() {
      busy = true;
      message = null;
    });
    try {
      // SQLite returns a detached, consistent snapshot before asynchronous work.
      final snapshot = [
        for (final entry in accounts.entries)
          BackupEntry(entry.key, entry.value),
      ];
      final saved = await (widget.exportAction ?? _exportSnapshot)(
        snapshot,
        protected ? password.text : null,
      );
      if (mounted) {
        if (saved) {
          password.clear();
          confirmation.clear();
        }
        setState(
          () => message = saved
              ? 'Backup saved to the selected location. Keep it safe.'
              : 'Save cancelled.',
        );
      }
    } catch (_) {
      if (mounted)
        setState(
          () => message = 'Could not complete the export. If a file was created, check the destination.',
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<bool> _exportSnapshot(List<BackupEntry> snapshot, String? password) =>
      BackupExporter((bytes, filename) async {
        if (!mounted) return false;
        return saveBackupWithSystem(bytes, filename);
      }).export(snapshot, password: password);

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    navigationBar: const CupertinoNavigationBar(middle: Text('Export backup')),
    child: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Choose a backup mode, then choose where to save the file.',
          ),
          Text(
            accounts.length == 0
                ? 'There are no accounts; this backup will be empty.'
                : '${accounts.length} accounts will be included.',
          ),
          CupertinoSlidingSegmentedControl<bool>(
            groupValue: protected,
            children: const {true: Text('Password'), false: Text('Plaintext')},
            onValueChanged: (value) {
              if (!busy) {
                if (value != null)
                  setState(() {
                    protected = value;
                    message = null;
                  });
              }
            },
          ),
          if (protected) ...[
            const Text(
              'Recommended. You must remember this backup password to restore the file. It is separate from app unlock.',
            ),
            CupertinoTextField(
              controller: password,
              enabled: !busy,
              placeholder: 'Backup password',
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
            ),
            CupertinoTextField(
              controller: confirmation,
              enabled: !busy,
              placeholder: 'Confirm backup password',
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
            ),
          ] else
            const Text(
              'Without a password, anyone with the file can read account secrets and generate codes.',
            ),
          CupertinoButton.filled(
            onPressed: busy ? null : export,
            child: const Text('Choose destination'),
          ),
          if (busy) const CupertinoActivityIndicator(),
          if (message != null) Text(message!),
        ],
      ),
    ),
  );
}
