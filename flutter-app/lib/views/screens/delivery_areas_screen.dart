import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../controllers/delivery_area_controller.dart';
import '../../models/delivery_area_model.dart';
import '../../services/app_theme.dart';
import 'package:intl/intl.dart';

class DeliveryAreasScreen extends StatefulWidget {
  const DeliveryAreasScreen({super.key});

  @override
  State<DeliveryAreasScreen> createState() => _DeliveryAreasScreenState();
}

class _DeliveryAreasScreenState extends State<DeliveryAreasScreen> {
  final ctrl = Get.find<DeliveryAreaController>();

  @override
  void initState() {
    super.initState();
    // Load ALL areas (including inactive) on open — the shared list
    // otherwise holds only the active areas the cashier dropdown loads,
    // so inactive areas would be invisible here until a manual refresh.
    ctrl.loadAllAreas();
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
              child: const Icon(Icons.location_on,
                  color: AppTheme.accent, size: 22),
            ),
            const SizedBox(width: 10),
            const Text('مناطق التوصيل'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: ctrl.loadAllAreas,
          ),
          IconButton(
            icon: const Icon(Icons.add_circle,
                color: AppTheme.accent, size: 28),
            onPressed: () => _showAreaDialog(context, ctrl, null),
            tooltip: 'إضافة منطقة',
          ),
        ],
      ),
      body: Obx(() {
        if (ctrl.isLoading.value && ctrl.deliveryAreas.isEmpty) {
          return const Center(
              child: CircularProgressIndicator(color: AppTheme.accent));
        }

        if (ctrl.deliveryAreas.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_off,
                    size: 60, color: AppTheme.textSecondary),
                const SizedBox(height: 12),
                const Text('لا توجد مناطق توصيل',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 16)),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _showAreaDialog(context, ctrl, null),
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة منطقة'),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: ctrl.loadAllAreas,
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: ctrl.deliveryAreas.length,
            itemBuilder: (_, i) {
              final area = ctrl.deliveryAreas[i];
              return _AreaTile(area: area, ctrl: ctrl);
            },
          ),
        );
      }),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'areas_fab',
        onPressed: () => _showAreaDialog(context, ctrl, null),
        backgroundColor: AppTheme.accent,
        icon: const Icon(Icons.add),
        label: const Text('إضافة منطقة جديدة'),
      ),
    );
  }

  static void _showAreaDialog(
    BuildContext context,
    DeliveryAreaController ctrl,
    DeliveryAreaModel? area,
  ) {
    final isEdit = area != null;
    final nameCtrl =
        TextEditingController(text: isEdit ? area.name : '');
    final feeCtrl = TextEditingController(
        text: isEdit ? area.deliveryFee.toStringAsFixed(2) : '0.00');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.secondary,
        title: Text(
          isEdit ? 'تعديل المنطقة' : 'إضافة منطقة',
          style: const TextStyle(color: AppTheme.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'اسم المنطقة',
                prefixIcon: Icon(Icons.location_on_outlined,
                    color: AppTheme.textSecondary),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: feeCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                    RegExp(r'^\d+\.?\d{0,2}'))
              ],
              decoration: const InputDecoration(
                hintText: 'رسوم التوصيل',
                prefixIcon: Icon(Icons.attach_money,
                    color: AppTheme.textSecondary),
                suffixText: 'د.أ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('إلغاء',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final fee = double.tryParse(feeCtrl.text) ?? 0.0;
              if (name.isEmpty) return;

              bool ok;
              if (isEdit) {
                ok = await ctrl.updateArea(area,
                    {'name': name, 'delivery_fee': fee, 'is_active': area.isActive});
              } else {
                ok = await ctrl.addArea(
                    name: name, deliveryFee: fee);
              }

              if (ok) {
                Get.back();
                Get.snackbar(
                  isEdit ? 'تم التعديل' : 'تمت الإضافة',
                  isEdit
                      ? 'تم تعديل "$name" بنجاح'
                      : 'تمت إضافة "$name"',
                  backgroundColor: AppTheme.success,
                  colorText: Colors.white,
                  snackPosition: SnackPosition.TOP,
                );
              } else {
                Get.snackbar('خطأ', ctrl.error.value,
                    backgroundColor: AppTheme.accent,
                    colorText: Colors.white,
                    snackPosition: SnackPosition.TOP);
              }
            },
            child: Text(isEdit ? 'حفظ' : 'إضافة'),
          ),
        ],
      ),
    ).whenComplete(() {
      // Dispose the dialog's controllers so they aren't leaked on every open.
      nameCtrl.dispose();
      feeCtrl.dispose();
    });
  }
}

class _AreaTile extends StatelessWidget {
  final DeliveryAreaModel area;
  final DeliveryAreaController ctrl;

  const _AreaTile({required this.area, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: area.isActive
              ? AppTheme.divider
              : AppTheme.accent.withValues(alpha: 0.3),
        ),
      ),
      child: Opacity(
        opacity: area.isActive ? 1.0 : 0.55,
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: (area.isActive ? AppTheme.success : AppTheme.accent)
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.location_on,
              color: area.isActive ? AppTheme.success : AppTheme.accent,
              size: 22,
            ),
          ),
          title: Text(
            area.name,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          subtitle: Text(
            'رسوم التوصيل: ${NumberFormat('#,##0.00').format(area.deliveryFee)} د.أ',
            style: const TextStyle(
                color: AppTheme.accentGold, fontSize: 13),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Toggle active
              GestureDetector(
                onTap: () => ctrl.toggleActive(area.id),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: area.isActive
                        ? AppTheme.success.withValues(alpha: 0.15)
                        : AppTheme.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: area.isActive
                            ? AppTheme.success.withValues(alpha: 0.5)
                            : AppTheme.accent.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    area.isActive ? 'فعّال' : 'معطّل',
                    style: TextStyle(
                      color: area.isActive
                          ? AppTheme.success
                          : AppTheme.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              // Edit
              IconButton(
                icon: const Icon(Icons.edit_outlined,
                    color: AppTheme.textSecondary, size: 20),
                onPressed: () =>
                    _DeliveryAreasScreenState._showAreaDialog(
                        context, ctrl, area),
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              // Delete
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
    Get.dialog(
      AlertDialog(
        backgroundColor: AppTheme.secondary,
        title: const Text('تأكيد الحذف',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Text('هل تريد حذف "${area.name}"؟',
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
              final ok = await ctrl.deleteArea(area.id);
              Get.snackbar(
                ok ? 'تم الحذف' : 'تعذر الحذف',
                ok
                    ? 'تم حذف "${area.name}"'
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