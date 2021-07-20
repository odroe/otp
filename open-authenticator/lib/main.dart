import 'package:flutter/cupertino.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'entities/account.entity.dart';

Future<void> initHive() async {
  // Register adapter.
  Hive.registerAdapter(AccountEntityAdapter());
  Hive.registerAdapter(AccountTypeAdapter());

  // Init and open box
  await Hive.initFlutter();
  await Hive.openBox<AccountEntity>(AccountEntity.entityName);
}

Future<void> main() async {
  await initHive();
  runApp(Application());
}
