import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/category_controller.dart';
import '../../controllers/reports_controller.dart';
import '../../models/channel_model.dart';
import '../../models/product_sales_model.dart';
import '../../services/app_theme.dart';
import '../../services/order_type_meta.dart';
import 'itemized_sales_screen.dart';
import 'package:intl/intl.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final ctrl = Get.find<ReportsController>();

  @override
  void initState() {
    super.initState();
    // Always show live numbers: re-fetch from the API on every open.
    ctrl.refreshCurrent();
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
              child: const Icon(Icons.bar_chart,
                  color: AppTheme.accent, size: 22),
            ),
            const SizedBox(width: 10),
            const Text('التقارير'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ctrl.applyFilter(ctrl.filter.value),
          ),
        ],
      ),
      body: Obx(() {
        return Column(
          children: [
            // ── Date filter tabs ──
            Container(
              color: AppTheme.secondary,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: [
                  _FilterTab(
                      label: 'اليوم',
                      filter: ReportFilter.today,
                      current: ctrl.filter.value,
                      onTap: () =>
                          ctrl.applyFilter(ReportFilter.today)),
                  const SizedBox(width: 5),
                  _FilterTab(
                      label: 'الأسبوع',
                      filter: ReportFilter.week,
                      current: ctrl.filter.value,
                      onTap: () =>
                          ctrl.applyFilter(ReportFilter.week)),
                  const SizedBox(width: 5),
                  _FilterTab(
                      label: 'الشهر',
                      filter: ReportFilter.month,
                      current: ctrl.filter.value,
                      onTap: () =>
                          ctrl.applyFilter(ReportFilter.month)),
                  const SizedBox(width: 5),
                  _FilterTab(
                      label: 'مخصص',
                      filter: ReportFilter.custom,
                      current: ctrl.filter.value,
                      onTap: () =>
                          _showCustomRange(Get.context!, ctrl)),
                ],
              ),
            ),
            // ── Order source filter: [الكل] [كوفي شوب] [طلبات] [أطلب] [أخرى] … ──
            Container(
              color: AppTheme.secondary,
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: OrderType.all.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                  itemBuilder: (_, i) {
                    final code = i == 0 ? null : OrderType.all[i - 1];
                    final selected = ctrl.channelFilter.value == code;
                    return _SourceChip(
                      label: code == null ? 'الكل' : OrderType.label(code),
                      icon: code == null ? Icons.all_inclusive : OrderType.icon(code),
                      color: code == null
                          ? AppTheme.accentGold
                          : OrderType.color(code),
                      selected: selected,
                      onTap: () => ctrl.setChannelFilter(code),
                    );
                  },
                ),
              ),
            ),

            if (ctrl.filter.value == ReportFilter.custom &&
                ctrl.customFrom.value != null)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 6),
                color: AppTheme.accent.withValues(alpha: 0.08),
                child: Row(
                  children: [
                    const Icon(Icons.date_range,
                        size: 14, color: AppTheme.accent),
                    const SizedBox(width: 6),
                    Text(
                      '${DateFormat('dd/MM/yyyy').format(ctrl.customFrom.value!)} - ${ctrl.customTo.value != null ? DateFormat('dd/MM/yyyy').format(ctrl.customTo.value!) : 'الآن'}',
                      style: const TextStyle(
                          color: AppTheme.accent, fontSize: 12),
                    ),
                  ],
                ),
              ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  // ── One-click daily reconciliation list ──
                  _DailyItemizedButton(
                      onTap: () =>
                          Get.toNamed(ItemizedSalesScreen.route)),
                  const SizedBox(height: 10),

                  // ── Main stats ──
                  Row(
                    children: [
                      Expanded(
                          child: _StatCard(
                        icon: Icons.attach_money,
                        label: 'إجمالي المبيعات',
                        value:
                            '${NumberFormat('#,##0.00').format(ctrl.totalSales.value)} د.أ',
                        color: AppTheme.accentGold,
                      )),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _StatCard(
                        icon: Icons.receipt_long,
                        label: 'عدد الفواتير',
                        value: '${ctrl.invoiceCount}',
                        color: AppTheme.accent,
                      )),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                          child: _StatCard(
                        icon: Icons.calculate,
                        label: 'متوسط الفاتورة',
                        value:
                            '${NumberFormat('#,##0.00').format(ctrl.averageInvoice.value)} د.أ',
                        color: AppTheme.success,
                      )),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _StatCard(
                        icon: Icons.shopping_bag,
                        label: 'إجمالي الأصناف',
                        value:
                            '${ctrl.totalItems}',
                        color: const Color(0xFF9C27B0),
                      )),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // ── Delivery stats ──
                  Row(
                    children: [
                      Expanded(
                          child: _StatCard(
                        icon: Icons.delivery_dining,
                        label: 'طلبات توصيل',
                        value: '${ctrl.deliveryCount}',
                        color: AppTheme.accent,
                      )),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _StatCard(
                        icon: Icons.store,
                        label: 'طلبات استلام',
                        value: '${ctrl.pickupCount}',
                        color: AppTheme.success,
                      )),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _StatCard(
                    icon: Icons.local_shipping,
                    label: 'مبيعات التوصيل',
                    value:
                        '${NumberFormat('#,##0.00').format(ctrl.deliverySales.value)} د.أ',
                    color: AppTheme.accent,
                    wide: true,
                  ),
                  const SizedBox(height: 16),

                  // ── Revenue by order source ──
                  if (ctrl.sourceRows.isNotEmpty) ...[
                    _SectionHeader(
                        icon: Icons.hub_outlined,
                        label: 'الإيرادات حسب مصدر الطلب',
                        color: AppTheme.accentGold),
                    const SizedBox(height: 8),
                    _SourceSummaryTable(
                      rows: ctrl.sourceRows,
                      total: ctrl.totalSales.value,
                      totalCount: ctrl.invoiceCount.value,
                    ),
                    const SizedBox(height: 10),
                    ...ctrl.sourceRows
                        .where((c) => c.invoiceCount > 0)
                        .map((c) => _ChannelTile(
                              channel: c,
                              selected:
                                  ctrl.channelFilter.value == c.channelCode,
                              onTap: () => ctrl.setChannelFilter(
                                ctrl.channelFilter.value == c.channelCode
                                    ? null
                                    : c.channelCode,
                              ),
                            )),
                    // Commission only matters when a platform actually took a
                    // cut, so keep the net card out of the way otherwise.
                    if (ctrl.totalCommission.value > 0) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                              child: _StatCard(
                            icon: Icons.percent,
                            label: 'عمولة المنصات',
                            value:
                                '${NumberFormat('#,##0.00').format(ctrl.totalCommission.value)} د.أ',
                            color: AppTheme.warning,
                          )),
                          const SizedBox(width: 10),
                          Expanded(
                              child: _StatCard(
                            icon: Icons.account_balance_wallet_outlined,
                            label: 'الصافي بعد العمولة',
                            value:
                                '${NumberFormat('#,##0.00').format(ctrl.totalNetSales.value)} د.أ',
                            color: AppTheme.success,
                          )),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                  ],

                  // ── Product sales × order source (weekly stock-taking) ──
                  _SectionHeader(
                      icon: Icons.inventory_2_outlined,
                      label: 'مبيعات الأصناف حسب المصدر',
                      color: AppTheme.success),
                  const SizedBox(height: 8),
                  _ProductPivotFilters(ctrl: ctrl),
                  const SizedBox(height: 8),
                  if (ctrl.productSalesLoading.value)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(
                          child: CircularProgressIndicator(
                              color: AppTheme.accent)),
                    )
                  else
                    _ProductPivotTable(
                      columns: ctrl.pivotColumns,
                      rows: ctrl.pivotRows,
                      report: ctrl.productSales.value,
                    ),
                  const SizedBox(height: 16),

                  // ── Most ordered ──
                  if (ctrl.mostOrdered.isNotEmpty) ...[
                    _SectionHeader(
                        icon: Icons.trending_up,
                        label: 'الأكثر طلباً',
                        color: AppTheme.success),
                    const SizedBox(height: 8),
                    ...ctrl.mostOrdered.asMap().entries.map((e) =>
                        _RankTile(
                            rank: e.key + 1,
                            name: e.value.key,
                            count: e.value.value,
                            isTop: true)),
                    const SizedBox(height: 16),
                  ],

                  // ── Least ordered ──
                  if (ctrl.leastOrdered.isNotEmpty &&
                      ctrl.itemFrequency.length > 1) ...[
                    _SectionHeader(
                        icon: Icons.trending_down,
                        label: 'الأقل طلباً',
                        color: AppTheme.accent),
                    const SizedBox(height: 8),
                    ...ctrl.leastOrdered.asMap().entries.map((e) =>
                        _RankTile(
                            rank: e.key + 1,
                            name: e.value.key,
                            count: e.value.value,
                            isTop: false)),
                  ],

                  if (ctrl.invoiceCount.value == 0)
                    const Padding(
                      padding: EdgeInsets.all(40),
                      child: Column(
                        children: [
                          Icon(Icons.bar_chart,
                              size: 60,
                              color: AppTheme.textSecondary),
                          SizedBox(height: 12),
                          Text('لا توجد بيانات في هذه الفترة',
                              style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 16)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }

  void _showCustomRange(
      BuildContext context, ReportsController ctrl) async {
    DateTime? from;
    DateTime? to;
    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: AppTheme.secondary,
          title: const Text('نطاق مخصص',
              style: TextStyle(color: AppTheme.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  'من: ${from != null ? DateFormat('dd/MM/yyyy').format(from!) : 'اختر'}',
                  style:
                      const TextStyle(color: AppTheme.textPrimary),
                ),
                trailing: const Icon(Icons.calendar_today,
                    color: AppTheme.accent, size: 20),
                onTap: () async {
                  final p = await showDatePicker(
                    context: ctx,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (p != null) setState(() => from = p);
                },
              ),
              ListTile(
                title: Text(
                  'إلى: ${to != null ? DateFormat('dd/MM/yyyy').format(to!) : 'اختر'}',
                  style:
                      const TextStyle(color: AppTheme.textPrimary),
                ),
                trailing: const Icon(Icons.calendar_today,
                    color: AppTheme.accent, size: 20),
                onTap: () async {
                  final p = await showDatePicker(
                    context: ctx,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (p != null) setState(() => to = p);
                },
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
              onPressed: () {
                ctrl.applyFilter(ReportFilter.custom,
                    from: from, to: to);
                Get.back();
              },
              child: const Text('تطبيق'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Prominent card that opens the consolidated daily itemized list
/// (جرد مبيعات اليوم) in one tap, independent of the active filters.
class _DailyItemizedButton extends StatelessWidget {
  final VoidCallback onTap;
  const _DailyItemizedButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.success.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.inventory_2,
                  color: AppTheme.success, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('مبيعات الأصناف بالكمية',
                      style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                  SizedBox(height: 2),
                  Text('اليوم / الأسبوع / الشهر — كميات فقط بدون أسعار أو زبائن',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.chevron_left,
                color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _FilterTab extends StatelessWidget {
  final String label;
  final ReportFilter filter;
  final ReportFilter current;
  final VoidCallback onTap;

  const _FilterTab(
      {required this.label,
      required this.filter,
      required this.current,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final sel = filter == current;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: sel ? AppTheme.accent : AppTheme.cardBg,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color:
                    sel ? Colors.white : AppTheme.textSecondary,
                fontSize: 12,
                fontWeight:
                    sel ? FontWeight.bold : FontWeight.normal,
              )),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool wide;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: wide
          ? Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value,
                        style: TextStyle(
                          color: color,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        )),
                    Text(label,
                        style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12)),
                  ],
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(height: 10),
                Text(value,
                    style: TextStyle(
                      color: color,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    )),
                const SizedBox(height: 2),
                Text(label,
                    style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11)),
              ],
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _SectionHeader(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
      ],
    );
  }
}

/// One row of the per-channel sales breakdown. Tapping it filters the whole
/// report down to that channel (tap again to clear), which is how a manager
/// pulls an independent "Talabaty only" or "Eshyai only" report.
class _ChannelTile extends StatelessWidget {
  final ChannelSalesModel channel;
  final bool selected;
  final VoidCallback onTap;

  const _ChannelTile({
    required this.channel,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = OrderType.color(channel.channelCode);
    final money = NumberFormat('#,##0.00');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : AppTheme.divider,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(OrderType.icon(channel.channelCode),
                    color: color, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(channel.displayName,
                          style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 15)),
                      Text(
                        '${channel.invoiceCount} فاتورة'
                        '${channel.commission > 0 ? ' — عمولة ${money.format(channel.commission)} د.أ' : ''}',
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${money.format(channel.totalSales)} د.أ',
                        style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                    // Net differs from gross only on commissioned channels.
                    if (channel.commission > 0)
                      Text('صافي ${money.format(channel.netSales)}',
                          style: const TextStyle(
                              color: AppTheme.success, fontSize: 11)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Share of total sales — the at-a-glance channel mix.
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: (channel.sharePercent / 100).clamp(0.0, 1.0),
                minHeight: 5,
                backgroundColor: AppTheme.divider,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('${channel.sharePercent.toStringAsFixed(1)}%',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 11)),
            ),
          ],
        ),
      ),
    );
  }
}

