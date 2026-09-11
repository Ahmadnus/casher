import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/employee_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../models/employee_model.dart';
import '../../services/app_theme.dart';

/// Arabic labels for backend role slugs — single source of truth so the
/// create/edit dropdown and the list tiles never disagree.
const Map<String, String> kRoleLabels = {
  'super_admin': 'مدير النظام',
  'admin': 'مدير عام',
  'manager': 'مدير',
  'cashier': 'كاشير',
  'kitchen': 'مطبخ',
  'waiter': 'موظف صالة',
  'delivery': 'توصيل',
};

String roleLabelFor(String role) => kRoleLabels[role] ?? role;

/// Fallback role list if the API roles haven't loaded yet. Excludes
/// super_admin (not user-creatable) but includes waiter.
const List<String> kSelectableRolesFallback = [
  'admin', 'manager', 'cashier', 'kitchen', 'waiter', 'delivery',
];

class EmployeeManagementScreen extends StatelessWidget {
  const EmployeeManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<EmployeeController>();
    final auth = Get.find<AuthController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الموظفين'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: ctrl.loadEmployees,
          ),
          IconButton(
            icon: const Icon(Icons.person_add, color: AppTheme.accent),
            onPressed: () => _showEmployeeDialog(context, ctrl),
            tooltip: 'إضافة موظف',
          ),
        ],
      ),
      body: Obx(() {
        if (ctrl.isLoading.value && ctrl.employees.isEmpty) {
          return const Center(
              child: CircularProgressIndicator(color: AppTheme.accent));
        }
        if (ctrl.employees.isEmpty) {
          return const Center(
            child: Text('لا يوجد موظفون',
                style: TextStyle(color: AppTheme.textSecondary)),
          );
        }
        return RefreshIndicator(
          onRefresh: ctrl.loadEmployees,
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: ctrl.employees.length,
            itemBuilder: (_, i) {
              final emp = ctrl.employees[i];
              final isSelf = auth.currentEmployee.value?.id == emp.id;
              return _EmployeeTile(
                emp: emp,
                isSelf: isSelf,
                ctrl: ctrl,
                onEdit: () => _showEmployeeDialog(context, ctrl, emp: emp),
              );
            },
          ),
        );
      }),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'employee_fab',
        onPressed: () => _showEmployeeDialog(context, ctrl),
        backgroundColor: AppTheme.accent,
        icon: const Icon(Icons.person_add),
        label: const Text('إضافة موظف'),
      ),
    );
  }

  void _showEmployeeDialog(BuildContext context, EmployeeController ctrl,
      {EmployeeModel? emp}) {
    final isEdit = emp != null;
    final nameCtrl = TextEditingController(text: emp?.name ?? '');
    final userCtrl = TextEditingController(text: emp?.username ?? '');
    final passCtrl = TextEditingController();
    final pinCtrl  = TextEditingController(text: emp?.pin ?? '');
    String role = emp?.role ?? 'cashier';
    String? errorMsg;

    Get.dialog(
      StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: AppTheme.secondary,
          title: Text(isEdit ? 'تعديل موظف' : 'إضافة موظف جديد',
              style: const TextStyle(color: AppTheme.textPrimary)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    hintText: 'الاسم الكامل',
                    prefixIcon: Icon(Icons.person_outline,
                        color: AppTheme.textSecondary),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: userCtrl,
                  decoration: const InputDecoration(
                    hintText: 'اسم المستخدم',
                    prefixIcon: Icon(Icons.account_circle_outlined,
                        color: AppTheme.textSecondary),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: passCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: isEdit
                        ? 'كلمة مرور جديدة (اتركه فارغاً للإبقاء)'
                        : 'كلمة المرور',
                    prefixIcon: const Icon(Icons.lock_outline,
                        color: AppTheme.textSecondary),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: pinCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    hintText: 'رمز PIN (اختياري)',
                    prefixIcon:
                        Icon(Icons.dialpad, color: AppTheme.textSecondary),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 12),
                // Role dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: Builder(builder: (_) {
                      // Build the role list from the live API roles (falls
                      // back to a static list), and always include the
                      // employee's current role so editing a waiter/
                      // super_admin never trips the "exactly one item"
                      // DropdownButton assertion.
                      final base = ctrl.availableRoles.isNotEmpty
                          ? ctrl.availableRoles
                              .where((r) => r != 'super_admin')
                              .toList()
                          : List<String>.from(kSelectableRolesFallback);
                      final roles = <String>{...base, role}.toList();
                      return DropdownButton<String>(
                        value: role,
                        isExpanded: true,
                        dropdownColor: AppTheme.cardBg,
                        style: const TextStyle(
                            color: AppTheme.textPrimary, fontSize: 14),
                        items: roles
                            .map((r) => DropdownMenuItem(
                                  value: r,
                                  child: Text(roleLabelFor(r)),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => role = v ?? role),
                      );
                    }),
                  ),
                ),
                if (errorMsg != null) ...[
                  const SizedBox(height: 10),
                  Text(errorMsg!,
                      style: const TextStyle(
                          color: AppTheme.accent, fontSize: 12)),
                ],
              ],
            ),
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
                final username = userCtrl.text.trim();
                final password = passCtrl.text.trim();
                final pin = pinCtrl.text.trim();

                if (name.isEmpty || username.isEmpty) {
                  setState(() => errorMsg = 'الاسم واسم المستخدم مطلوبان');
                  return;
                }
                if (!isEdit && password.isEmpty) {
                  setState(() => errorMsg = 'كلمة المرور مطلوبة');
                  return;
                }

                String? err;

                if (isEdit) {
                  // Build data map — only include password if changed
                  final data = <String, dynamic>{
                    'name': name,
                    'username': username,
                    'role': role,
                    if (pin.isNotEmpty) 'pin': pin,
                    if (password.isNotEmpty) ...{
                      'password': password,
                      'password_confirmation': password,
                    },
                    'is_active': emp.isActive,
                  };
                  err = await ctrl.updateEmployee(emp, data);
                } else {
                  err = await ctrl.addEmployee(
                    username: username,
                    password: password,
                    name: name,
                    role: role,
                    pin: pin.isEmpty ? null : pin,
                  );
                }

                if (err != null) {
                  setState(() => errorMsg = err);
                } else {
                  Get.back();
                  Get.snackbar(
                    isEdit ? 'تم التعديل' : 'تمت الإضافة',
                    isEdit ? 'تم تعديل بيانات $name' : 'تمت إضافة $name بنجاح',
                    backgroundColor: AppTheme.success,
                    colorText: Colors.white,
                    snackPosition: SnackPosition.TOP,
                  );
                }
              },
              child: Text(isEdit ? 'حفظ' : 'إضافة'),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      // Dispose the dialog's text controllers so they aren't leaked
      // every time the add/edit dialog is opened.
      nameCtrl.dispose();
      userCtrl.dispose();
      passCtrl.dispose();
      pinCtrl.dispose();
    });
  }
}

