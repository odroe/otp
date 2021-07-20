// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'origin.entity.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class OriginTypeAdapter extends TypeAdapter<OriginType> {
  @override
  final int typeId = 0;

  @override
  OriginType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return OriginType.HOTP;
      case 1:
        return OriginType.TOTP;
      default:
        return OriginType.HOTP;
    }
  }

  @override
  void write(BinaryWriter writer, OriginType obj) {
    switch (obj) {
      case OriginType.HOTP:
        writer.writeByte(0);
        break;
      case OriginType.TOTP:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OriginTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class OriginEntityAdapter extends TypeAdapter<OriginEntity> {
  @override
  final int typeId = 1;

  @override
  OriginEntity read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return OriginEntity()
      ..type = fields[0] == null ? OriginType.TOTP : fields[0] as OriginType
      ..issuer = fields[1] as String
      ..account = fields[2] as String
      ..secret = fields[3] as String
      ..digits = fields[4] == null ? 6 : fields[4] as int
      ..period = fields[5] == null ? 30 : fields[5] as int;
  }

  @override
  void write(BinaryWriter writer, OriginEntity obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.type)
      ..writeByte(1)
      ..write(obj.issuer)
      ..writeByte(2)
      ..write(obj.account)
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
      other is OriginEntityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