/// One order-source chip in the filter row.
class _SourceChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _SourceChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.2) : AppTheme.cardBg,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: selected ? color : Colors.transparent),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: selected ? color : AppTheme.textSecondary),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                  color: selected ? color : AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                )),
          ],
        ),
      ),
    );
  }
}

/// Compact "source → orders / revenue" table with a total row, so the split
/// is readable at a glance before the detailed per-channel tiles.
class _SourceSummaryTable extends StatelessWidget {
  final List<ChannelSalesModel> rows;
  final double total;
  final int totalCount;

  const _SourceSummaryTable({
    required this.rows,
    required this.total,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat('#,##0.00');
    TextStyle head = const TextStyle(
        color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600);
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          Row(children: [
            Expanded(flex: 3, child: Text('المصدر', style: head)),
            Expanded(flex: 2, child: Text('الطلبات', style: head, textAlign: TextAlign.center)),
            Expanded(flex: 3, child: Text('الإيراد', style: head, textAlign: TextAlign.end)),
          ]),
          const Divider(height: 12, color: AppTheme.divider),
          ...rows.map((c) {
            final color = OrderType.color(c.channelCode);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Expanded(
                  flex: 3,
                  child: Row(children: [
                    Icon(OrderType.icon(c.channelCode), size: 15, color: color),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(OrderType.label(c.channelCode),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppTheme.textPrimary, fontSize: 13)),
                    ),
                  ]),
                ),
                Expanded(
                  flex: 2,
                  child: Text('${c.invoiceCount}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: AppTheme.textPrimary, fontSize: 13)),
                ),
                Expanded(
                  flex: 3,
                  child: Text('${money.format(c.totalSales)} د.أ',
                      textAlign: TextAlign.end,
                      style: TextStyle(
                          color: c.totalSales > 0 ? color : AppTheme.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ),
              ]),
            );
          }),
          const Divider(height: 12, color: AppTheme.divider),
          Row(children: [
            const Expanded(
                flex: 3,
                child: Text('الإجمالي',
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold))),
            Expanded(
                flex: 2,
                child: Text('$totalCount',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold))),
            Expanded(
                flex: 3,
                child: Text('${money.format(total)} د.أ',
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                        color: AppTheme.accentGold,
                        fontSize: 14,
                        fontWeight: FontWeight.bold))),
          ]),
        ],
      ),
    );
  }
}

