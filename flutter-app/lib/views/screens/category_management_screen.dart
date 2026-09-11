import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../controllers/category_controller.dart';
import '../../models/category_model.dart';
import '../../platform/platform_support.dart' as platform;
import '../../services/app_theme.dart';

class CategoryManagementScreen extends StatelessWidget {
  const CategoryManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<CategoryController>();

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
              child: const Icon(Icons.category, color: AppTheme.accent, size: 22),
            ),
            const SizedBox(width: 10),
            const Text('إدارة الفئات'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: ctrl.loadAll,
            tooltip: 'تحديث',
          ),
          IconButton(
            icon: const Icon(Icons.add_circle, color: AppTheme.accent, size: 28),
            onPressed: () => showCategoryDialog(context, ctrl, null),
            tooltip: 'إضافة فئة',
          ),
        ],
      ),
      body: Obx(() {
        if (ctrl.isLoading.value && ctrl.categories.isEmpty) {
          return const Center(
              child: CircularProgressIndicator(color: AppTheme.accent));
        }

        if (ctrl.categories.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.category_outlined,
                    size: 60, color: AppTheme.textSecondary),
                const SizedBox(height: 12),
                const Text('لا توجد فئات بعد',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 16)),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => showCategoryDialog(context, ctrl, null),
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة أول فئة'),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: ctrl.loadAll,
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: ctrl.categories.length,
            itemBuilder: (_, i) =>
                _CategoryTile(category: ctrl.categories[i], ctrl: ctrl),
          ),
        );
      }),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'categories_fab',
        onPressed: () => showCategoryDialog(context, ctrl, null),
        backgroundColor: AppTheme.accent,
        icon: const Icon(Icons.add),
        label: const Text('إضافة فئة جديدة'),
      ),
    );
  }
}

/// Shared add/edit dialog — pass [category] null to add, or an existing
/// category to edit. Handles picking + uploading an optional image.
void showCategoryDialog(
  BuildContext context,
  CategoryController ctrl,
  CategoryModel? category,
) {
  final isEdit = category != null;
  final nameCtrl = TextEditingController(text: isEdit ? category.name : '');
  XFile? pickedImage;
  bool saving = false;

  showDialog(
    context: context,
    // Dispose the text controller once the dialog is dismissed so it
    // isn't leaked each time the add/edit dialog is opened.
    builder: (_) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        backgroundColor: AppTheme.secondary,
        title: Text(
          isEdit ? 'تعديل الفئة' : 'إضافة فئة',
          style: const TextStyle(color: AppTheme.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: GestureDetector(
                onTap: () async {
                  final file = await ImagePicker().pickImage(
                    source: ImageSource.gallery,
                    maxWidth: 800,
                    maxHeight: 800,
                    imageQuality: 80,
                  );
                  if (file != null) {
                    setDialogState(() => pickedImage = file);
                  }
                },
                child: Container(
                  width: 90,
                  height: 90,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: AppTheme.accent.withValues(alpha: 0.4), width: 2),
                  ),
                  child: _buildCategoryImagePreview(pickedImage, category),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'اسم الفئة (مثال: شاورما، بيتزا، مشروبات)',
                prefixIcon: Icon(Icons.category_outlined,
                    color: AppTheme.textSecondary),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: saving ? null : () => Get.back(),
            child: const Text('إلغاء',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: saving
                ? null
                : () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    setDialogState(() => saving = true);

                    final ok = isEdit
                        ? await ctrl.updateCategory(
                            category, {'name': name},
                            imagePath: pickedImage?.path)
                        : await ctrl.addCategory(
                            name: name, imagePath: pickedImage?.path);

                    if (ok) {
                      Get.back();
                      Get.snackbar(
                        isEdit ? 'تم التعديل' : 'تمت الإضافة',
                        isEdit ? 'تم تعديل "$name" بنجاح' : 'تمت إضافة "$name"',
                        backgroundColor: AppTheme.success,
                        colorText: Colors.white,
                        snackPosition: SnackPosition.TOP,
                      );
                    } else {
                      setDialogState(() => saving = false);
                      Get.snackbar('خطأ', ctrl.error.value,
                          backgroundColor: AppTheme.accent,
                          colorText: Colors.white,
                          snackPosition: SnackPosition.TOP);
                    }
                  },
            child: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Text(isEdit ? 'حفظ' : 'إضافة'),
          ),
        ],
      ),
    ),
  ).whenComplete(nameCtrl.dispose);
}

Widget _buildCategoryImagePreview(XFile? pickedImage, CategoryModel? category) {
  if (pickedImage != null) {
    return platform.localImage(pickedImage.path, fit: BoxFit.cover);
  }
  final existingUrl = category?.imageUrl;
  if (existingUrl != null && existingUrl.isNotEmpty) {
    return Image.network(
      existingUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const Icon(Icons.category,
          color: AppTheme.accent, size: 28),
    );
  }
  return const Icon(Icons.add_photo_alternate_outlined,
      color: AppTheme.accent, size: 28);
}

class _CategoryTile extends StatelessWidget {
  final CategoryModel category;
  final CategoryController ctrl;

  const _CategoryTile({required this.category, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final itemCount = category.menuItemsCount ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: category.isActive
              ? AppTheme.divider
              : AppTheme.accent.withValues(alpha: 0.3),
        ),
      ),
      child: Opacity(
        opacity: category.isActive ? 1.0 : 0.55,
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          leading: Container(
            width: 44,
            height: 44,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: (category.isActive ? AppTheme.success : AppTheme.accent)
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: (category.imageUrl != null && category.imageUrl!.isNotEmpty)
                ? Image.network(
                    category.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Icon(
                      Icons.category,
                      color:
                          category.isActive ? AppTheme.success : AppTheme.accent,
                      size: 22,
                    ),
                  )
                : Icon(
                    Icons.category,
                    color:
                        category.isActive ? AppTheme.success : AppTheme.accent,
                    size: 22,
                  ),
          ),
          title: Text(
            category.name,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          subtitle: Text(
            '$itemCount صنف',
            style: const TextStyle(color: AppTheme.accentGold, fontSize: 13),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () => ctrl.toggleActive(category),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: category.isActive
                        ? AppTheme.success.withValues(alpha: 0.15)
                        : AppTheme.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: category.isActive
                            ? AppTheme.success.withValues(alpha: 0.5)
                            : AppTheme.accent.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    category.isActive ? 'فعّالة' : 'معطّلة',
                    style: TextStyle(
                      color: category.isActive
                          ? AppTheme.success
                          : AppTheme.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined,
                    color: AppTheme.textSecondary, size: 20),
                onPressed: () => showCategoryDialog(context, ctrl, category),
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: AppTheme.accent, size: 20),
                onPressed: () => _confirmDelete(context),
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

  void _confirmDelete(BuildContext context) {
    final itemCount = category.menuItemsCount ?? 0;
    Get.dialog(
      AlertDialog(
        backgroundColor: AppTheme.secondary,
        title: const Text('تأكيد الحذف',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          itemCount > 0
              ? 'يوجد $itemCount صنف مرتبط بفئة "${category.name}". يجب نقل أو حذف هذه الأصناف قبل حذف الفئة.'
              : 'هل تريد حذف "${category.name}"؟',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('إلغاء',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Get.back();
              final ok = await ctrl.deleteCategory(category);
              Get.snackbar(
                ok ? 'تم الحذف' : 'خطأ',
                ok ? 'تم حذف "${category.name}"' : ctrl.error.value,
                backgroundColor: AppTheme.accent,
                colorText: Colors.white,
                snackPosition: SnackPosition.TOP,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}
