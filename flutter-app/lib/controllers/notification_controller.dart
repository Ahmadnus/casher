import 'package:get/get.dart';
import '../models/notification_api_model.dart';
import '../repositories/notification_repository.dart';
import '../core/api_exception.dart';

class NotificationController extends GetxController {
  final _repo = NotificationRepository();

  final RxList<NotificationApiModel> notifications = <NotificationApiModel>[].obs;
  final RxInt unreadCount = 0.obs;
  final RxBool isLoading = false.obs;

  // NOTE: no auto-load in onInit. This controller is created eagerly at
  // app start (before login), so loading here fired a pre-auth request
  // that 401'd and was discarded. Whatever UI consumes notifications
  // should call load() when it mounts.

  Future<void> load() async {
    isLoading.value = true;
    try {
      final page = await _repo.getNotifications(perPage: 30);
      notifications.value = page.items;
      // Prefer the server's total unread count (accurate beyond the
      // fetched page) and fall back to counting the loaded items.
      unreadCount.value = page.unreadCount ??
          notifications.where((n) => !n.read).length;
    } on ApiException catch (_) {
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> markAsRead(NotificationApiModel n) async {
    try {
      await _repo.markAsRead(n.id);
      final idx = notifications.indexWhere((e) => e.id == n.id);
      if (idx >= 0) {
        load();
      }
    } catch (_) {}
  }

  Future<void> markAllAsRead() async {
    try {
      await _repo.markAllAsRead();
      await load();
    } catch (_) {}
  }

  Future<void> deleteNotification(NotificationApiModel n) async {
    try {
      await _repo.deleteNotification(n.id);
      notifications.removeWhere((e) => e.id == n.id);
      unreadCount.value = notifications.where((e) => !e.read).length;
    } catch (_) {}
  }
}
