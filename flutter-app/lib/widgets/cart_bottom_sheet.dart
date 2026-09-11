import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/cart_controller.dart';
import '../controllers/menu_controller.dart' as mc;
import '../controllers/invoice_controller.dart';
import '../controllers/delivery_area_controller.dart';
import '../services/app_theme.dart';
import '../services/order_type_meta.dart';
import 'package:intl/intl.dart';

// Mobile bottom sheet — mirrors the tablet _CartPanel logic
class CartBottomSheet extends StatelessWidget {
  final CartController cartCtrl;
  final mc.MenuItemController menuCtrl;

  const CartBottomSheet(
      {super.key, required this.cartCtrl, required this.menuCtrl});

  @override
  Widget build(BuildContext context) {
    final areaCtrl = Get.find<DeliveryAreaController>();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.97,
      minChildSize: 0.5,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.secondary,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.shopping_cart, color: AppTheme.accent),
                  const SizedBox(width: 8),
                  const Text(
                    'الطلب الحالي',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      cartCtrl.clearCart();
                      Get.back();
                    },
                    child: const Text('مسح الكل',
                        style: TextStyle(color: AppTheme.accent)),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppTheme.divider),

            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.all(12),
                children: [
                  // ── Order type toggle ──
                  _OrderTypeRow(cartCtrl: cartCtrl),
                  const SizedBox(height: 12),

                  // ── Customer fields ──
                  _MobileCustomerFields(
                      cartCtrl: cartCtrl, areaCtrl: areaCtrl),
                  const SizedBox(height: 12),
                  const Divider(color: AppTheme.divider),
                  const SizedBox(height: 4),

                  // ── Items ──
                  Obx(() {
                    final cartItems = menuCtrl.items
                        .where((item) =>
                            cartCtrl.getQuantity(item.id) > 0)
                        .toList();
                    if (cartItems.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text('السلة فارغة',
                              style: TextStyle(
                                  color: AppTheme.textSecondary)),
                        ),
                      );
                    }
                    return Column(
                      children: cartItems.map((item) {
                        return Obx(() {
                          final qty = cartCtrl.getQuantity(item.id);
                          return _ItemRow(
                              item: item,
                              qty: qty,
                              cartCtrl: cartCtrl);
                        });
                      }).toList(),
                    );
                  }),
                ],
              ),
            ),

            // ── Total + checkout ──
            Obx(() {
              final subtotal = cartCtrl.calculateSubtotal(menuCtrl.items);
              final fee = cartCtrl.appliedDeliveryFee;
              final total = subtotal + fee;
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    children: [
                      if (fee > 0) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('رسوم التوصيل',
                                style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 13)),
                            Text(
                              '${NumberFormat('#,##0.00').format(fee)} د.أ',
                              style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 13),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                      ],
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('الإجمالي',
                              style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 16)),
                          Text(
                            '${NumberFormat('#,##0.00').format(total)} د.أ',
                            style: const TextStyle(
                              color: AppTheme.accent,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: cartCtrl.cartItemCount == 0
                              ? null
                              : () => _checkout(context),
                          icon: const Icon(
                              Icons.check_circle_outline,
                              size: 22),
                          label: const Text('تأكيد وإنشاء الفاتورة',
                              style: TextStyle(fontSize: 16)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.success,
                            padding: const EdgeInsets.symmetric(
                                vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _checkout(BuildContext context) async {
    final invoice = await cartCtrl.createInvoice(menuCtrl.items);
    if (invoice != null) {
      final invCtrl = Get.find<InvoiceController>();
      invCtrl.loadInvoices();
      invCtrl.refreshPending();
      Get.back();
      Get.snackbar(
        'أُرسل إلى الطلبات المعلقة ✓',
        'طلب #${invoice.invoiceNumber} — ${OrderType.label(invoice.orderType)} — ${NumberFormat('#,##0.00').format(invoice.total)} د.أ — بانتظار تأكيد الدفع',
        backgroundColor: AppTheme.success,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(12),
        borderRadius: 12,
      );
    } else {
      Get.snackbar(
        'تعذر إنشاء الفاتورة',
        cartCtrl.error.value.isNotEmpty
            ? cartCtrl.error.value
            : 'حدث خطأ غير متوقع، حاول مرة أخرى',
        backgroundColor: AppTheme.accent,
        colorText: Colors.white,
        icon: const Icon(Icons.error_outline, color: Colors.white),
        duration: const Duration(seconds: 4),
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(12),
        borderRadius: 12,
      );
    }
  }
}

// Order type toggle for mobile — 4 types in a 2x2 grid
class _OrderTypeRow extends StatelessWidget {
  final CartController cartCtrl;
  const _OrderTypeRow({required this.cartCtrl});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final selected = cartCtrl.orderType.value;
      return GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 2.6,
        children: OrderType.all.map((type) {
          final isSelected = type == selected;
          final color = OrderType.color(type);
          return GestureDetector(
            // setOrderType (not a bare assignment) so the channel's price
            // overrides load with it and the cart totals stay correct.
            onTap: () => cartCtrl.setOrderType(type),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                color: isSelected ? color : AppTheme.cardBg,
                borderRadius: BorderRadius.circular(11),
                border:
                    Border.all(color: isSelected ? color : AppTheme.divider),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(OrderType.icon(type),
                      size: 18,
                      color:
                          isSelected ? Colors.white : AppTheme.textSecondary),
                  const SizedBox(width: 6),
                  Text(OrderType.label(type),
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      )),
                ],
              ),
            ),
          );
        }).toList(),
      );
    });
  }
}

