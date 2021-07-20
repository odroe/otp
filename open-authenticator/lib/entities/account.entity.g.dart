// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account.entity.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AccountTypeAdapter extends TypeAdapter<AccountType> {
  @override
  final int typeId = 0;

  @override
  AccountType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return AccountType.HOTP;
      case 1:
        return AccountType.TOTP;
      default:
        return AccountType.HOTP;
    }
  }

  @override
  void write(BinaryWriter writer, AccountType obj) {
    switch (obj) {
      case AccountType.HOTP:
        writer.writeByte(0);
        break;
      case AccountType.TOTP:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccountTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AccountEntityAdapter extends TypeAdapter<AccountEntity> {
  @override
  final int typeId = 1;

  @override
  AccountEntity read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AccountEntity()
      ..type = fields[0] == null ? AccountType.TOTP : fields[0] as AccountType
      ..issuer = fields[1] as String
      ..name = fields[2] as String?
      ..secret = fields[3] as String
      ..digits = fields[4] == null ? 6 : fields[4] as int
      ..period = fields[5] == null ? 30 : fields[5] as int;
  }

  @override
  void write(BinaryWriter writer, AccountEntity obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.type)
      ..writeByte(1)
      ..write(obj.issuer)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.secret)
      ..writeByte(4)
      ..write(obj.digits)
      ..writeByte(5)
      ..write(obj.period);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccountEntityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
