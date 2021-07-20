import 'package:hive/hive.dart';

part 'origin.entity.g.dart';

@HiveType(typeId: 0)
enum OriginType {
  @HiveField(0)
  HOTP,

  @HiveField(1)
  TOTP,
}

@HiveType(typeId: 1)
class OriginEntity {
  static String entityName = "OriginEntities";

  @HiveField(0, defaultValue: OriginType.TOTP)
  late OriginType type;

  @HiveField(1)
  late String issuer;

  @HiveField(2, defaultValue: null)
  late String account;

  @HiveField(3)
  late String secret;

  @HiveField(4, defaultValue: 6)
  late int digits;

  @HiveField(5, defaultValue: 30)
  late int period;
}
