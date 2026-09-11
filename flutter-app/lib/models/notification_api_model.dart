import '../core/json_parsing.dart';

class NotificationApiModel {
  final String id;
  final String type;
  final Map<String, dynamic> data;
  final bool read;
  final DateTime? readAt;
  final DateTime createdAt;

  String get message => data['message'] as String? ?? '';
  String get notificationType => data['type'] as String? ?? type;

  const NotificationApiModel({
    required this.id,
    required this.type,
    required this.data,
    required this.read,
    this.readAt,
    required this.createdAt,
  });

  factory NotificationApiModel.fromJson(Map<String, dynamic> json) {
    return NotificationApiModel(
      id: json['id'] as String,
      type: json['type'] as String? ?? '',
      data: json['data'] as Map<String, dynamic>? ?? {},
      read: asBool(json['read']),
      readAt: json['read_at'] != null
          ? DateTime.tryParse(json['read_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}
