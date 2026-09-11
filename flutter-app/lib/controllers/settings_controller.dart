import 'package:get/get.dart';
import '../models/settings_model.dart';
import '../repositories/settings_repository.dart';
import '../core/api_exception.dart';

class SettingsController extends GetxController {
  final _repo = SettingsRepository();

  final Rx<SettingsModel> settings = SettingsModel.defaults().obs;
  final RxBool  isLoading = false.obs;
  final RxString error    = ''.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    try {
      settings.value = await _repo.getSettings();
    } on ApiException catch (e) {
      error.value = e.displayMessage;
    } catch (_) {
    } finally {
      isLoading.value = false;
    }
  }

  /// Renamed from `update` to avoid shadowing GetxController.update().
  Future<bool> saveSettings(Map<String, dynamic> data) async {
    isLoading.value = true;
    try {
      settings.value = await _repo.updateSettings(data);
      return true;
    } on ApiException catch (e) {
      error.value = e.displayMessage;
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  String get restaurantName  => settings.value.name;
  String get currencySymbol  => settings.value.currencySymbol;
}