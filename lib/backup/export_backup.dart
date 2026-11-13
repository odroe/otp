import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../entities/account.entity.dart';
import 'offline_backup.dart';

typedef BackupSaver = Future<bool> Function(Uint8List data, String filename);

/// Produces and verifies a detached snapshot before opening the system saver.
class BackupExporter(final BackupSaver save) {
  Future<bool> export(List<BackupEntry> snapshot, {String? password}) async {
    final bytes = await OfflineBackup.encode(snapshot, password: password);
    try {
      final restored = await OfflineBackup.decode(bytes, password: password);
      if (!_sameSnapshot(snapshot, restored)) {
        throw StateError('Backup verification failed.');
      }
      return await save(bytes, 'authenticator-backup.oab');
    } finally {
      bytes.fillRange(0, bytes.length, 0);
    }
  }
}

Future<bool> saveBackupWithSystem(Uint8List bytes, String filename) async {
  return await FilePicker.saveFile(fileName: filename, bytes: bytes) != null;
}

bool _sameSnapshot(List<BackupEntry> a, List<BackupEntry> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    final x = a[i].account, y = b[i].account;
    if (a[i].id != b[i].id || !_sameAccount(x, y)) return false;
  }
  return true;
}

bool _sameAccount(AccountEntity a, AccountEntity b) =>
    a.issuer == b.issuer &&
    a.name == b.name &&
    a.secret == b.secret &&
    a.type == b.type &&
    a.algorithm == b.algorithm &&
    a.digits == b.digits &&
    a.period == b.period &&
    a.counter == b.counter &&
    a.format == b.format;
