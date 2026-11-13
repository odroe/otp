import 'package:sqlite3/sqlite3.dart';
import 'package:hotp/hotp.dart';

import '../entities/account.entity.dart';
import 'legacy_hive_reader.dart';

typedef LegacyAccountLoader = Future<Map<String, AccountEntity>> Function();

/// SQLite becomes authoritative only after the complete legacy import has been
/// committed and verified. Hive originals are retained, never renamed/deleted.
class AccountStore._(final Database _database) {
  static Future<AccountStore> open({
    required String sqlitePath,
    required String legacyDirectory,
    LegacyAccountLoader? legacyLoader,
  }) async {
    var database = sqlite3.open(sqlitePath);
    try {
      _configure(database);
      _createSchema(database);
      if (!_migrationComplete(database)) {
        // Failure here leaves SQLite unmarked and retryable, and Hive untouched.
        final records =
            await (legacyLoader ?? () => readLegacyAccounts(legacyDirectory))();
        database.execute('BEGIN IMMEDIATE');
        try {
          // Refuse unknown pre-existing data rather than overwrite it.
          final imported = database
              .select(
                "SELECT value FROM storage_metadata WHERE key = 'hive_import_v1'",
              )
              .any((row) => row['value'] == 'imported');
          if (!imported &&
              database
                      .select('SELECT COUNT(*) AS n FROM accounts')
                      .single['n'] !=
                  0) {
            throw StateError('Unmarked SQLite records require inspection.');
          }
          if (!imported) {
            for (final entry in records.entries) {
              _insert(database, entry.key, entry.value);
            }
          }
          _verifyRecords(database, records);
          database.execute(
            "INSERT INTO storage_metadata (key, value) VALUES ('hive_import_v1', 'imported') ON CONFLICT(key) DO UPDATE SET value = excluded.value",
          );
          database.execute('COMMIT');
        } catch (_) {
          database.execute('ROLLBACK');
          rethrow;
        }
        database.close();
        database = sqlite3.open(sqlitePath);
        _configure(database);
        _verifyRecords(database, records);
        _checkIntegrity(database);
        database.execute(
          "UPDATE storage_metadata SET value = 'complete' WHERE key = 'hive_import_v1' AND value = 'imported'",
        );
        if (!_migrationComplete(database)) {
          throw StateError('Migration verification marker was not persisted.');
        }
      }
      _checkIntegrity(database);
      return AccountStore._(database);
    } catch (_) {
      database.close();
      rethrow;
    }
  }

  static void _configure(Database database) {
    database.execute('PRAGMA busy_timeout = 5000');
    database.execute('PRAGMA synchronous = FULL');
  }

  static void _createSchema(Database database) {
    database.execute('''CREATE TABLE IF NOT EXISTS accounts (
      account_key TEXT PRIMARY KEY NOT NULL,
      account_type INTEGER NOT NULL,
      issuer TEXT NOT NULL,
      name TEXT,
      secret TEXT NOT NULL,
      digits INTEGER NOT NULL,
      period INTEGER NOT NULL
    )''');
    database.execute('BEGIN IMMEDIATE');
    try {
      final columns = database
          .select('PRAGMA table_info(accounts)')
          .map((row) => row['name'])
          .toSet();
      if (!columns.contains('algorithm')) {
        database.execute(
          "ALTER TABLE accounts ADD COLUMN algorithm TEXT NOT NULL DEFAULT 'sha1'",
        );
      }
      if (!columns.contains('counter')) {
        database.execute('ALTER TABLE accounts ADD COLUMN counter INTEGER');
      }
      if (!columns.contains('format')) {
        database.execute(
          "ALTER TABLE accounts ADD COLUMN format TEXT NOT NULL DEFAULT 'decimal'",
        );
      }
      database.execute('COMMIT');
    } catch (_) {
      database.execute('ROLLBACK');
      rethrow;
    }
    database.execute('''CREATE TABLE IF NOT EXISTS account_order (
      account_key TEXT PRIMARY KEY NOT NULL,
      position INTEGER NOT NULL
    )''');
    database.execute('''CREATE TABLE IF NOT EXISTS storage_metadata (
      key TEXT PRIMARY KEY NOT NULL,
      value TEXT NOT NULL
    )''');
  }

