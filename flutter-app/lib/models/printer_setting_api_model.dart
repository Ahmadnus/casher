import '../core/json_parsing.dart';

class PrinterSettingApiModel {
  final int id;
  final String name;
  final String type; // 'cash' | 'invoice'

  /// Android: "vendorId:productId" USB descriptor.
  /// Windows: the printer's registered queue name.
  final String deviceIdentifier;
  final bool isActive;
  final bool isDefault;

  const PrinterSettingApiModel({
    required this.id,
    required this.name,
    required this.type,
    required this.deviceIdentifier,
    this.isActive = true,
    this.isDefault = false,
  });

  factory PrinterSettingApiModel.fromJson(Map<String, dynamic> json) {
    return PrinterSettingApiModel(
      id: asInt(json['id']),
      name: json['name'] as String? ?? '',
      type: json['type'] as String? ?? 'invoice',
      deviceIdentifier: json['device_identifier'] as String? ?? '',
      isActive: asBool(json['is_active'], true),
      isDefault: asBool(json['is_default']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'device_identifier': deviceIdentifier,
        'is_active': isActive,
        'is_default': isDefault,
      };
}
