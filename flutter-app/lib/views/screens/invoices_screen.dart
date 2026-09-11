import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/invoice_controller.dart';
import '../../services/app_theme.dart';
import '../../services/order_type_meta.dart';
import '../../widgets/invoice_tile.dart';
import 'package:intl/intl.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  final InvoiceController ctrl = Get.find<InvoiceController>();
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    ctrl.loadInvoices();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
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
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.receipt_long,
                  color: AppTheme.accent, size: 22),
            ),
            const SizedBox(width: 10),
            const Text('الفواتير'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _searchCtrl.clear();
              ctrl.clearFilters();
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) {
                ctrl.searchQuery.value = v;
                ctrl.loadInvoices();
              },
              decoration: const InputDecoration(
                hintText: 'بحث برقم الفاتورة أو اسم العميل...',
                prefixIcon:
                    Icon(Icons.search, color: AppTheme.textSecondary),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          _buildChannelTabs(),
          Expanded(child: Obx(() => _buildList())),
        ],
      ),
    );
  }

  /// Channel selector. Picking a channel re-queries the API filtered to it,
  /// so "طلباتي" and "اشيائي" each become their own invoice list rather than
  /// a client-side filter over one page of mixed results.
  Widget _buildChannelTabs() {
    const tabs = <String?>[
      null, // الكل
      ...OrderType.all,
    ];

    return SizedBox(
      height: 42,
      child: Obx(() {
        final active = ctrl.orderTypeFilter.value;
        return ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: tabs.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final code = tabs[i];
            final isAll = code == null;
            final selected = isAll ? active.isEmpty : active == code;
            final color = isAll ? AppTheme.accent : OrderType.color(code);

            return GestureDetector(
              onTap: () => ctrl.setChannelFilter(code),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: selected ? color : AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(21),
                  border: Border.all(
                      color: selected ? color : AppTheme.divider),
                ),
                child: Row(
                  children: [
                    Icon(isAll ? Icons.receipt_long : OrderType.icon(code),
                        size: 16,
                        color: selected
                            ? Colors.white
                            : AppTheme.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      isAll ? 'الكل' : OrderType.label(code),
                      style: TextStyle(
                        color: selected
                            ? Colors.white
                            : AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }),
    );
  }

  Widget _buildList() {
    if (ctrl.isLoading.value && ctrl.invoices.isEmpty) {
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.accent));
    }

    if (ctrl.invoices.isEmpty) {
      // Name the channel, so an empty Talabaty tab reads as "no Talabaty
      // invoices" rather than looking like the whole list failed to load.
      final channel = ctrl.activeChannelLabel;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.receipt_long,
                size: 60, color: AppTheme.textSecondary),
            const SizedBox(height: 12),
            Text(channel == null ? 'لا توجد فواتير' : 'لا توجد فواتير $channel',
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 16)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      itemCount: ctrl.invoices.length,
      itemBuilder: (_, i) => InvoiceTile(invoice: ctrl.invoices[i]),
    );
  }

  void _showFilterDialog(BuildContext context) {
    DateTime? from = ctrl.filterFrom.value;
    DateTime? to = ctrl.filterTo.value;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: AppTheme.secondary,
          title: const Text('تصفية بالتاريخ',
              style: TextStyle(color: AppTheme.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  'من: ${from != null ? DateFormat('dd/MM/yyyy').format(from!) : 'غير محدد'}',
                  style: const TextStyle(color: AppTheme.textPrimary),
                ),
                trailing: const Icon(Icons.calendar_today,
                    color: AppTheme.accent, size: 20),
                onTap: () async {
                  final p = await showDatePicker(
                      context: ctx,
                      initialDate: from ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now());
                  if (p != null) setDlgState(() => from = p);
                },
              ),
              ListTile(
                title: Text(
                  'إلى: ${to != null ? DateFormat('dd/MM/yyyy').format(to!) : 'غير محدد'}',
                  style: const TextStyle(color: AppTheme.textPrimary),
                ),
                trailing: const Icon(Icons.calendar_today,
                    color: AppTheme.accent, size: 20),
                onTap: () async {
                  final p = await showDatePicker(
                      context: ctx,
                      initialDate: to ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now());
                  if (p != null) setDlgState(() => to = p);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                ctrl.clearFilters();
                Navigator.pop(ctx);
              },
              child: const Text('مسح',
                  style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                ctrl.filterFrom.value = from;
                ctrl.filterTo.value = to;
                ctrl.loadInvoices();
                Navigator.pop(ctx);
              },
              child: const Text('تطبيق'),
            ),
          ],
        ),
      ),
    );
  }
}
