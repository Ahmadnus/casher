import 'package:hive/hive.dart';

import '../core/json_parsing.dart';

class MenuItemModel extends HiveObject {
  String id;
  String name;
  double price;
  String category;
  String? description;
  String? imagePath;
  bool isAvailable;
  int? categoryId;
  String? imageUrl;

  MenuItemModel({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    this.description,
    this.imagePath,
    this.isAvailable = true,
    this.categoryId,
    this.imageUrl,
  });

  // ── API serialization ──────────────────────────────────────────
  factory MenuItemModel.fromJson(Map<String, dynamic> json) {
    final cat = json['category'] as Map<String, dynamic>?;
    return MenuItemModel(
      id: json['id'].toString(),
      name: json['name'] as String? ?? '',
      price: asDouble(json['price']),
      category: cat?['name'] as String? ?? '',
      description: json['description'] as String?,
      imagePath: null,
      imageUrl: json['image_url'] as String?,
      isAvailable: asBool(json['is_available'], true),
      categoryId: asIntOrNull(json['category_id']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'price': price,
        'category': category,
        'description': description,
        'is_available': isAvailable,
        'category_id': categoryId,
        'image_url': imageUrl,
      };
}

class MenuItemModelAdapter extends TypeAdapter<MenuItemModel> {
  @override
  final int typeId = 0;

  @override
  MenuItemModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MenuItemModel(
      id: fields[0] as String,
      name: fields[1] as String,
      price: fields[2] as double,
      category: fields[3] as String,
      description: fields[4] as String?,
      imagePath: fields[5] as String?,
      isAvailable: fields[6] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, MenuItemModel obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.price)
      ..writeByte(3)
      ..write(obj.category)
      ..writeByte(4)
      ..write(obj.description)
      ..writeByte(5)
      ..write(obj.imagePath)
      ..writeByte(6)
      ..write(obj.isAvailable);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MenuItemModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
