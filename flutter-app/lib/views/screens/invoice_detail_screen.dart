import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../models/invoice_model.dart';
import '../../services/app_theme.dart';
import '../../services/order_type_meta.dart';
import '../../services/printer_service.dart';
import '../../controllers/invoice_controller.dart';
import 'printer_settings_screen.dart';
import 'package:intl/intl.dart';

class InvoiceDetailScreen extends StatelessWidget {
  final InvoiceModel invoice;

  const InvoiceDetailScreen({super.key, required this.invoice});

  @override
  Widget build(BuildContext context) {
    final isDelivery = invoice.orderType == OrderType.delivery;
    final isDineIn = invoice.orderType == OrderType.dineIn;
    final fmt = NumberFormat('#,##0.00');

    return Scaffold(
      backgroundColor: AppTheme.primary,
      appBar: AppBar(
        title: Text('فاتورة #${invoice.invoiceNumber}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: 'طباعة الفاتورة',
            onPressed: () => _printInvoice(context, invoice),
          ),
          IconButton(
            icon: const Icon(Icons.point_of_sale_outlined),
            tooltip: 'طباعة إيصال كاش',
            onPressed: () => _printCashSlip(context, invoice),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'إعدادات الطابعات',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const PrinterSettingsScreen())),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header card ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _Badge(
                          label: 'فاتورة #${invoice.invoiceNumber}',
                          color: AppTheme.accent),
                      const SizedBox(width: 8),
                      _Badge(
                        label: OrderType.label(invoice.orderType),
                        color: OrderType.color(invoice.orderType),
                        icon: OrderType.icon(invoice.orderType),
                      ),
                      if (invoice.status != null) ...[
                        const SizedBox(width: 8),
                        _Badge(
                          label: invoice.status!,
                          color: invoice.status == 'paid'
                              ? AppTheme.success
                              : AppTheme.accent,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),
                  _Row(Icons.calendar_today, 'التاريخ',
                      DateFormat('dd/MM/yyyy').format(invoice.createdAt)),
                  _Row(Icons.access_time, 'الوقت',
                      DateFormat('hh:mm a').format(invoice.createdAt)),
                  _Row(Icons.shopping_bag_outlined, 'عدد العناصر',
                      '${invoice.itemCount} عنصر'),
                  if (invoice.employeeName != null &&
                      invoice.employeeName!.isNotEmpty)
                    _Row(Icons.badge_outlined, 'الموظف',
                        invoice.employeeName!),
                  if (invoice.customerName != null &&
                      invoice.customerName!.isNotEmpty)
                    _Row(Icons.person_outline, 'العميل',
                        invoice.customerName!),
                  if (invoice.customerPhone != null &&
                      invoice.customerPhone!.isNotEmpty)
                    _Row(Icons.phone, 'الهاتف', invoice.customerPhone!),
                  if (isDelivery) ...[
                    const Divider(color: AppTheme.divider, height: 20),
                    if (invoice.deliveryArea != null &&
                        invoice.deliveryArea!.isNotEmpty)
                      _Row(Icons.location_on, 'المنطقة',
                          invoice.deliveryArea!,
                          valueColor: AppTheme.accent),
                    if (invoice.deliveryAddress != null &&
                        invoice.deliveryAddress!.isNotEmpty)
                      _Row(Icons.home_outlined, 'العنوان',
                          invoice.deliveryAddress!),
                  ],
                  if (isDineIn &&
                      invoice.tableNumber != null &&
                      invoice.tableNumber!.isNotEmpty) ...[
                    const Divider(color: AppTheme.divider, height: 20),
                    _Row(Icons.table_bar, 'رقم الطاولة',
                        invoice.tableNumber!,
                        valueColor: AppTheme.accentGold),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Items table ──
            const Text('تفاصيل الطلب',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                        color: AppTheme.surface.withValues(alpha: 0.5),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12))),
                    child: const Row(
                      children: [
                        Expanded(
                            flex: 3,
                            child: Text('الصنف',
                                style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600))),
                        Expanded(
                            child: Text('الكمية',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600))),
                        Expanded(
                            child: Text('السعر',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600))),
                        Expanded(
                            child: Text('الإجمالي',
                                textAlign: TextAlign.end,
                                style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600))),
                      ],
                    ),
                  ),
                  for (int i = 0; i < invoice.items.length; i++)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: i % 2 != 0
                            ? AppTheme.surface.withValues(alpha: 0.08)
                            : Colors.transparent,
                        border: const Border(
                            top: BorderSide(
                                color: AppTheme.divider, width: 0.5)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                              flex: 3,
                              child: Text(invoice.items[i].name,
                                  style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 13))),
                          Expanded(
                              child: Text('${invoice.items[i].quantity}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 13))),
                          Expanded(
                              child: Text(
                                  fmt.format(invoice.items[i].price),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 12))),
                          Expanded(
                              child: Text(
                                  fmt.format(invoice.items[i].subtotal),
                                  textAlign: TextAlign.end,
                                  style: const TextStyle(
                                      color: AppTheme.accentGold,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600))),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Total ──
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('الإجمالي الكلي',
                      style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  Text('${fmt.format(invoice.total)} د.أ',
                      style: const TextStyle(
                          color: AppTheme.accent,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Mark paid (only while unpaid) ──
            if (invoice.status == 'unpaid') ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _confirmMarkPaid(context, invoice),
                  icon: const Icon(Icons.payments_outlined, size: 20),
                  label: const Text('تأكيد الدفع',
                      style: TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentGold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],

            // ── Print buttons ──
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _printInvoice(context, invoice),
                    icon: const Icon(Icons.receipt_long, size: 18),
                    label: const Text('طباعة الفاتورة'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.success,
                        padding:
                            const EdgeInsets.symmetric(vertical: 13)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _printCashSlip(context, invoice),
                    icon: const Icon(Icons.point_of_sale, size: 18),
                    label: const Text('إيصال كاش'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.accentGold,
                      side: const BorderSide(color: AppTheme.accentGold),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                  ),
                ),
              ],
            ),
            // Web only: browser print dialog as a fallback when the local
            // print agent is not installed on this computer.
            if (Get.find<PrinterService>().supportsBrowserPrint) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => _printInBrowser(context, invoice),
                icon: const Icon(Icons.open_in_browser, size: 18),
                label: const Text('طباعة عبر المتصفح (بديل)'),
                style: TextButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Print helpers ────────────────────────────────────────────────
Future<void> _printInvoice(
    BuildContext context, InvoiceModel invoice) async {
  final printer = Get.find<PrinterService>();
  if (printer.invoiceSavedId == null) {
    _showNoPrinter(context);
    return;
  }

  // Try to get enriched print data from API (includes restaurant settings)
  InvoiceModel printable = invoice;
  try {
    final ctrl = Get.find<InvoiceController>();
    final data = await ctrl.getPrintData(invoice.id);
    if (data != null && data['invoice'] != null) {
      printable = InvoiceModel.fromJson(
          data['invoice'] as Map<String, dynamic>);
    }
  } catch (_) {}

  if (!context.mounted) return;
  _showLoading(context, 'جاري طباعة الفاتورة...');
  final ok = await printer.printInvoice(printable);
  if (context.mounted) Navigator.pop(context);
  _showResult(ok, 'الفاتورة');
}

Future<void> _printInBrowser(
    BuildContext context, InvoiceModel invoice) async {
  final printer = Get.find<PrinterService>();
  InvoiceModel printable = invoice;
  try {
    final ctrl = Get.find<InvoiceController>();
    final data = await ctrl.getPrintData(invoice.id);
    if (data != null && data['invoice'] != null) {
      printable = InvoiceModel.fromJson(
          data['invoice'] as Map<String, dynamic>);
    }
  } catch (_) {}
  final ok = await printer.printInvoiceInBrowser(printable);
  if (!ok) {
    Get.snackbar('تعذرت الطباعة', 'المتصفح منع فتح نافذة الطباعة',
        backgroundColor: AppTheme.accent,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP);
  }
}

Future<void> _printCashSlip(
    BuildContext context, InvoiceModel invoice) async {
  final printer = Get.find<PrinterService>();
  if (printer.cashSavedId == null) {
    _showNoPrinter(context);
    return;
  }
  _showLoading(context, 'جاري طباعة إيصال الكاش...');
  final ok = await printer.printCashSlip(invoice);
  if (context.mounted) Navigator.pop(context);
  _showResult(ok, 'إيصال الكاش');
}

Future<void> _confirmMarkPaid(BuildContext context, InvoiceModel invoice) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: AppTheme.secondary,
      title: const Text('تأكيد الدفع',
          style: TextStyle(color: AppTheme.textPrimary)),
      content: Text(
        'تأكيد استلام الدفع لفاتورة #${invoice.invoiceNumber}؟',
        style: const TextStyle(color: AppTheme.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('إلغاء',
              style: TextStyle(color: AppTheme.textSecondary)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
          child: const Text('تأكيد'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;

  final ok = await Get.find<InvoiceController>().markPaid(invoice);
  if (context.mounted) {
    Get.snackbar(
      ok ? 'تم الدفع ✓' : 'فشل التأكيد',
      ok ? 'تم تأكيد دفع فاتورة #${invoice.invoiceNumber}' : 'حاول مرة أخرى',
      backgroundColor: ok ? AppTheme.success : AppTheme.accent,
      colorText: Colors.white,
      snackPosition: SnackPosition.TOP,
    );
    if (ok) Navigator.pop(context);
  }
}

void _showResult(bool ok, String label) {
  Get.snackbar(
    ok ? 'تمت الطباعة ✓' : 'فشل الطباعة',
    ok ? 'تم إرسال $label إلى الطابعة' : 'تحقق من اتصال الطابعة',
    backgroundColor: ok ? AppTheme.success : AppTheme.accent,
    colorText: Colors.white,
    snackPosition: SnackPosition.TOP,
    duration: const Duration(seconds: 3),
  );
}

void _showNoPrinter(BuildContext context) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: AppTheme.secondary,
      title: const Text('لا توجد طابعة',
          style: TextStyle(color: AppTheme.textPrimary)),
      content: const Text('لم يتم إعداد طابعة بعد.',
          style: TextStyle(color: AppTheme.textSecondary)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إغلاق',
              style: TextStyle(color: AppTheme.textSecondary)),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const PrinterSettingsScreen()),
            );
          },
          child: const Text('إعداد الطابعة'),
        ),
      ],
    ),
  );
}

void _showLoading(BuildContext context, String msg) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      backgroundColor: AppTheme.secondary,
      content: Row(
        children: [
          const CircularProgressIndicator(color: AppTheme.accent),
          const SizedBox(width: 16),
          Text(msg, style: const TextStyle(color: AppTheme.textPrimary)),
        ],
      ),
    ),
  );
}

// ── Sub-widgets ──────────────────────────────────────────────────
class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const _Badge({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  const _Row(this.icon, this.label, this.value, {this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: AppTheme.textSecondary),
          const SizedBox(width: 8),
          Text('$label: ',
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 13)),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    color: valueColor ?? AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
