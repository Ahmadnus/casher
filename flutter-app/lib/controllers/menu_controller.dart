import 'package:get/get.dart';
import '../models/menu_item_model.dart';
import '../models/category_model.dart';
import '../repositories/menu_item_repository.dart';
import '../repositories/category_repository.dart';
import '../core/api_exception.dart';

class MenuItemController extends GetxController {
  final _menuRepo = MenuItemRepository();
  final _catRepo  = CategoryRepository();

  final RxList<MenuItemModel>  menuItems  = <MenuItemModel>[].obs;
  final RxList<CategoryModel>  categories = <CategoryModel>[].obs;
  final RxBool  isLoading = false.obs;
  final RxString error    = ''.obs;

  /// Selected category name for the cashier grid filter chips.
  final RxString selectedCategory = ''.obs;

  // ── Backward-compat alias used by cashier_screen / cart_bottom_sheet ──
  /// Same list as [menuItems]. Screens that used the old name still work.
  List<MenuItemModel> get items => menuItems;

  /// Items visible in the cashier grid (filtered by [selectedCategory]).
  List<MenuItemModel> get filteredItems {
    final sel = selectedCategory.value;
    if (sel.isEmpty) return menuItems.toList();
    return menuItems.where((m) => m.category == sel).toList();
  }

  /// All items for the admin management screen (same as menuItems).
  List<MenuItemModel> get allItemsForManagement => menuItems.toList();

  @override
  void onInit() {
    super.onInit();
    loadAll();
  }

  Future<void> loadAll() async {
    isLoading.value = true;
    error.value = '';
    try {
      await Future.wait([loadMenuItems(), loadCategories()]);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadMenuItems() async {
    try {
      final items = await _menuRepo.getAvailableItems();
      menuItems.value = items;
    } on ApiException catch (e) {
      error.value = e.displayMessage;
    } catch (_) {
      error.value = 'فشل تحميل القائمة';
    }
  }

  Future<void> loadCategories() async {
    try {
      final cats = await _catRepo.getActiveCategories();
      categories.value = cats;
    } on ApiException catch (e) {
      // Surface the failure instead of leaving the cashier with empty
      // category chips and no explanation.
      error.value = e.displayMessage;
    } catch (_) {
      error.value = 'فشل تحميل الفئات';
    }
  }

  Future<void> loadAllMenuItemsAdmin() async {
    isLoading.value = true;
    try {
      final page = await _menuRepo.getMenuItems(perPage: 200);
      menuItems.value = page.items;
    } on ApiException catch (e) {
      error.value = e.displayMessage;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> addMenuItem({
    required String name,
    required double price,
    required int categoryId,
    String? description,
    bool isAvailable = true,
    int sortOrder = 0,
    String? imagePath,
  }) async {
    try {
      final item = await _menuRepo.createMenuItem({
        'name': name,
        'price': price,
        'category_id': categoryId,
        'description': ?description,
        'is_available': isAvailable,
        'sort_order': sortOrder,
      }, imagePath: imagePath);
      menuItems.add(item);
      return true;
    } on ApiException catch (e) {
      error.value = e.displayMessage;
      return false;
    }
  }

  Future<bool> updateMenuItem(MenuItemModel item, Map<String, dynamic> data,
      {String? imagePath}) async {
    try {
      final updated =
          await _menuRepo.updateMenuItem(item.id, data, imagePath: imagePath);
      final idx = menuItems.indexWhere((m) => m.id == item.id);
      if (idx >= 0) menuItems[idx] = updated;
      return true;
    } on ApiException catch (e) {
      error.value = e.displayMessage;
      return false;
    }
  }

  /// Accepts [MenuItemModel] — used by MenuFormScreen.
  Future<bool> toggleAvailability(MenuItemModel item) async {
    try {
      final updated = await _menuRepo.toggleAvailability(item.id);
      final idx = menuItems.indexWhere((m) => m.id == item.id);
      if (idx >= 0) menuItems[idx] = updated;
      return true;
    } on ApiException catch (e) {
      error.value = e.displayMessage;
      return false;
    }
  }

  /// Accepts a String [id] — used by MenuManagementScreen tile.
  Future<bool> toggleAvailabilityById(String id) async {
    final item = _findById(id);
    if (item == null) return false;
    return toggleAvailability(item);
  }

  /// Accepts [MenuItemModel] — primary delete method.
  Future<bool> deleteMenuItem(MenuItemModel item) async {
    try {
      await _menuRepo.deleteMenuItem(item.id);
      menuItems.removeWhere((m) => m.id == item.id);
      return true;
    } on ApiException catch (e) {
      error.value = e.displayMessage;
      return false;
    }
  }

  /// Accepts a String [id] — convenience method used by management screen.
  Future<bool> deleteItem(String id) async {
    final item = _findById(id);
    if (item == null) return false;
    return deleteMenuItem(item);
  }

  MenuItemModel? _findById(String id) {
    for (final m in menuItems) {
      if (m.id == id) return m;
    }
    return null;
  }

  List<MenuItemModel> getItemsByCategory(String categoryName) =>
      menuItems.where((m) => m.category == categoryName).toList();

  List<MenuItemModel> get availableItems =>
      menuItems.where((m) => m.isAvailable).toList();
}