/// Category dropdown + product search for the pivot table.
class _ProductPivotFilters extends StatelessWidget {
  final ReportsController ctrl;
  const _ProductPivotFilters({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final cats = Get.isRegistered<CategoryController>()
        ? Get.find<CategoryController>().categories
        : const [];
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: TextField(
            onChanged: ctrl.setProductSearch,
            style: const TextStyle(fontSize: 13),
            decoration: const InputDecoration(
              isDense: true,
              prefixIcon: Icon(Icons.search, size: 18),
              hintText: 'بحث عن صنف',
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: Obx(() => DropdownButtonFormField<int?>(
                initialValue: ctrl.categoryFilter.value,
                isDense: true,
                dropdownColor: AppTheme.secondary,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                ),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('كل الفئات')),
                  ...cats.map((c) => DropdownMenuItem<int?>(
                      value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis))),
                ],
                onChanged: ctrl.setCategoryFilter,
              )),
        ),
      ],
    );
  }
}

/// Product × order-source pivot:
///
///   الصنف | كوفي شوب | طلبات | أطلب | أخرى | الإجمالي
///
/// Quantities come from invoice_items of paid invoices (server aggregated).
/// Horizontally scrollable so extra channels never squash the columns.
class _ProductPivotTable extends StatelessWidget {
  final List<ProductSalesChannel> columns;
  final List<ProductSalesRow> rows;
  final ProductSalesReport report;

