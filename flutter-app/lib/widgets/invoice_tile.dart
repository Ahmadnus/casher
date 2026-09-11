import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/invoice_model.dart';
import '../services/app_theme.dart';
import '../services/order_type_meta.dart';
import '../views/screens/invoice_detail_screen.dart';

/// Shared invoice list row — used by both the full invoice history list and
/// the cashier's live pending-orders queue.
class InvoiceTile extends StatelessWidget {
  final InvoiceModel invoice;
  const InvoiceTile({super.key, required this.invoice});

  @override
  Widget build(BuildContext context) {
    final isDelivery = invoice.orderType == OrderType.delivery;
    final typeColor = OrderType.color(invoice.orderType);
    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => InvoiceDetailScreen(invoice: invoice))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    OrderType.icon(invoice.orderType),
                    color: typeColor,
                    size: 18,
                  ),
                  Text('#${invoice.invoiceNumber}',
                      style: TextStyle(
                          color: typeColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (invoice.customerName?.isNotEmpty == true)
                        ? invoice.customerName!
                        : 'فاتورة رقم ${invoice.invoiceNumber}',
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    DateFormat('dd/MM/yyyy hh:mm a').format(invoice.createdAt),
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12),
                  ),
                  Text(
                    '${invoice.itemCount} عنصر'
                    '${invoice.customerPhone?.isNotEmpty == true ? " · ${invoice.customerPhone}" : ""}',
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12),
                  ),
                  if (isDelivery && invoice.deliveryArea?.isNotEmpty == true)
                    Text('📍 ${invoice.deliveryArea}',
                        style: const TextStyle(
                            color: AppTheme.accent, fontSize: 12)),
                  if (invoice.orderType == OrderType.dineIn &&
                      invoice.tableNumber?.isNotEmpty == true)
                    Text('🍽️ طاولة ${invoice.tableNumber}',
                        style: const TextStyle(
                            color: AppTheme.accentGold, fontSize: 12)),
                  // Platform order id — the number staff match against the
                  // aggregator's own app when reconciling.
                  if (invoice.isThirdParty &&
                      invoice.externalReference?.isNotEmpty == true)
                    Text(
                        '${OrderType.label(invoice.orderType)} #${invoice.externalReference}',
                        style: TextStyle(color: typeColor, fontSize: 12)),
                ],
              ),
            ),
            Text('${NumberFormat('#,##0.00').format(invoice.total)} د.أ',
                style: const TextStyle(
                    color: AppTheme.accentGold,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
          ],
        ),
      ),
    );
  }
}
