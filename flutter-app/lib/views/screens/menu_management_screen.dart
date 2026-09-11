import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/menu_controller.dart';
import '../../models/menu_item_model.dart';
import '../../platform/platform_support.dart' as platform;
import '../../services/app_theme.dart';
import 'category_management_screen.dart';
import 'menu_form_screen.dart';
import 'package:intl/intl.dart';

class MenuManagementScreen extends StatefulWidget {
  const MenuManagementScreen({super.key});

  @override
  State<MenuManagementScreen> createState() => _MenuManagementScreenState();
}

class _MenuManagementScreenState extends State<MenuManagementScreen> {
  final ctrl = Get.find<MenuItemController>();

  @override
  void initState() {
    super.initState();
    // Load the FULL admin list (including unavailable items) on open —
    // the shared menuItems list otherwise holds only the cashier's
    // available-only items, hiding disabled products from management.
    ctrl.loadAllMenuItemsAdmin();
  }

  @override
  void dispose() {
    // Restore the cashier's available-only view when leaving management,
    // so the POS grid doesn't keep showing unavailable items.
    ctrl.loadMenuItems();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.restaurant_menu,
                  color: AppTheme.accent, size: 22),
            ),
            const SizedBox(width: 10),
            const Text('إدارة القائمة'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ctrl.loadAllMenuItemsAdmin(),
            tooltip: 'تحديث',
          ),
          IconButton(
            icon: const Icon(Icons.category_outlined),
            onPressed: () => Get.to(() => const CategoryManagementScreen()),
            tooltip: 'إدارة الفئات',
          ),
          IconButton(
            icon: const Icon(Icons.add_circle, color: AppTheme.accent, size: 28),
            onPressed: () => Get.to(() => const MenuFormScreen(item: null)),
            tooltip: 'إضافة صنف',
          ),
        ],
      ),
      body: Obx(() {
        if (ctrl.isLoading.value && ctrl.menuItems.isEmpty) {
          return const Center(
              child: CircularProgressIndicator(color: AppTheme.accent));
        }

        // Use menuItems (the actual reactive list)
        final items = ctrl.menuItems;
        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.restaurant_menu,
                    size: 60, color: AppTheme.textSecondary),
                const SizedBox(height: 12),
                const Text('القائمة فارغة',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 16)),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () =>
                      Get.to(() => const MenuFormScreen(item: null)),
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة أول صنف'),
                ),
              ],
            ),
          );
        }

        // Group by category name
        final Map<String, List<MenuItemModel>> grouped = {};
        for (final item in items) {
          grouped.putIfAbsent(item.category.isEmpty ? 'عام' : item.category, () => []).add(item);
        }

        return RefreshIndicator(
          onRefresh: ctrl.loadAllMenuItemsAdmin,
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: grouped.keys.length,
            itemBuilder: (_, i) {
              final category = grouped.keys.elementAt(i);
              final catItems = grouped[category]!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 8, horizontal: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 20,
                          decoration: BoxDecoration(
                            color: AppTheme.accent,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(category,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            )),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('${catItems.length}',
                              style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                  ...catItems.map((item) =>
                      _MenuItemManageTile(item: item, ctrl: ctrl)),
                  const SizedBox(height: 8),
                ],
              );
            },
          ),
        );
      }),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'menu_fab',
        onPressed: () => Get.to(() => const MenuFormScreen(item: null)),
        backgroundColor: AppTheme.accent,
        icon: const Icon(Icons.add),
        label: const Text('إضافة صنف جديد'),
      ),
    );
  }
}

class _MenuItemManageTile extends StatelessWidget {
  final MenuItemModel item;
  final MenuItemController ctrl;

  const _MenuItemManageTile({required this.item, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: item.isAvailable
              ? AppTheme.divider
              : AppTheme.accent.withValues(alpha: 0.3),
        ),
      ),
      child: Opacity(
        opacity: item.isAvailable ? 1.0 : 0.6,
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 52,
              height: 52,
              child: (item.imageUrl != null && item.imageUrl!.isNotEmpty)
                  ? Image.network(item.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _imgPlaceholder())
                  : (item.imagePath != null && item.imagePath!.isNotEmpty)
                      ? platform.localImage(item.imagePath!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _imgPlaceholder())
                      : _imgPlaceholder(),
            ),
          ),
          title: Text(item.name,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              )),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${NumberFormat('#,##0.00').format(item.price)} د.أ',
                  style: const TextStyle(
                      color: AppTheme.accentGold, fontSize: 13)),
              if (item.description != null && item.description!.isNotEmpty)
                Text(item.description!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Toggle availability — pass full item object
              GestureDetector(
                onTap: () => ctrl.toggleAvailability(item),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: item.isAvailable
                        ? AppTheme.success.withValues(alpha: 0.15)
                        : AppTheme.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: item.isAvailable
                          ? AppTheme.success.withValues(alpha: 0.5)
                          : AppTheme.accent.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    item.isAvailable ? 'متاح' : 'غير متاح',
                    style: TextStyle(
                      color: item.isAvailable
                          ? AppTheme.success
                          : AppTheme.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Edit
              IconButton(
                icon: const Icon(Icons.edit_outlined,
                    color: AppTheme.textSecondary, size: 20),
                onPressed: () => Get.to(() => MenuFormScreen(item: item)),
                tooltip: 'تعديل',
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              // Delete — pass full item object
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: AppTheme.accent, size: 20),
                onPressed: () => _confirmDelete(context, item),
                tooltip: 'حذف',
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imgPlaceholder() {
    return Container(
      color: AppTheme.surface,
      child: const Center(
        child: Icon(Icons.restaurant, size: 24, color: AppTheme.textSecondary),
      ),
    );
  }

  void _confirmDelete(BuildContext context, MenuItemModel item) {
    Get.dialog(
      AlertDialog(
        backgroundColor: AppTheme.secondary,
        title: const Text('تأكيد الحذف',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Text('هل تريد حذف "${item.name}"؟',
            style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('إلغاء',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Get.back();
              final ok = await ctrl.deleteMenuItem(item);
              Get.snackbar(
                ok ? 'تم الحذف' : 'تعذر الحذف',
                ok
                    ? 'تم حذف "${item.name}" بنجاح'
                    : (ctrl.error.value.isNotEmpty
                        ? ctrl.error.value
                        : 'حدث خطأ، حاول مرة أخرى'),
                backgroundColor: AppTheme.accent,
                colorText: Colors.white,
                snackPosition: SnackPosition.TOP,
              );
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}