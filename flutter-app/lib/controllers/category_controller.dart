import 'package:get/get.dart';
import '../models/category_model.dart';
import '../repositories/category_repository.dart';
import '../core/api_exception.dart';
import 'menu_controller.dart';

class CategoryController extends GetxController {
  final _repo = CategoryRepository();

  final RxList<CategoryModel> categories = <CategoryModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxString error = ''.obs;

  @override
  void onInit() {
    super.onInit();
    loadAll();
  }

  /// Full list (active + inactive) for the admin management screen.
  Future<void> loadAll() async {
    isLoading.value = true;
    error.value = '';
    try {
      final cats = await _repo.getAllCategories();
      categories.value = cats;
    } on ApiException catch (e) {
      error.value = e.displayMessage;
    } catch (_) {
      error.value = 'فشل تحميل الفئات';
    } finally {
      isLoading.value = false;
    }
  }

  /// Refreshes the active-only category cache used by the cashier grid
  /// and the menu item form, wherever [MenuItemController] is registered.
  void _syncMenuController() {
    if (Get.isRegistered<MenuItemController>()) {
      Get.find<MenuItemController>().loadCategories();
    }
  }

  Future<bool> addCategory({
    required String name,
    bool isActive = true,
    String? imagePath,
  }) async {
    try {
      final category = await _repo.createCategory({
        'name': name,
        'is_active': isActive,
      }, imagePath: imagePath);
      categories.add(category);
      _syncMenuController();
      return true;
    } on ApiException catch (e) {
      error.value = e.displayMessage;
      return false;
    }
  }

  Future<bool> updateCategory(CategoryModel category, Map<String, dynamic> data,
      {String? imagePath}) async {
    try {
      final updated = await _repo.updateCategory(category.id, data,
          imagePath: imagePath);
      final idx = categories.indexWhere((c) => c.id == category.id);
      if (idx >= 0) categories[idx] = updated;
      _syncMenuController();
      return true;
    } on ApiException catch (e) {
      error.value = e.displayMessage;
      return false;
    }
  }

  Future<bool> toggleActive(CategoryModel category) =>
      updateCategory(category, {'is_active': !category.isActive});

  Future<bool> deleteCategory(CategoryModel category) async {
    try {
      await _repo.deleteCategory(category.id);
      categories.removeWhere((c) => c.id == category.id);
      _syncMenuController();
      return true;
    } on ApiException catch (e) {
      error.value = e.displayMessage;
      return false;
    }
  }
}
