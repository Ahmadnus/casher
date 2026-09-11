import 'package:hive/hive.dart';

import '../core/json_parsing.dart';

class DeliveryAreaModel extends HiveObject {
  String id;
  String name;
  bool isActive;
  double deliveryFee;

  DeliveryAreaModel({
    required this.id,
    required this.name,
    this.isActive = true,
    this.deliveryFee = 0.0,
  });

  // ── API serialization ──────────────────────────────────────────
  factory DeliveryAreaModel.fromJson(Map<String, dynamic> json) {
    return DeliveryAreaModel(
      id: json['id'].toString(),
      name: json['name'] as String? ?? '',
      isActive: asBool(json['is_active'], true),
      deliveryFee: asDouble(json['delivery_fee']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'is_active': isActive,
        'delivery_fee': deliveryFee,
      };
}

class DeliveryAreaModelAdapter extends TypeAdapter<DeliveryAreaModel> {
  @override
  final int typeId = 3;

  @override
  DeliveryAreaModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DeliveryAreaModel(
      id: fields[0] as String,
      name: fields[1] as String,
      isActive: fields[2] as bool,
      deliveryFee: (fields[3] as num?)?.toDouble() ?? 0.0,
    );
  }

  @override
  void write(BinaryWriter writer, DeliveryAreaModel obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.isActive)
      ..writeByte(3)
      ..write(obj.deliveryFee);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeliveryAreaModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
