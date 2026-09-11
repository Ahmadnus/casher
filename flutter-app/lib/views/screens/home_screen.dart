import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/app_theme.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/invoice_controller.dart';
import 'cashier_screen.dart';
import 'dashboard_screen.dart';
import 'invoices_screen.dart';
import 'pending_orders_screen.dart';
import 'menu_management_screen.dart';
import 'reports_screen.dart';
import 'delivery_areas_screen.dart';
import 'employee_management_screen.dart';
import 'restaurant_settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final RxInt currentIndex = 0.obs;
    final auth = Get.find<AuthController>();

    return Obx(() {
      // Build tabs dynamically based on the logged-in employee's role
      final List<Widget> screens = [const CashierScreen(), const InvoicesScreen()];
      final List<BottomNavigationBarItem> items = const [
        BottomNavigationBarItem(
          icon: Icon(Icons.point_of_sale_outlined),
          activeIcon: Icon(Icons.point_of_sale),
          label: 'الكاشير',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.receipt_long_outlined),
          activeIcon: Icon(Icons.receipt_long),
          label: 'الفواتير',
        ),
      ];
      final navItems = List<BottomNavigationBarItem>.from(items);

      if (auth.canSeePendingOrders) {
        final invoiceCtrl = Get.find<InvoiceController>();
        screens.add(const PendingOrdersScreen());
        navItems.add(BottomNavigationBarItem(
          icon: _PendingOrdersIcon(invoiceCtrl: invoiceCtrl, filled: false),
          activeIcon: _PendingOrdersIcon(invoiceCtrl: invoiceCtrl, filled: true),
          label: 'الطلبات المعلقة',
        ));
      }

      if (auth.canManageMenu) {
        screens.add(const MenuManagementScreen());
        navItems.add(const BottomNavigationBarItem(
          icon: Icon(Icons.restaurant_menu_outlined),
          activeIcon: Icon(Icons.restaurant_menu),
          label: 'القائمة',
        ));
      }
      if (auth.canManageDeliveryAreas) {
        screens.add(const DeliveryAreasScreen());
        navItems.add(const BottomNavigationBarItem(
          icon: Icon(Icons.location_on_outlined),
          activeIcon: Icon(Icons.location_on),
          label: 'مناطق',
        ));
      }
      if (auth.canViewReports) {
        screens.add(const ReportsScreen());
        navItems.add(const BottomNavigationBarItem(
          icon: Icon(Icons.bar_chart_outlined),
          activeIcon: Icon(Icons.bar_chart),
          label: 'التقارير',
        ));
        screens.add(const DashboardScreen());
        navItems.add(const BottomNavigationBarItem(
          icon: Icon(Icons.dashboard_outlined),
          activeIcon: Icon(Icons.dashboard),
          label: 'الرئيسية',
        ));
      }

      // Clamp index if role changed and reduced tab count
      if (currentIndex.value >= screens.length) {
        currentIndex.value = 0;
      }

      return Scaffold(
        body: Column(
          children: [
            _EmployeeBar(auth: auth),
            Expanded(
              child: IndexedStack(
                index: currentIndex.value,
                children: screens,
              ),
            ),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: BottomNavigationBar(
            // fixed: keep every tab's label visible — with >3 items the
            // default "shifting" mode hides unselected labels, which is
            // confusing on a POS with many role-based tabs.
            type: BottomNavigationBarType.fixed,
            currentIndex: currentIndex.value,
            onTap: (i) => currentIndex.value = i,
            selectedItemColor: AppTheme.accent,
            unselectedItemColor: AppTheme.textSecondary,
            selectedFontSize: 11,
            unselectedFontSize: 10,
            items: navItems,
          ),
        ),
      );
    });
  }
}

class _EmployeeBar extends StatelessWidget {
  final AuthController auth;
  const _EmployeeBar({required this.auth});

  String _roleLabel(String? role) {
    switch (role) {
      case 'admin':
      case 'super_admin':
        return 'مدير عام';
      case 'manager':
        return 'مدير';
      case 'cashier':
        return 'كاشير';
      case 'waiter':
        return 'موظف الصالة';
      case 'kitchen':
        return 'مطبخ';
      case 'delivery':
        return 'توصيل';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final emp = auth.currentEmployee.value;
    return SafeArea(
      bottom: false,
      child: Container(
        height: 44,
        color: AppTheme.secondary,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            const Icon(Icons.account_circle,
                color: AppTheme.textSecondary, size: 20),
            const SizedBox(width: 8),
            Text(
              emp?.name ?? '',
              style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _roleLabel(emp?.role),
                style: const TextStyle(
                    color: AppTheme.accent, fontSize: 11),
              ),
            ),
            const Spacer(),
            if (auth.canManageEmployees) ...[
              IconButton(
                icon: const Icon(Icons.people_outline,
                    color: AppTheme.textSecondary, size: 20),
                tooltip: 'إدارة الموظفين',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const EmployeeManagementScreen()),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined,
                    color: AppTheme.textSecondary, size: 20),
                tooltip: 'إعدادات المطعم',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const RestaurantSettingsScreen()),
                ),
              ),
            ],
            IconButton(
              icon: const Icon(Icons.logout,
                  color: AppTheme.accent, size: 20),
              tooltip: 'تسجيل الخروج',
              onPressed: () => _confirmLogout(context),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.secondary,
        title: const Text('تسجيل الخروج',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text('هل تريد تسجيل الخروج؟',
            style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              auth.logout();
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );
  }
}

/// Bottom-nav icon with a live badge showing how many invoices are
/// waiting for payment — updates automatically as [InvoiceController]
/// polls every 5 seconds.
class _PendingOrdersIcon extends StatelessWidget {
  final InvoiceController invoiceCtrl;
  final bool filled;

  const _PendingOrdersIcon({required this.invoiceCtrl, required this.filled});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final count = invoiceCtrl.pendingInvoices.length;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(filled ? Icons.pending_actions : Icons.pending_actions_outlined),
          if (count > 0)
            Positioned(
              right: -6,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: AppTheme.accent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      );
    });
  }
}