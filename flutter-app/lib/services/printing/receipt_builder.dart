import 'dart:typed_data';

import 'package:intl/intl.dart';

import '../../models/invoice_model.dart';
import '../../models/settings_model.dart';
import '../order_type_meta.dart';

/// Builds the ESC/POS byte streams for every ticket the POS prints.
///
/// Pure Dart, no platform APIs: the exact same bytes are produced on desktop
/// (sent through the USB plugin) and on web (sent to the local print agent),
/// so a receipt looks identical regardless of where the POS runs.
///
/// The layout is byte-for-byte what the desktop app printed before the web
/// port; only the location of the code changed.
class ReceiptBuilder {
  final SettingsModel? settings;

  const ReceiptBuilder({this.settings});

  /// Real restaurant name from Settings (falls back to a neutral label),
  /// so receipts never print a hardcoded placeholder for the client.
  String get _restaurantName {
    final n = settings?.name.trim() ?? '';
    return n.isNotEmpty ? n : 'مطعم';
  }

  /// Arabic label for every order source. Delegates to the shared channel
  /// metadata so a newly added channel is never silently printed as "استلام".
  String _typeLabel(String t) => OrderType.label(t);

  // ── Full invoice receipt ───────────────────────────────────────
  Uint8List invoice(InvoiceModel invoice) {
    final fmt = NumberFormat('#,##0.00');
    final dateFmt = DateFormat('dd/MM/yyyy hh:mm a');
    final buf = <int>[];

    void cmd(List<int> b) => buf.addAll(b);
    void text(String s) => buf.addAll(s.codeUnits);
    void nl([int n = 1]) {
      for (int i = 0; i < n; i++) {
        buf.add(0x0A);
      }
    }

    void divider([String c = '-']) => text(c * 32);

    cmd([0x1B, 0x40]); // reset
    cmd([0x1B, 0x61, 0x01]); // center
    cmd([0x1B, 0x45, 0x01]); // bold on
    cmd([0x1D, 0x21, 0x11]); // double size
    text(_restaurantName);
    nl();
    cmd([0x1D, 0x21, 0x00]);
    cmd([0x1B, 0x45, 0x00]);
    final s = settings;
    if ((s?.address ?? '').trim().isNotEmpty) {
      text(s!.address!.trim());
      nl();
    }
    if ((s?.phone ?? '').trim().isNotEmpty) {
      text('هاتف: ${s!.phone!.trim()}');
      nl();
    }
    text('فاتورة #${invoice.invoiceNumber}');
    nl();
    text(dateFmt.format(invoice.createdAt));
    nl();
    text('[ ${_typeLabel(invoice.orderType)} ]');
    nl();
    if (invoice.orderType == OrderType.dineIn &&
        (invoice.tableNumber?.isNotEmpty ?? false)) {
      text('طاولة: ${invoice.tableNumber}');
      nl();
    }
    // Platform order id on third-party tickets, so the kitchen and the
    // driver can match this ticket against the aggregator's app.
    if (invoice.isThirdParty &&
        (invoice.externalReference?.isNotEmpty ?? false)) {
      text('${_typeLabel(invoice.orderType)} #${invoice.externalReference}');
      nl();
    }
    if (invoice.employeeName != null && invoice.employeeName!.isNotEmpty) {
      text('الموظف: ${invoice.employeeName}');
      nl();
    }
    divider();
    nl();

    cmd([0x1B, 0x61, 0x02]); // right align
    if (invoice.customerName?.isNotEmpty == true) {
      text('الاسم: ${invoice.customerName}');
      nl();
    }
    if (invoice.customerPhone?.isNotEmpty == true) {
      text('الهاتف: ${invoice.customerPhone}');
      nl();
    }
    if (invoice.orderType == OrderType.delivery) {
      if (invoice.deliveryArea?.isNotEmpty == true) {
        text('المنطقة: ${invoice.deliveryArea}');
        nl();
      }
      if (invoice.deliveryAddress?.isNotEmpty == true) {
        text('العنوان: ${invoice.deliveryAddress}');
        nl();
      }
    }

    cmd([0x1B, 0x61, 0x00]); // left align
    divider();
    nl();
    text('الصنف              الكمية   السعر');
    nl();
    divider();
    nl();

    for (final item in invoice.items) {
      final name = item.name.length > 18
          ? '${item.name.substring(0, 15)}...'
          : item.name;
      final qty = 'x${item.quantity}'.padLeft(6);
      final price = fmt.format(item.subtotal).padLeft(9);
      text('$name$qty$price');
      nl();
    }

    divider();
    nl();

    // Subtotal + delivery fee breakdown (right-aligned) so the customer
    // sees what makes up the total, not just the final number.
    cmd([0x1B, 0x61, 0x02]); // right align
    if ((invoice.subtotal ?? 0) > 0) {
      text('المجموع الفرعي: ${fmt.format(invoice.subtotal)} د.أ');
      nl();
    }
    if ((invoice.deliveryFee ?? 0) > 0) {
      text('رسوم التوصيل: ${fmt.format(invoice.deliveryFee)} د.أ');
      nl();
    }
    cmd([0x1B, 0x61, 0x00]); // left align

    divider('=');
    nl();

    cmd([0x1B, 0x61, 0x01]); // center
    cmd([0x1B, 0x45, 0x01]); // bold
    text('الإجمالي: ${fmt.format(invoice.total)} د.أ');
    nl();
    cmd([0x1B, 0x45, 0x00]);
    divider('=');
    nl();
    final footer = (settings?.receiptFooter ?? '').trim();
    text(footer.isNotEmpty ? footer : 'شكراً لزيارتكم!');
    nl(4);

    cmd([0x1D, 0x56, 0x41, 0x03]); // cut
    return Uint8List.fromList(buf);
  }