  const _ProductPivotTable({
    required this.columns,
    required this.rows,
    required this.report,
  });

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.divider),
        ),
        child: const Center(
          child: Text('لا توجد أصناف مباعة في هذه الفترة',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        ),
      );
    }

    const cell = TextStyle(color: AppTheme.textPrimary, fontSize: 13);
    const head = TextStyle(
        color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w700);

    // Column totals for the visible rows (search may hide some products).
    final colTotals = {
      for (final c in columns) c.code: rows.fold<int>(0, (s, r) => s + r.qty(c.code))
    };
    final grand = rows.fold<int>(0, (s, r) => s + r.totalQuantity);
    final grandRevenue = rows.fold<double>(0, (s, r) => s + r.totalRevenue);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 40,
          dataRowMinHeight: 36,
          dataRowMaxHeight: 40,
          columnSpacing: 18,
          horizontalMargin: 12,
          dividerThickness: 0.5,
          columns: [
            const DataColumn(label: Text('الصنف', style: head)),
            ...columns.map((c) => DataColumn(
                  numeric: true,
                  label: Row(children: [
                    Icon(OrderType.icon(c.code), size: 13, color: OrderType.color(c.code)),
                    const SizedBox(width: 4),
                    Text(OrderType.label(c.code),
                        style: head.copyWith(color: OrderType.color(c.code))),
                  ]),
                )),
            const DataColumn(numeric: true, label: Text('الإجمالي', style: head)),
            const DataColumn(numeric: true, label: Text('الإيراد', style: head)),
          ],
          rows: [
            ...rows.map((r) => DataRow(cells: [
                  DataCell(ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 160),
                    child: Text(r.name, overflow: TextOverflow.ellipsis, style: cell),
                  )),
                  ...columns.map((c) {
                    final q = r.qty(c.code);
                    return DataCell(Text('$q',
                        style: cell.copyWith(
                            color: q == 0 ? AppTheme.textSecondary : AppTheme.textPrimary)));
                  }),
                  DataCell(Text('${r.totalQuantity}',
                      style: cell.copyWith(
                          fontWeight: FontWeight.bold, color: AppTheme.accentGold))),
                  DataCell(Text(NumberFormat('#,##0.00').format(r.totalRevenue),
                      style: cell.copyWith(color: AppTheme.success))),
                ])),
            DataRow(
              color: WidgetStateProperty.all(AppTheme.secondary),
              cells: [
                const DataCell(Text('الإجمالي',
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold))),
                ...columns.map((c) => DataCell(Text('${colTotals[c.code] ?? 0}',
                    style: cell.copyWith(
                        fontWeight: FontWeight.bold, color: OrderType.color(c.code))))),
                DataCell(Text('$grand',
                    style: cell.copyWith(
                        fontWeight: FontWeight.bold, color: AppTheme.accentGold))),
                DataCell(Text(NumberFormat('#,##0.00').format(grandRevenue),
                    style: cell.copyWith(
                        fontWeight: FontWeight.bold, color: AppTheme.success))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RankTile extends StatelessWidget {
  final int rank;
  final String name;
  final int count;
  final bool isTop;
  const _RankTile(
      {required this.rank,
      required this.name,
      required this.count,
      required this.isTop});

  @override
  Widget build(BuildContext context) {
    final color = isTop ? AppTheme.success : AppTheme.accent;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Center(
              child: Text('$rank',
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Text(name,
                  style: const TextStyle(
                      color: AppTheme.textPrimary, fontSize: 14))),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('$count طلب',
                style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}