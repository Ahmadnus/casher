import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/menu_controller.dart' as mc;
import '../../controllers/cart_controller.dart';
import '../../controllers/invoice_controller.dart';
import '../../controllers/delivery_area_controller.dart';
import '../../models/menu_item_model.dart';
import '../../services/app_theme.dart';
import '../../services/order_type_meta.dart';
import '../../widgets/menu_item_card.dart';
import '../../widgets/cart_bottom_sheet.dart';
import 'package:intl/intl.dart';

class CashierScreen extends StatelessWidget {
  const CashierScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final menuCtrl = Get.find<mc.MenuItemController>();
    final cartCtrl = Get.find<CartController>();
    final isWide = MediaQuery.of(context).size.width > 700;

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
              child: const Icon(Icons.point_of_sale,
                  color: AppTheme.accent, size: 22),
            ),
            const SizedBox(width: 10),
            const Text('الكاشير'),
          ],
        ),
        actions: [
          Obx(() {
            final total = cartCtrl.calculateTotal(menuCtrl.menuItems);
            final count = cartCtrl.cartItemCount;
            if (count == 0) return const SizedBox.shrink();
            return GestureDetector(
              onTap: () => _showCart(context, cartCtrl, menuCtrl),
              child: Container(
                margin: const EdgeInsets.only(left: 12, right: 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.accent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.shopping_cart, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      '$count | ${NumberFormat('#,##0.00').format(total)} د.أ',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
            );
          }),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => menuCtrl.loadAll(),
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: isWide
          ? Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _MenuPanel(menuCtrl: menuCtrl, cartCtrl: cartCtrl),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  flex: 2,
                  child: _CartPanel(cartCtrl: cartCtrl, menuCtrl: menuCtrl),
                ),
              ],
            )
          : _MenuPanel(menuCtrl: menuCtrl, cartCtrl: cartCtrl),
      floatingActionButton: isWide
          ? null
          : Obx(() {
              if (cartCtrl.cartItemCount == 0) return const SizedBox.shrink();
              return FloatingActionButton.extended(
                heroTag: "cashier_fab",
                onPressed: () => _showCart(context, cartCtrl, menuCtrl),
                backgroundColor: AppTheme.accent,
                icon: const Icon(Icons.shopping_cart),
                label: Obx(() {
                  final total = cartCtrl.calculateTotal(menuCtrl.menuItems);
                  return Text(
                    '${cartCtrl.cartItemCount} عنصر | ${NumberFormat('#,##0.00').format(total)} د.أ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  );
                }),
              );
            }),
    );
  }

  void _showCart(BuildContext context, CartController cartCtrl,
      mc.MenuItemController menuCtrl) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CartBottomSheet(
        cartCtrl: cartCtrl,
        menuCtrl: menuCtrl,
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Menu Panel (unchanged logic, left side)
// ─────────────────────────────────────────────
class _MenuPanel extends StatelessWidget {
  final mc.MenuItemController menuCtrl;
  final CartController cartCtrl;

  const _MenuPanel({required this.menuCtrl, required this.cartCtrl});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Obx(() => Container(
              height: 50,
              color: AppTheme.secondary,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                itemCount: menuCtrl.categories.length,
                itemBuilder: (_, i) {
                  final cat = menuCtrl.categories[i];
                  final selected = menuCtrl.selectedCategory.value == cat.name;
                  return Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: ChoiceChip(
                      label: Text(cat.name),
                      selected: selected,
                      onSelected: (_) =>
                          menuCtrl.selectedCategory.value = cat.name,
                      backgroundColor: AppTheme.cardBg,
                      selectedColor: AppTheme.accent,
                      labelStyle: TextStyle(
                        color: selected
                            ? Colors.white
                            : AppTheme.textSecondary,
                        fontWeight: selected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  );
                },
              ),
            )),
        Expanded(
          child: Obx(() {
            if (menuCtrl.isLoading.value && menuCtrl.menuItems.isEmpty) {
              return const Center(
                  child: CircularProgressIndicator(color: AppTheme.accent));
            }

            final sel = menuCtrl.selectedCategory.value;
            final items = sel.isEmpty
                ? menuCtrl.menuItems
                : menuCtrl.menuItems.where((m) => m.category == sel).toList();
            if (items.isEmpty) {
              return RefreshIndicator(
                onRefresh: () => menuCtrl.loadAll(),
                child: ListView(
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.6,
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.restaurant_menu,
                                size: 60, color: AppTheme.textSecondary),
                            SizedBox(height: 12),
                            Text('لا توجد عناصر في هذه الفئة',
                                style: TextStyle(color: AppTheme.textSecondary)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: () => menuCtrl.loadAll(),
              child: GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount:
                      MediaQuery.of(context).size.width > 600 ? 3 : 2,
                  childAspectRatio: 0.85,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: items.length,
                itemBuilder: (_, i) => MenuItemCard(
                  item: items[i],
                  cartCtrl: cartCtrl,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Cart Panel (wide layout — tablet/desktop)
// ─────────────────────────────────────────────
class _CartPanel extends StatefulWidget {
  final CartController cartCtrl;
  final mc.MenuItemController menuCtrl;

  const _CartPanel({required this.cartCtrl, required this.menuCtrl});

  @override
  State<_CartPanel> createState() => _CartPanelState();
}

class _CartPanelState extends State<_CartPanel> {
  @override
  Widget build(BuildContext context) {
    final cartCtrl = widget.cartCtrl;
    final menuCtrl = widget.menuCtrl;

    return Container(
      color: AppTheme.secondary,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.receipt, color: AppTheme.accent),
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
                Obx(() => cartCtrl.cartItemCount > 0
                    ? TextButton(
                        onPressed: () => cartCtrl.clearCart(),
                        child: const Text('مسح',
                            style: TextStyle(color: AppTheme.accent)),
                      )
                    : const SizedBox.shrink()),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.divider),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Order type toggle ──
                  _OrderTypeToggle(cartCtrl: cartCtrl),
                  const SizedBox(height: 10),

                  // ── Customer fields ──
                  _CustomerFields(cartCtrl: cartCtrl),
                  const SizedBox(height: 10),

                  // ── Cart items ──
                  Obx(() {
                    final items = menuCtrl.menuItems
                        .where(
                            (item) => cartCtrl.getQuantity(item.id) > 0)
                        .toList();
                    if (items.isEmpty) {
                      return Container(
                        height: 100,
                        alignment: Alignment.center,
                        child: const Text('لا توجد أصناف في الطلب',
                            style: TextStyle(
                                color: AppTheme.textSecondary)),
                      );
                    }
                    return Column(
                      children: items.map((item) {
                        return Obx(() {
                          final qty = cartCtrl.getQuantity(item.id);
                          return _CartItemTile(
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
          ),

          // ── Total + Checkout ──
          const Divider(height: 1, color: AppTheme.divider),
          Obx(() {
            final subtotal = cartCtrl.calculateSubtotal(menuCtrl.menuItems);
            final fee = cartCtrl.appliedDeliveryFee;
            final total = subtotal + fee;
            return Container(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  if (fee > 0) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('رسوم التوصيل:',
                            style: TextStyle(
                                fontSize: 14, color: AppTheme.textSecondary)),
                        Text(
                          '${NumberFormat('#,##0.00').format(fee)} د.أ',
                          style: const TextStyle(
                              fontSize: 14, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('الإجمالي:',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary)),
                      Text(
                        '${NumberFormat('#,##0.00').format(total)} د.أ',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.accent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: cartCtrl.cartItemCount == 0
                          ? null
                          : () => _confirmOrder(context),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('إنشاء الفاتورة',
                          style: TextStyle(fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: AppTheme.success,
                        disabledBackgroundColor: AppTheme.divider,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _confirmOrder(BuildContext context) async {
    final invoice =
        await widget.cartCtrl.createInvoice(widget.menuCtrl.menuItems);
    if (invoice != null) {
      final invCtrl = Get.find<InvoiceController>();
      invCtrl.loadInvoices();
      invCtrl.refreshPending();
      Get.snackbar(
        'أُرسل إلى الطلبات المعلقة ✓',
        'طلب #${invoice.invoiceNumber} — ${OrderType.label(invoice.orderType)} — بانتظار تأكيد الدفع',
        backgroundColor: AppTheme.success,
        colorText: Colors.white,
        icon: const Icon(Icons.check_circle, color: Colors.white),
        duration: const Duration(seconds: 3),
        snackPosition: SnackPosition.TOP,
      );
    } else {
      Get.snackbar(
        'تعذر إنشاء الفاتورة',
        widget.cartCtrl.error.value.isNotEmpty
            ? widget.cartCtrl.error.value
            : 'حدث خطأ غير متوقع، حاول مرة أخرى',
        backgroundColor: AppTheme.accent,
        colorText: Colors.white,
        icon: const Icon(Icons.error_outline, color: Colors.white),
        duration: const Duration(seconds: 4),
        snackPosition: SnackPosition.TOP,
      );
    }
  }
}

// ─────────────────────────────────────────────
// Order type toggle widget — 4 types in a 2x2 grid
// ─────────────────────────────────────────────
class _OrderTypeToggle extends StatelessWidget {
  final CartController cartCtrl;
  const _OrderTypeToggle({required this.cartCtrl});

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
        children: OrderType.all
            .map((type) => _OrderTypeCell(
                  type: type,
                  selected: type == selected,
                  // setOrderType (not a bare assignment) so the channel's
                  // price overrides load with it and totals stay correct.
                  onTap: () => cartCtrl.setOrderType(type),
                ))
            .toList(),
      );
    });
  }
}

class _OrderTypeCell extends StatelessWidget {
  final String type;
  final bool selected;
  final VoidCallback onTap;

  const _OrderTypeCell(
      {required this.type, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = OrderType.color(type);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: selected ? color : AppTheme.cardBg,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: selected ? color : AppTheme.divider),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(OrderType.icon(type),
                size: 16,
                color: selected ? Colors.white : AppTheme.textSecondary),
            const SizedBox(width: 6),
            Text(
              OrderType.label(type),
              style: TextStyle(
                color: selected ? Colors.white : AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Customer fields widget (name, phone, area, address)
// ─────────────────────────────────────────────
class _CustomerFields extends StatelessWidget {
  final CartController cartCtrl;
  const _CustomerFields({required this.cartCtrl});

  @override
  Widget build(BuildContext context) {
    final areaCtrl = Get.find<DeliveryAreaController>();

    return Obx(() {
      final type = cartCtrl.orderType.value;
      final isDelivery = type == OrderType.delivery;
      final isDineIn = type == OrderType.dineIn;
      final isThirdParty = OrderType.isThirdParty(type);
      return Column(
        children: [
          // Customer name
          _SmallField(
            hint: 'اسم العميل',
            icon: Icons.person_outline,
            value: cartCtrl.customerName.value,
            onChanged: (v) => cartCtrl.customerName.value = v,
          ),
          const SizedBox(height: 8),
          // Phone
          _SmallField(
            hint: 'رقم الهاتف',
            icon: Icons.phone_outlined,
            value: cartCtrl.customerPhone.value,
            onChanged: (v) => cartCtrl.customerPhone.value = v,
            keyboardType: TextInputType.phone,
          ),
          // Delivery-only fields
          if (isDelivery) ...[
            const SizedBox(height: 8),
            // Area dropdown
            _AreaDropdown(cartCtrl: cartCtrl, areaCtrl: areaCtrl),
            const SizedBox(height: 8),
            // Full address
            _AddressField(cartCtrl: cartCtrl),
          ],
          // Table number for dine-in
          if (isDineIn) ...[
            const SizedBox(height: 8),
            _SmallField(
              hint: 'رقم الطاولة',
              icon: Icons.table_bar_outlined,
              value: cartCtrl.tableNumber.value,
              onChanged: (v) => cartCtrl.tableNumber.value = v,
            ),
          ],
          // Platform order id for Talabaty / Eshyai — required by the backend
          // so every third-party ticket can be reconciled with the platform.
          if (isThirdParty) ...[
            const SizedBox(height: 8),
            _SmallField(
              hint: 'رقم الطلب على ${OrderType.label(type)}',
              icon: OrderType.icon(type),
              value: cartCtrl.externalReference.value,
              onChanged: (v) => cartCtrl.externalReference.value = v,
            ),
          ],
        ],
      );
    });
  }
}

class _SmallField extends StatefulWidget {
  final String hint;
  final IconData icon;
  final String value;
  final ValueChanged<String> onChanged;
  final TextInputType keyboardType;

  const _SmallField({
    required this.hint,
    required this.icon,
    required this.value,
    required this.onChanged,
    this.keyboardType = TextInputType.text,
  });

  @override
  State<_SmallField> createState() => _SmallFieldState();
}

class _SmallFieldState extends State<_SmallField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      keyboardType: widget.keyboardType,
      onChanged: widget.onChanged,
      style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
      decoration: InputDecoration(
        hintText: widget.hint,
        prefixIcon:
            Icon(widget.icon, color: AppTheme.textSecondary, size: 18),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}

class _AreaDropdown extends StatelessWidget {
  final CartController cartCtrl;
  final DeliveryAreaController areaCtrl;

  const _AreaDropdown(
      {required this.cartCtrl, required this.areaCtrl});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final areas = areaCtrl.activeAreas;
      final selected = cartCtrl.selectedDeliveryArea.value;
      final validSelected =
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
            value: validSelected,
            hint: const Row(
              children: [
                Icon(Icons.location_on_outlined,
                    color: AppTheme.textSecondary, size: 18),
                SizedBox(width: 8),
                Text('منطقة التوصيل',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 14)),
              ],
            ),
            isExpanded: true,
            dropdownColor: AppTheme.cardBg,
            style: const TextStyle(
                color: AppTheme.textPrimary, fontSize: 14),
            onChanged: (v) {
                final area = areas.firstWhereOrNull((a) => a.name == v);
                cartCtrl.setDeliveryArea(
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
    });
  }
}

class _AddressField extends StatefulWidget {
  final CartController cartCtrl;
  const _AddressField({required this.cartCtrl});

  @override
  State<_AddressField> createState() => _AddressFieldState();
}

class _AddressFieldState extends State<_AddressField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.cartCtrl.deliveryAddress.value);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      maxLines: 3,
      onChanged: (v) => widget.cartCtrl.deliveryAddress.value = v,
      style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
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
    );
  }
}

// ─────────────────────────────────────────────
// Cart item tile (unchanged from original)
// ─────────────────────────────────────────────
class _CartItemTile extends StatelessWidget {
  final MenuItemModel item;
  final int qty;
  final CartController cartCtrl;

  const _CartItemTile(
      {required this.item, required this.qty, required this.cartCtrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(10),
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
                        fontSize: 13)),
                // Channel price, not the base menu price.
                Text(
                  '${NumberFormat('#,##0.00').format(cartCtrl.effectivePrice(item))} × $qty = ${NumberFormat('#,##0.00').format(cartCtrl.effectivePrice(item) * qty)}',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          _QtyControl(
            qty: qty,
            onAdd: () => cartCtrl.addItem(item),
            onRemove: () => cartCtrl.removeItem(item),
          ),
        ],
      ),
    );
  }
}

class _QtyControl extends StatelessWidget {
  final int qty;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _QtyControl(
      {required this.qty, required this.onAdd, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CircleBtn(
            icon: Icons.remove, onTap: onRemove, color: AppTheme.accent),
        Container(
          width: 32,
          alignment: Alignment.center,
          child: Text(
            '$qty',
            style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 14),
          ),
        ),
        _CircleBtn(icon: Icons.add, onTap: onAdd, color: AppTheme.success),
      ],
    );
  }
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _CircleBtn(
      {required this.icon, required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}