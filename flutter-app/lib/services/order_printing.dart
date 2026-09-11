import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/invoice_model.dart';
import '../repositories/invoice_repository.dart';
import 'app_theme.dart';
import 'printer_service.dart';

/// Auto-printing fires ONLY on payment confirmation (markPaid) — never
/// at order creation. Both jobs run sequentially: the kitchen slip
/// (no prices) first, then the priced customer invoice; the printer
/// service switches its single USB connection between the two targets.
///
/// Fire-and-forget — the payment is already saved; a failed print only
/// shows a warning so the cashier can reprint from the invoice screen.
/// A target with no configured printer is skipped silently.
Future<void> autoPrintOnPayment(InvoiceModel invoice) async {
  try {
    final printer = Get.find<PrinterService>();

    // Enrich with the API print payload (restaurant settings, full
    // items) when available — same pattern as the manual print button.
    InvoiceModel printable = invoice;
    try {
      final data = await InvoiceRepository().getPrintData(invoice.id);
      if (data['invoice'] != null) {
        printable =
            InvoiceModel.fromJson(data['invoice'] as Map<String, dynamic>);
      }
    } catch (_) {}

    // 1) Kitchen slip (no prices) → cash/kitchen printer.
    final kitchenOk = printer.cashSavedId == null
        ? null
        : await printer.printCashSlip(printable);
    // 2) Customer invoice (with prices) → invoice printer.
    final customerOk = printer.invoiceSavedId == null
        ? null
        : await printer.printInvoice(printable);

    final failed = <String>[
      if (kitchenOk == false) 'طلب المطبخ',
      if (customerOk == false) 'فاتورة العميل',
    ];
    if (failed.isNotEmpty) _warnFailed(failed.join(' و '));
  } catch (_) {
    // Printing must never surface an exception into the payment flow.
  }
}

void _warnFailed(String what) {
  Get.snackbar(
    'تعذرت الطباعة التلقائية',
    'فشلت طباعة $what. يمكن إعادة الطباعة من شاشة الفاتورة.',
    backgroundColor: AppTheme.accent,
    colorText: Colors.white,
    icon: const Icon(Icons.print_disabled, color: Colors.white),
    duration: const Duration(seconds: 4),
    snackPosition: SnackPosition.TOP,
    margin: const EdgeInsets.all(12),
    borderRadius: 12,
  );
}
