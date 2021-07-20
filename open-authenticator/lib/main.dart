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

  // final account = AccountEntity();
  // account.digits = 6;
  // account.secret = 'MU2TSNRZG5TGKMBYGAZDCMJTMM3GIMJVMZRTINDFGI3WGZRVMQ4Q';
  // account.period = 30;
  // account.type = AccountType.TOTP;
  // account.issuer = "GitHub";
  // account.name = "medz";
  // // account.
  // print(box.length);
  // // box.add(account);
}

Future<void> main() async {
  await initHive();
  runApp(Application());
}
