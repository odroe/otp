import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'entities/account.entity.dart';
import 'storage/account_store.dart';

late AccountRepository accounts;

class AccountRepository extends ChangeNotifier {
  final AccountStore store;
  AccountRepository(this.store);

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