  // ── Short cash / kitchen slip ──────────────────────────────────
  Uint8List cashSlip(InvoiceModel invoice) {
    final dateFmt = DateFormat('dd/MM hh:mm a');
    final buf = <int>[];

    void cmd(List<int> b) => buf.addAll(b);
    void text(String s) => buf.addAll(s.codeUnits);
    void nl([int n = 1]) {
      for (int i = 0; i < n; i++) {
        buf.add(0x0A);
      }
    }

    void divider([String c = '-']) => text(c * 32);

    cmd([0x1B, 0x40]); // reset
    cmd([0x1B, 0x61, 0x01]); // center
    cmd([0x1B, 0x45, 0x01]);
    cmd([0x1D, 0x21, 0x11]);
    text('طلب كاش / مطبخ');
    nl();
    cmd([0x1D, 0x21, 0x00]);
    cmd([0x1B, 0x45, 0x00]);
    text('#${invoice.invoiceNumber}  ${dateFmt.format(invoice.createdAt)}');
    nl();
    text('[ ${_typeLabel(invoice.orderType)} ]');
    nl();
    if (invoice.orderType == OrderType.dineIn &&
        (invoice.tableNumber?.isNotEmpty ?? false)) {
      text('طاولة: ${invoice.tableNumber}');
      nl();
    }
    if (invoice.isThirdParty &&
        (invoice.externalReference?.isNotEmpty ?? false)) {
      text('${_typeLabel(invoice.orderType)} #${invoice.externalReference}');
      nl();
    }
    if (invoice.customerName?.isNotEmpty == true) {
      text(invoice.customerName!);
      nl();
    }
    divider();
    nl();

    cmd([0x1B, 0x61, 0x00]); // left
    for (final item in invoice.items) {
      text('x${item.quantity}  ${item.name}');
      nl();
    }

    divider();
    nl();
    nl(3);
    cmd([0x1D, 0x56, 0x41, 0x03]); // cut
    return Uint8List.fromList(buf);
  }

  // ── Test ticket ────────────────────────────────────────────────
  Uint8List test(String label) {
    final buf = <int>[];
    buf.addAll([0x1B, 0x40]);
    buf.addAll([0x1B, 0x61, 0x01]);
    buf.addAll('Test Print OK\n'.codeUnits);
    buf.addAll('$label\n'.codeUnits);
    buf.addAll('Printer Connected!\n'.codeUnits);
    buf.addAll('----------------------------\n'.codeUnits);
    buf.addAll([0x0A, 0x0A, 0x0A]);
    buf.addAll([0x1D, 0x56, 0x41, 0x03]);
    return Uint8List.fromList(buf);
  }
}
