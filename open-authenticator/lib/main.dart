import 'package:flutter/cupertino.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';

void main() async {
  await Hive.initFlutter();
  await Hive.openBox("Open Authenticator");
  runApp(Application());
}
