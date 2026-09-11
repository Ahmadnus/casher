import 'package:get/get.dart';
import '../models/dashboard_model.dart';
import '../repositories/dashboard_repository.dart';
import '../core/api_exception.dart';

class DashboardController extends GetxController {
  final _repo = DashboardRepository();

  final Rx<DashboardModel> dashboard = DashboardModel.empty().obs;
  final RxBool isLoading = false.obs;
  final RxString error = ''.obs;

  // NOTE: deliberately no load() in onInit — this controller is created
  // eagerly at app start (before login), so auto-loading here fired a
  // pre-auth request that 401'd and was discarded. The DashboardScreen
  // calls load() itself when it opens.

  Future<void> load() async {
    isLoading.value = true;
    error.value = '';
    try {
      dashboard.value = await _repo.getSummary();
    } on ApiException catch (e) {
      error.value = e.displayMessage;
    } catch (_) {
      error.value = 'فشل تحميل لوحة التحكم';
    } finally {
      isLoading.value = false;
    }
  }
}
