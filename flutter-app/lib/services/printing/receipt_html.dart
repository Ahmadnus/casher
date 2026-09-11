import 'package:intl/intl.dart';

import '../../models/invoice_model.dart';
import '../../models/settings_model.dart';
import '../order_type_meta.dart';

/// HTML rendering of a receipt for the browser-print fallback on web
/// (used only when the local print agent is not available). Mirrors the
/// content of the ESC/POS invoice ticket at 80 mm width.
class ReceiptHtml {
  final SettingsModel? settings;

  const ReceiptHtml({this.settings});

  String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  String invoice(InvoiceModel inv, {bool prices = true}) {
    final fmt = NumberFormat('#,##0.00');
    final dateFmt = DateFormat('dd/MM/yyyy hh:mm a');
    final name = (settings?.name.trim().isNotEmpty ?? false)
        ? settings!.name.trim()
        : 'مطعم';
    final sb = StringBuffer();

    sb.write('''
<!doctype html><html dir="rtl" lang="ar"><head><meta charset="utf-8">
<title>${_esc('فاتورة #${inv.invoiceNumber}')}</title>
<style>
  @page { size: 80mm auto; margin: 4mm; }
  body { font-family: Tahoma, Arial, sans-serif; font-size: 12px; color:#000; width: 72mm; margin: 0 auto; }
  h1 { font-size: 18px; text-align: center; margin: 0 0 4px; }
  .c { text-align: center; } .b { font-weight: bold; }
  hr { border: 0; border-top: 1px dashed #000; margin: 6px 0; }
  table { width: 100%; border-collapse: collapse; }
  td { padding: 2px 0; vertical-align: top; }
  td.q { width: 14%; text-align: center; } td.p { width: 26%; text-align: left; }
  .total { font-size: 15px; }
</style></head><body>
<h1>${_esc(name)}</h1>
''');
    if ((settings?.address ?? '').trim().isNotEmpty) {
      sb.write('<div class="c">${_esc(settings!.address!.trim())}</div>');
    }
    if ((settings?.phone ?? '').trim().isNotEmpty) {
      sb.write('<div class="c">هاتف: ${_esc(settings!.phone!.trim())}</div>');
    }
    sb.write('<div class="c">${prices ? 'فاتورة' : 'طلب كاش / مطبخ'} #${inv.invoiceNumber}</div>');
    sb.write('<div class="c">${dateFmt.format(inv.createdAt)}</div>');
    sb.write('<div class="c b">[ ${_esc(OrderType.label(inv.orderType))} ]</div>');
    if (inv.orderType == OrderType.dineIn &&
        (inv.tableNumber?.isNotEmpty ?? false)) {
      sb.write('<div class="c">طاولة: ${_esc(inv.tableNumber!)}</div>');
    }
    if (inv.isThirdParty && (inv.externalReference?.isNotEmpty ?? false)) {
      sb.write(
          '<div class="c">${_esc(OrderType.label(inv.orderType))} #${_esc(inv.externalReference!)}</div>');
    }
    if ((inv.employeeName ?? '').isNotEmpty) {
      sb.write('<div class="c">الموظف: ${_esc(inv.employeeName!)}</div>');
    }
    sb.write('<hr>');
    if ((inv.customerName ?? '').isNotEmpty) {
      sb.write('<div>الاسم: ${_esc(inv.customerName!)}</div>');
    }
    if ((inv.customerPhone ?? '').isNotEmpty) {
      sb.write('<div>الهاتف: ${_esc(inv.customerPhone!)}</div>');
    }
    if (inv.orderType == OrderType.delivery) {
      if ((inv.deliveryArea ?? '').isNotEmpty) {
        sb.write('<div>المنطقة: ${_esc(inv.deliveryArea!)}</div>');
      }
      if ((inv.deliveryAddress ?? '').isNotEmpty) {
        sb.write('<div>العنوان: ${_esc(inv.deliveryAddress!)}</div>');
      }
    }
    sb.write('<hr><table>');
    for (final item in inv.items) {
      sb.write('<tr><td>${_esc(item.name)}</td><td class="q">x${item.quantity}</td>');
      if (prices) sb.write('<td class="p">${fmt.format(item.subtotal)}</td>');
      sb.write('</tr>');
    }
    sb.write('</table><hr>');
    if (prices) {
      if ((inv.subtotal ?? 0) > 0) {
        sb.write('<div>المجموع الفرعي: ${fmt.format(inv.subtotal)} د.أ</div>');
      }
      if ((inv.deliveryFee ?? 0) > 0) {
        sb.write('<div>رسوم التوصيل: ${fmt.format(inv.deliveryFee)} د.أ</div>');
      }
      sb.write('<hr><div class="c b total">الإجمالي: ${fmt.format(inv.total)} د.أ</div><hr>');
      final footer = (settings?.receiptFooter ?? '').trim();
      sb.write('<div class="c">${_esc(footer.isNotEmpty ? footer : 'شكراً لزيارتكم!')}</div>');
    }
    sb.write('</body></html>');
    return sb.toString();
  }
}
