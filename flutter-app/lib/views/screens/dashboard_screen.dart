import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../controllers/dashboard_controller.dart';
import '../../services/app_theme.dart';

/// Owner/manager overview: today's sales, month revenue, live counts and
/// top-selling items. Data comes fresh from GET /api/dashboard each time
/// the tab opens (and on pull-to-refresh).
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ctrl = Get.find<DashboardController>();

  @override
  void initState() {
    super.initState();
    ctrl.load();
  }

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat('#,##0.00');
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
              child: const Icon(Icons.dashboard, color: AppTheme.accent, size: 22),
            ),
            const SizedBox(width: 10),
            const Text('الرئيسية'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: ctrl.load,
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: Obx(() {
        if (ctrl.isLoading.value) {
          return const Center(
              child: CircularProgressIndicator(color: AppTheme.accent));
        }
        if (ctrl.error.value.isNotEmpty) {
          return _ErrorState(message: ctrl.error.value, onRetry: ctrl.load);
        }

        final d = ctrl.dashboard.value;
        return RefreshIndicator(
          onRefresh: ctrl.load,
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              // ── Headline: today's sales ──
              _HeroCard(
                label: 'مبيعات اليوم',
                value: '${money.format(d.todaySales)} د.أ',
                sub: '${d.todayInvoiceCount} فاتورة · ${d.todayOrders} طلب',
              ),
              const SizedBox(height: 12),

              // ── KPI grid ──
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.7,
                children: [
                  _KpiCard(
                    icon: Icons.calendar_month,
                    label: 'إيرادات الشهر',
                    value: '${money.format(d.revenueThisMonth)} د.أ',
                    color: AppTheme.accentGold,
                  ),
                  _KpiCard(
                    icon: Icons.pending_actions,
                    label: 'طلبات معلقة',
                    value: '${d.pendingOrdersCount}',
                    color: AppTheme.accent,
                  ),
                  _KpiCard(
                    icon: Icons.people_alt,
                    label: 'العملاء',
                    value: '${d.customersCount}',
                    color: AppTheme.success,
                  ),
                  _KpiCard(
                    icon: Icons.badge,
                    label: 'الموظفون',
                    value: '${d.employeesCount}',
                    color: const Color(0xFF9C27B0),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Top sellers ──
              Row(
                children: const [
                  Icon(Icons.trending_up, color: AppTheme.success, size: 20),
                  SizedBox(width: 8),
                  Text('الأكثر مبيعاً',
                      style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              if (d.topSellingItems.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('لا توجد مبيعات بعد',
                        style: TextStyle(color: AppTheme.textSecondary)),
                  ),
                )
              else
                ...d.topSellingItems.asMap().entries.map((e) => _TopItemTile(
                      rank: e.key + 1,
                      name: e.value.name,
                      qty: e.value.totalQuantity,
                      revenue: money.format(e.value.totalRevenue),
                    )),
            ],
          ),
        );
      }),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  const _HeroCard(
      {required this.label, required this.value, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.accent, AppTheme.accentGold],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(sub,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _KpiCard(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 22),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: color, fontSize: 18, fontWeight: FontWeight.bold)),
          Text(label,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}

class _TopItemTile extends StatelessWidget {
  final int rank;
  final String name;
  final int qty;
  final String revenue;
  const _TopItemTile(
      {required this.rank,
      required this.name,
      required this.qty,
      required this.revenue});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Center(
              child: Text('$rank',
                  style: const TextStyle(
                      color: AppTheme.success,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppTheme.textPrimary, fontSize: 14)),
          ),
          Text('$qty',
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(width: 10),
          Text('$revenue د.أ',
              style: const TextStyle(
                  color: AppTheme.accentGold,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline,
              size: 56, color: AppTheme.textSecondary),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textSecondary)),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }
}
