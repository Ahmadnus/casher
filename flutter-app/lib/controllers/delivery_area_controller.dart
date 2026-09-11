import 'package:get/get.dart';
import '../models/delivery_area_model.dart';
import '../repositories/delivery_area_repository.dart';
import '../core/api_exception.dart';

class DeliveryAreaController extends GetxController {
  final _repo = DeliveryAreaRepository();

  final RxList<DeliveryAreaModel> deliveryAreas = <DeliveryAreaModel>[].obs;
  final RxBool  isLoading = false.obs;
  final RxString error    = ''.obs;

  @override
  void onInit() {
    super.onInit();
    loadDeliveryAreas();
  }

  Future<void> loadDeliveryAreas() async {
    isLoading.value = true;
    error.value = '';
    try {
      final areas = await _repo.getActiveAreas();
      deliveryAreas.value = areas;
    } on ApiException catch (e) {
      error.value = e.displayMessage;
    } catch (_) {
      error.value = 'فشل تحميل مناطق التوصيل';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadAllAreas() async {
    isLoading.value = true;
    try {
      final areas = await _repo.getAllAreas();
      deliveryAreas.value = areas;
    } on ApiException catch (e) {
      error.value = e.displayMessage;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> addArea({
    required String name,
    double deliveryFee = 0.0,
    bool isActive = true,
  }) async {
    try {
      final area = await _repo.createArea({
        'name': name,
        'delivery_fee': deliveryFee,
        'is_active': isActive,
        'sort_order': 0,
      });
      deliveryAreas.add(area);
      return true;
    } on ApiException catch (e) {
      error.value = e.displayMessage;
      return false;
    }
  }

  Future<bool> updateArea(DeliveryAreaModel area, Map<String, dynamic> data) async {
    try {
      final updated = await _repo.updateArea(area.id, data);
      final idx = deliveryAreas.indexWhere((a) => a.id == area.id);
      if (idx >= 0) deliveryAreas[idx] = updated;
      return true;
    } on ApiException catch (e) {
      error.value = e.displayMessage;
      return false;
    }
  }

  Future<bool> toggleActive(String id) async {
    try {
      final updated = await _repo.toggleActive(id);
      final idx = deliveryAreas.indexWhere((a) => a.id == id);
      if (idx >= 0) deliveryAreas[idx] = updated;
      return true;
    } on ApiException catch (e) {
      error.value = e.displayMessage;
      return false;
    }
  }

  Future<bool> deleteArea(String id) async {
    try {
      await _repo.deleteArea(id);
      deliveryAreas.removeWhere((a) => a.id == id);
      return true;
    } on ApiException catch (e) {
      error.value = e.displayMessage;
      return false;
    }
  }

  List<DeliveryAreaModel> get activeAreas =>
      deliveryAreas.where((a) => a.isActive).toList();
}