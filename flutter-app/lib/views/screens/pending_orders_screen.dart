import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/invoice_controller.dart';
import '../../services/app_theme.dart';
import '../../widgets/invoice_tile.dart';

/// Cashier-facing live queue of unpaid invoices. Backed by
/// [InvoiceController.pendingInvoices], which polls the server every 5
/// seconds — so an invoice a floor waiter creates on another device shows
/// up here without any action from the cashier.
class PendingOrdersScreen extends StatelessWidget {
  const PendingOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<InvoiceController>();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.accentGold.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.pending_actions,
                  color: AppTheme.accentGold, size: 22),
            ),
            const SizedBox(width: 10),
            const Text('الطلبات المعلقة'),
          ],
        ),
      ),
      body: Obx(() {
        final items = ctrl.pendingInvoices;
        if (items.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline,
                    size: 60, color: AppTheme.textSecondary),
                SizedBox(height: 12),
                Text('لا توجد طلبات بانتظار الدفع',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 16)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          itemCount: items.length,
          itemBuilder: (_, i) => InvoiceTile(invoice: items[i]),
        );
      }),
    );
  }
}
