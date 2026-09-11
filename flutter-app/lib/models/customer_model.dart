import '../core/json_parsing.dart';

class CustomerModel {
  final int id;
  final String name;
  final String phone;
  final String? email;
  final String? address;
  final String? deliveryAddress;
  final int? deliveryAreaId;
  final String? notes;
  final bool isActive;

  const CustomerModel({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.address,
    this.deliveryAddress,
    this.deliveryAreaId,
    this.notes,
    this.isActive = true,
  });

  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    return CustomerModel(
      id: asInt(json['id']),
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String?,
      address: json['address'] as String?,
      deliveryAddress: json['delivery_address'] as String?,
      deliveryAreaId: asIntOrNull(json['delivery_area']?['id']),
      notes: json['notes'] as String?,
      isActive: asBool(json['is_active'], true),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'address': address,
        'delivery_address': deliveryAddress,
        'delivery_area_id': deliveryAreaId,
        'notes': notes,
        'is_active': isActive,
      };
}