  static bool _migrationComplete(Database database) => database
      .select("SELECT value FROM storage_metadata WHERE key = 'hive_import_v1'")
      .any((row) => row['value'] == 'complete');

  static void _checkIntegrity(Database database) {
    final result = database.select('PRAGMA quick_check');
    if (result.length != 1 || result.single.values.single != 'ok') {
      throw StateError(
        'SQLite integrity check failed; storage was not opened.',
      );
    }
  }

  static void _insert(Database database, String key, AccountEntity account) {
    database.execute(
      '''INSERT INTO accounts
      (account_key, account_type, issuer, name, secret, digits, period, algorithm, counter, format)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        key,
        account.type.index,
        account.issuer,
        account.name,
        account.secret,
        account.digits,
        account.period,
        account.algorithm.name,
        account.counter,
        account.format.name,
      ],
    );
  }

  static AccountEntity _decode(Row row) => AccountEntity()
    ..type = AccountType.values[row['account_type'] as int]
    ..issuer = row['issuer'] as String
    ..name = row['name'] as String?
    ..secret = row['secret'] as String
    ..digits = row['digits'] as int
    ..period = row['period'] as int
    ..algorithm = Algorithm.values.byName(row['algorithm'] as String)
    ..counter = row['counter'] as int?
    ..format = OtpFormat.values.byName(row['format'] as String);

  static void _verifyRecords(
    Database database,
    Map<String, AccountEntity> expected,
  ) {
    final rows = database.select('SELECT * FROM accounts');
    if (rows.length != expected.length) {
      throw StateError('Migration count verification failed.');
    }
    for (final row in rows) {
      final value = expected[row['account_key']];
      if (value == null ||
          row['account_type'] != value.type.index ||
          row['issuer'] != value.issuer ||
          row['name'] != value.name ||
          row['secret'] != value.secret ||
          row['digits'] != value.digits ||
          row['period'] != value.period ||
          row['algorithm'] != value.algorithm.name ||
          row['counter'] != value.counter ||
          row['format'] != value.format.name) {
        throw StateError('Migration record verification failed.');
      }
    }
  }

  Map<String, AccountEntity> get accounts => {
    for (final row in _database.select(
      'SELECT accounts.* FROM accounts LEFT JOIN account_order USING(account_key) ORDER BY account_order.position IS NULL, account_order.position, accounts.rowid',
    ))
      row['account_key'] as String: _decode(row),
  };

  Iterable<AccountEntity> get values => accounts.values;

  Iterable<String> get keys => accounts.keys;

  int get length =>
      _database.select('SELECT COUNT(*) AS n FROM accounts').single['n'] as int;

  AccountEntity? get(String key) {
    final rows = _database.select(
      'SELECT * FROM accounts WHERE account_key = ?',
      [key],
    );
    return rows.isEmpty ? null : _decode(rows.single);
  }

  bool containsKey(String key) => get(key) != null;

  /// Inserts a complete batch or leaves every existing account unchanged.
  void insertNewBatch(Map<String, AccountEntity> records) {
    _database.execute('BEGIN IMMEDIATE');
    try {
      for (final entry in records.entries) {
        final account = entry.value;
        if (_database.select(
          'SELECT 1 FROM accounts WHERE issuer = ? AND name IS ? LIMIT 1',
          [account.issuer, account.name],
        ).isNotEmpty) {
          throw StateError('An account already exists.');
        }
        _insert(_database, entry.key, account);
      }
      _database.execute('COMMIT');
    } catch (_) {
      _database.execute('ROLLBACK');
      rethrow;
    }
  }

  void put(String key, AccountEntity value) {
    _database.execute(
      '''INSERT INTO accounts
      (account_key, account_type, issuer, name, secret, digits, period, algorithm, counter, format)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(account_key) DO UPDATE SET
      account_type=excluded.account_type, issuer=excluded.issuer,
      name=excluded.name, secret=excluded.secret, digits=excluded.digits,
      period=excluded.period, algorithm=excluded.algorithm, counter=excluded.counter, format=excluded.format''',
      [
        key,
        value.type.index,
        value.issuer,
        value.name,
        value.secret,
        value.digits,
        value.period,
        value.algorithm.name,
        value.counter,
        value.format.name,
      ],
    );
  }

  /// Changes only labels, keeping the stable identity and OTP state intact.
  void updateLabels(
    String key,
    String issuer,
    String? name, {
    required AccountEntity expected,
  }) {
    if (issuer.length > 1024 ||
        (name?.length ?? 0) > 1024 ||
        (issuer.isEmpty && (name?.isEmpty ?? true))) {
      throw const FormatException('Invalid account label.');
    }
    // A concurrent HOTP advance is safe, but do not edit a replacement account.
    _database.execute(
      'UPDATE accounts SET issuer = ?, name = ? WHERE account_key = ? '
      'AND issuer = ? AND name IS ? AND account_type = ? AND secret = ? '
      'AND algorithm = ? AND digits = ? AND period = ? AND format = ?',
      [
        issuer,
        name == '' ? null : name,
        key,
        expected.issuer,
        expected.name,
        expected.type.index,
        expected.secret,
        expected.algorithm.name,
        expected.digits,
        expected.period,
        expected.format.name,
      ],
    );
    if (_database.updatedRows != 1) {
      throw StateError('Account changed; reload before editing.');
    }
  }

  /// Applies a complete order atomically; stale or duplicate identities fail.
  void reorder(List<String> keys) {
    _database.execute('BEGIN IMMEDIATE');
    try {
      final current = _database
          .select('SELECT account_key FROM accounts')
          .map((row) => row['account_key'] as String)
          .toSet();
      if (keys.length != current.length ||
          keys.toSet().length != keys.length ||
          !current.containsAll(keys)) {
        throw StateError('Account list changed; reload before reordering.');
      }
      _database.execute('DELETE FROM account_order');
      for (var i = 0; i < keys.length; i++) {
        _database.execute(
          'INSERT INTO account_order (account_key, position) VALUES (?, ?)',
          [keys[i], i],
        );
      }
      _database.execute('COMMIT');
    } catch (_) {
      _database.execute('ROLLBACK');
      rethrow;
    }
  }

  /// Atomically advances only the counter the caller actually observed.
  void advanceHotp(
    String key,
    int expectedCounter, {
    AccountEntity? expectedAccount,
  }) {
    if (expectedCounter < 0 || expectedCounter >= Hotp.maxCounter) {
      throw StateError('Counter cannot be advanced.');
    }
    _database.execute(
      'UPDATE accounts SET counter = counter + 1 WHERE account_key = ? '
      'AND account_type = ? AND counter = ?'
      '${expectedAccount == null ? '' : ' AND issuer = ? AND name IS ? AND secret = ? AND algorithm = ? AND digits = ? AND period = ? AND format = ?'}',
      [
        key,
        AccountType.HOTP.index,
        expectedCounter,
        if (expectedAccount != null) ...[
          expectedAccount.issuer,
          expectedAccount.name,
          expectedAccount.secret,
          expectedAccount.algorithm.name,
          expectedAccount.digits,
          expectedAccount.period,
          expectedAccount.format.name,
        ],
      ],
    );
    if (_database.updatedRows != 1) {
      throw StateError('Account changed; reload before advancing.');
    }
  }

  void delete(String key) {
    _database.execute('BEGIN IMMEDIATE');
    try {
      _database.execute('DELETE FROM account_order WHERE account_key = ?', [
        key,
      ]);
      _database.execute('DELETE FROM accounts WHERE account_key = ?', [key]);
      _database.execute('COMMIT');
    } catch (_) {
      _database.execute('ROLLBACK');
      rethrow;
    }
  }

  void close() => _database.close();
}
