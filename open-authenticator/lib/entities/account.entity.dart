import 'package:hive/hive.dart';

part 'account.entity.g.dart';

@HiveType(typeId: 0)
enum AccountType {
  @HiveField(0)
  HOTP,

  @HiveField(1)
  TOTP,
}

@HiveType(typeId: 1)
class AccountEntity {
  static String entityName = "accounts";

  @HiveField(0, defaultValue: AccountType.TOTP)
  late AccountType type;

  @HiveField(1)
  late String issuer;

  @HiveField(2, defaultValue: null)
  String? name;

  @HiveField(3)
  late String secret;

  @HiveField(4, defaultValue: 6)
  late int digits;

  @HiveField(5, defaultValue: 30)
  late int period;
}
