import 'package:hive/hive.dart';

import '../core/json_parsing.dart';

class EmployeeModel extends HiveObject {
  String id;
  String username;
  String password;
  String name;
  String role;
  String? pin;
  bool isActive;
  String? email;
  String? phone;
  String? avatarUrl;

  EmployeeModel({
    required this.id,
    required this.username,
    required this.password,
    required this.name,
    required this.role,
    this.pin,
    this.isActive = true,
    this.email,
    this.phone,
    this.avatarUrl,
  });

  // ── API serialization ──────────────────────────────────────────
  factory EmployeeModel.fromJson(Map<String, dynamic> json) {
    return EmployeeModel(
      id: json['id'].toString(),
      username: json['username'] as String? ?? '',
      password: '',
      name: json['name'] as String? ?? '',
      role: json['role'] as String? ?? 'cashier',
      pin: null,
      isActive: asBool(json['is_active'], true),
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'name': name,
        'role': role,
        'is_active': isActive,
        'email': email,
        'phone': phone,
        'avatar_url': avatarUrl,
      };
}

class EmployeeModelAdapter extends TypeAdapter<EmployeeModel> {
  @override
  final int typeId = 4;

  @override
  EmployeeModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return EmployeeModel(
      id: fields[0] as String,
      username: fields[1] as String,
      password: fields[2] as String,
      name: fields[3] as String,
      role: fields[4] as String,
      pin: fields.containsKey(5) ? fields[5] as String? : null,
      isActive: fields.containsKey(6) ? fields[6] as bool : true,
    );
  }

  @override
  void write(BinaryWriter writer, EmployeeModel obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.username)
      ..writeByte(2)
      ..write(obj.password)
      ..writeByte(3)
      ..write(obj.name)
      ..writeByte(4)
      ..write(obj.role)
      ..writeByte(5)
      ..write(obj.pin)
      ..writeByte(6)
      ..write(obj.isActive);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EmployeeModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
