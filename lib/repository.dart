import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'entities/account.entity.dart';
import 'storage/account_store.dart';

late AccountRepository accounts;

class AccountRepository(final AccountStore store) extends ChangeNotifier {
  Iterable<MapEntry<String, AccountEntity>> get entries =>
      store.accounts.entries;
  Iterable<AccountEntity> get values => store.values;
  int get length => store.length;
  bool containsKey(String key) => store.containsKey(key);
  AccountEntity? get(String key) => store.get(key);

  /// Preserve migrated keys, matching identity by fields rather than delimiters.
  String keyFor(AccountEntity account) {
    for (final entry in entries) {
      if (entry.value.issuer == account.issuer &&
          entry.value.name == account.name) {
        return entry.key;
      }
    }
    final base = jsonEncode([account.issuer, account.name]);
    var key = base;
    var suffix = 1;
    // A legacy key is arbitrary text and may itself look like the new encoding.
    while (containsKey(key)) {
      key = '$base#${suffix++}';
    }
    return key;
  }

  Future<void> put(String key, AccountEntity account) async {
    store.put(key, account);
    notifyListeners();
  }

  Future<void> importNew(Iterable<AccountEntity> selected) async {
    final records = <String, AccountEntity>{};
    for (final account in selected) {
      final base = jsonEncode([account.issuer, account.name]);
      var key = base;
      var suffix = 1;
      while (containsKey(key) || records.containsKey(key)) {
        key = '$base#${suffix++}';
      }
      records[key] = account;
    }
    if (records.isEmpty) return;
    store.insertNewBatch(records);
    notifyListeners();
  }

  Future<void> updateLabels(
    String key,
    String issuer,
    String? name, {
    required AccountEntity expected,
  }) async {
    store.updateLabels(key, issuer, name, expected: expected);
    notifyListeners();
  }

  Future<void> reorder(List<String> keys) async {
    store.reorder(keys);
    notifyListeners();
  }

  final Set<String> _advancing = {};

  Future<void> advanceHotp(
    String key,
    int expectedCounter, {
    AccountEntity? expectedAccount,
  }) async {
    if (!_advancing.add(key)) throw StateError('Advancement already pending.');
    try {
      store.advanceHotp(key, expectedCounter, expectedAccount: expectedAccount);
      notifyListeners();
      await Future<void>.value();
    } finally {
      _advancing.remove(key);
    }
  }

  Future<void> delete(String key) async {
    store.delete(key);
    notifyListeners();
  }

  @override
  void dispose() {
    store.close();
    super.dispose();
  }
}
