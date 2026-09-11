import 'package:dio/dio.dart';
import '../network/network.dart';
import '../network/api_endpoints.dart';
import '../models/notification_api_model.dart';
import '../models/api_response.dart';

class NotificationRepository {
  Future<PaginatedResponse<NotificationApiModel>> getNotifications({
    bool unreadOnly = false,
    int perPage = 20,
  }) async {
    try {
      final res = await Network.dio.get(ApiEndpoints.notifications,
          queryParameters: {
            if (unreadOnly) 'unread_only': '1',
            'per_page': perPage,
          });
      return PaginatedResponse.fromJson(
        (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
        NotificationApiModel.fromJson,
      );
    } on DioException catch (e) {
      throw Network.handleError(e);
    }
  }

  Future<void> markAsRead(String id) async {
    try {
      await Network.dio.patch(ApiEndpoints.markNotificationRead(id));
    } on DioException catch (e) {
      throw Network.handleError(e);
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await Network.dio.patch(ApiEndpoints.markAllNotificationsRead);
    } on DioException catch (e) {
      throw Network.handleError(e);
    }
  }

  Future<void> deleteNotification(String id) async {
    try {
      await Network.dio.delete(ApiEndpoints.notificationById(id));
    } on DioException catch (e) {
      throw Network.handleError(e);
    }
  }
}
