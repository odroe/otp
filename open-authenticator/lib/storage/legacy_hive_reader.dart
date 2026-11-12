import 'dart:io';
import 'dart:isolate';

import 'package:hive/hive.dart';

import '../entities/account.entity.dart';

/// Reads only disposable copies. Never opens the original box through Hive,
/// whose startup recovery/compaction housekeeping can otherwise alter it.
Future<Map<String, AccountEntity>> readLegacyAccounts(String directory) async {
  final originals = <File>[];
  for (final extension in ['hive', 'hivec']) {
    final file = File('$directory/accounts.$extension');
    if (await file.exists()) originals.add(file);
  }
  if (originals.isEmpty) {
    if (await File('$directory/accounts.lock').exists()) {
      throw StateError(
        'Legacy storage is incomplete; migration was not started.',
      );
    }
    return {};
  }

  // Keep decode copies out of Documents backups. If the process is killed,
  // a temporary copy can remain until the operating system cleans it up.
  final staging = await Directory.systemTemp.createTemp('auth-hive-read-');
  try {
    for (final file in originals) {
      final bytes = await file.readAsBytes();
      final extension = file.path.endsWith('.hivec') ? 'hivec' : 'hive';
      await File(
        '${staging.path}/accounts.$extension',
      ).writeAsBytes(bytes, flush: true);
      final afterCopy = await file.readAsBytes();
      if (!_sameBytes(bytes, afterCopy)) {
        throw StateError(
          'Legacy storage changed while being copied. Retry safely.',
        );
      }
    }
    return await Isolate.run(() => _readCopy(staging.path));
  } finally {
    // Only our disposable copy is removed. Original .hive/.hivec remain intact.
    await staging.delete(recursive: true);
  }
}

bool _sameBytes(List<int> first, List<int> second) {
  if (first.length != second.length) return false;
  for (var i = 0; i < first.length; i++) {
    if (first[i] != second[i]) return false;
  }
  return true;
}

Future<Map<String, AccountEntity>> _readCopy(String directory) async {
  Hive.init(directory);
  Hive.registerAdapter(AccountTypeAdapter());
  Hive.registerAdapter(AccountEntityAdapter());
  try {
    final box = await Hive.openBox<AccountEntity>(
      'accounts',
      crashRecovery: false,
    );
    final result = <String, AccountEntity>{};
    for (final key in box.keys) {
      if (key is! String) {
        throw StateError(
          'Unexpected legacy key type; no records were migrated.',
        );
      }
      final value = box.get(key);
      if (value == null) {
        throw StateError('Unreadable legacy record; no records were migrated.');
      }
      result[key] = value;
    }
    return result;
  } finally {
    await Hive.close();
  }
}
