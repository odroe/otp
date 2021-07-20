import 'package:flutter/cupertino.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'entities/origin.entity.dart';

Future<void> initHive() async {
  // Register adapter.
  Hive.registerAdapter(OriginEntityAdapter());
  Hive.registerAdapter(OriginTypeAdapter());

  // Init and open box
  await Hive.initFlutter();
  await Hive.openBox<OriginEntity>(OriginEntity.entityName);
}

Future<void> main() async {
  await initHive();
  runApp(Application());
}
