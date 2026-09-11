import '../core/json_parsing.dart';

/// Generic envelope that wraps every successful Laravel API response.
class ApiResponse<T> {
  final bool success;
  final String? message;
  final T? data;

  const ApiResponse({
    required this.success,
    this.message,
    this.data,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic data) fromData,
  ) {
    return ApiResponse<T>(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String?,
      data: json['data'] != null ? fromData(json['data']) : null,
    );
  }
}

/// Paginated list wrapper returned by index endpoints.
class PaginatedResponse<T> {
  final List<T> items;
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  /// Optional extra count some endpoints include alongside the page
  /// (e.g. notifications' total unread). Null when not provided.
  final int? unreadCount;

  const PaginatedResponse({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
    this.unreadCount,
  });

  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromItem,
  ) {
    final rawItems = json['items'] as List? ?? [];
    final pagination = json['pagination'] as Map<String, dynamic>? ?? {};

    return PaginatedResponse<T>(
      items: rawItems
          .map((e) => fromItem(e as Map<String, dynamic>))
          .toList(),
      currentPage: asInt(pagination['current_page'], 1),
      lastPage: asInt(pagination['last_page'], 1),
      perPage: asInt(pagination['per_page'], 20),
      total: asInt(pagination['total']),
      unreadCount: json['unread_count'] != null
          ? asInt(json['unread_count'])
          : null,
    );
  }

  bool get hasMore => currentPage < lastPage;
}