class _EmployeeTile extends StatelessWidget {
  final EmployeeModel emp;
  final bool isSelf;
  final EmployeeController ctrl;
  final VoidCallback onEdit;

  const _EmployeeTile({
    required this.emp,
    required this.isSelf,
    required this.ctrl,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: emp.isActive
              ? AppTheme.divider
              : AppTheme.accent.withValues(alpha: 0.3),
        ),
      ),
      child: Opacity(
        opacity: emp.isActive ? 1.0 : 0.6,
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: _roleColor(emp.role).withValues(alpha: 0.2),
            child: Icon(_roleIcon(emp.role),
                color: _roleColor(emp.role), size: 20),
          ),
          title: Row(
            children: [
              Text(emp.name,
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600)),
              if (isSelf) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('أنت',
                      style:
                          TextStyle(color: AppTheme.success, fontSize: 10)),
                ),
              ],
            ],
          ),
          subtitle: Text(
            '@${emp.username} · ${_roleLabel(emp.role)}',
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 12),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Toggle active
              GestureDetector(
                onTap: isSelf ? null : () => ctrl.toggleActive(emp.id),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: emp.isActive
                        ? AppTheme.success.withValues(alpha: 0.15)
                        : AppTheme.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: emp.isActive
                            ? AppTheme.success.withValues(alpha: 0.4)
                            : AppTheme.accent.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    emp.isActive ? 'فعّال' : 'معطّل',
                    style: TextStyle(
                      color: emp.isActive
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
                    color: AppTheme.textSecondary, size: 18),
                onPressed: onEdit,
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              // Delete (not self)
              if (!isSelf)
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: AppTheme.accent, size: 18),
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
        content: Text('هل تريد حذف الموظف "${emp.name}"؟',
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
              final ok = await ctrl.deleteEmployee(emp.id);
              Get.snackbar(
                ok ? 'تم الحذف' : 'تعذر الحذف',
                ok
                    ? 'تم حذف "${emp.name}"'
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

  Color _roleColor(String role) {
    switch (role) {
      case 'admin':
      case 'super_admin':
        return AppTheme.accent;
      case 'manager':
        return AppTheme.accentGold;
      default:
        return AppTheme.success;
    }
  }

  IconData _roleIcon(String role) {
    switch (role) {
      case 'admin':
      case 'super_admin':
        return Icons.admin_panel_settings;
      case 'manager':
        return Icons.supervisor_account;
      case 'kitchen':
        return Icons.restaurant;
      case 'delivery':
        return Icons.delivery_dining;
      default:
        return Icons.point_of_sale;
    }
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'super_admin':
        return 'مدير النظام';
      case 'admin':
        return 'مدير عام';
      case 'manager':
        return 'مدير';
      case 'kitchen':
        return 'مطبخ';
      case 'delivery':
        return 'توصيل';
      default:
        return 'كاشير';
    }
  }
}