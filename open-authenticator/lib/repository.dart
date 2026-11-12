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