// Customer fields for mobile bottom sheet
class _MobileCustomerFields extends StatefulWidget {
  final CartController cartCtrl;
  final DeliveryAreaController areaCtrl;

  const _MobileCustomerFields(
      {required this.cartCtrl, required this.areaCtrl});

  @override
  State<_MobileCustomerFields> createState() =>
      _MobileCustomerFieldsState();
}

class _MobileCustomerFieldsState
    extends State<_MobileCustomerFields> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _tableCtrl;
  late final TextEditingController _externalRefCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl =
        TextEditingController(text: widget.cartCtrl.customerName.value);
    _phoneCtrl =
        TextEditingController(text: widget.cartCtrl.customerPhone.value);
    _addressCtrl = TextEditingController(
        text: widget.cartCtrl.deliveryAddress.value);
    _tableCtrl =
        TextEditingController(text: widget.cartCtrl.tableNumber.value);
    _externalRefCtrl = TextEditingController(
        text: widget.cartCtrl.externalReference.value);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _tableCtrl.dispose();
    _externalRefCtrl.dispose();
    super.dispose();
  }

  Future<void> _lookupCustomer() async {
    final c = await widget.cartCtrl.lookupByPhone();
    if (!mounted) return;
    if (c != null) {
      // Sync this State's own controllers so the found details are visible.
      _nameCtrl.text = c.name;
      if ((c.deliveryAddress ?? '').isNotEmpty) {
        _addressCtrl.text = c.deliveryAddress!;
      }
      Get.snackbar('تم العثور على العميل ✓', c.name,
          backgroundColor: AppTheme.success,
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
          duration: const Duration(seconds: 2));
    } else {
      Get.snackbar('عميل جديد', 'لا يوجد سجل سابق لهذا الرقم — سيُحفظ عند الدفع',
          backgroundColor: AppTheme.accentGold,
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
          duration: const Duration(seconds: 2));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final type = widget.cartCtrl.orderType.value;
      final isDelivery = type == OrderType.delivery;
      final isDineIn = type == OrderType.dineIn;
      final isThirdParty = OrderType.isThirdParty(type);
      return Column(
        children: [
          TextField(
            controller: _nameCtrl,
            onChanged: (v) =>
                widget.cartCtrl.customerName.value = v,
            style: const TextStyle(
                fontSize: 14, color: AppTheme.textPrimary),
            decoration: const InputDecoration(
              hintText: 'اسم العميل',
              prefixIcon: Icon(Icons.person_outline,
                  color: AppTheme.textSecondary, size: 18),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            onChanged: (v) =>
                widget.cartCtrl.customerPhone.value = v,
            style: const TextStyle(
                fontSize: 14, color: AppTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'رقم الهاتف',
              prefixIcon: const Icon(Icons.phone_outlined,
                  color: AppTheme.textSecondary, size: 18),
              suffixIcon: Obx(() => widget.cartCtrl.isLookingUp.value
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppTheme.accent)),
                    )
                  : IconButton(
                      icon: const Icon(Icons.search,
                          color: AppTheme.accent, size: 20),
                      tooltip: 'بحث عن عميل',
                      onPressed: _lookupCustomer,
                    )),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
          if (isDelivery) ...[
            const SizedBox(height: 8),
            // Area dropdown
            Obx(() {
              final areas = widget.areaCtrl.activeAreas;
              final selected =
                  widget.cartCtrl.selectedDeliveryArea.value;
              final valid =
                  areas.any((a) => a.name == selected) ? selected : null;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: valid,
                    hint: const Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            color: AppTheme.textSecondary, size: 18),
                        SizedBox(width: 8),
                        Text('منطقة التوصيل',
                            style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 14)),
                      ],
                    ),
                    isExpanded: true,
                    dropdownColor: AppTheme.cardBg,
                    style: const TextStyle(
                        color: AppTheme.textPrimary, fontSize: 14),
                    onChanged: (v) {
                      final area =
                          areas.firstWhereOrNull((a) => a.name == v);
                      widget.cartCtrl.setDeliveryArea(
                          v ?? '', area?.id ?? '', area?.deliveryFee ?? 0.0);
                    },
                    items: areas
                        .map((a) => DropdownMenuItem(
                              value: a.name,
                              child: Text(
                                  '${a.name} — ${NumberFormat('#,##0.00').format(a.deliveryFee)} د.أ'),
                            ))
                        .toList(),
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
            TextField(
              controller: _addressCtrl,
              maxLines: 3,
              onChanged: (v) =>
                  widget.cartCtrl.deliveryAddress.value = v,
              style: const TextStyle(
                  fontSize: 14, color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                hintText: 'العنوان الكامل...',
                prefixIcon: Padding(
                  padding: EdgeInsets.only(bottom: 40),
                  child: Icon(Icons.home_outlined,
                      color: AppTheme.textSecondary, size: 18),
                ),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
          if (isDineIn) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _tableCtrl,
              onChanged: (v) => widget.cartCtrl.tableNumber.value = v,
              style: const TextStyle(
                  fontSize: 14, color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                hintText: 'رقم الطاولة',
                prefixIcon: Icon(Icons.table_bar_outlined,
                    color: AppTheme.textSecondary, size: 18),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ],
          // Third-party platforms: capture the aggregator's own order id so
          // the POS ticket can be matched to the platform's tablet.
          if (isThirdParty) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _externalRefCtrl,
              onChanged: (v) =>
                  widget.cartCtrl.externalReference.value = v,
              style: const TextStyle(
                  fontSize: 14, color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'رقم الطلب على ${OrderType.label(type)}',
                prefixIcon: Icon(OrderType.icon(type),
                    color: OrderType.color(type), size: 18),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 12),
              ),
            ),
          ],
        ],
      );
    });
  }
}

// Item row inside mobile bottom sheet
class _ItemRow extends StatelessWidget {
  final dynamic item;
  final int qty;
  final CartController cartCtrl;

  const _ItemRow(
      {required this.item, required this.qty, required this.cartCtrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15)),
                // Channel price, not the base menu price — a Talabaty cart
                // must show what that platform's customer actually pays.
                Text(
                  '${NumberFormat('#,##0.00').format(cartCtrl.effectivePrice(item))} د.أ × $qty',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          Text(
            '${NumberFormat('#,##0.00').format(cartCtrl.effectivePrice(item) * qty)} د.أ',
            style: const TextStyle(
                color: AppTheme.accentGold,
                fontWeight: FontWeight.bold,
                fontSize: 15),
          ),
          const SizedBox(width: 12),
          _SmBtn(
              icon: Icons.remove,
              onTap: () => cartCtrl.removeItem(item),
              color: AppTheme.accent),
          SizedBox(
            width: 28,
            child: Text('$qty',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
          ),
          _SmBtn(
              icon: Icons.add,
              onTap: () => cartCtrl.addItem(item),
              color: AppTheme.success),
        ],
      ),
    );
  }
}

class _SmBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _SmBtn(
      {required this.icon, required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}
