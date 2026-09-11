import 'dart:math';
import 'package:get/get.dart';
import '../models/menu_item_model.dart';
import '../models/invoice_model.dart';
import '../models/customer_model.dart';
import '../repositories/invoice_repository.dart';
import '../repositories/customer_repository.dart';
import '../repositories/channel_repository.dart';
import '../core/api_exception.dart';
import '../services/order_type_meta.dart';
import 'auth_controller.dart';
import 'delivery_area_controller.dart';

class CartController extends GetxController {
  final _invoiceRepo = InvoiceRepository();
  final _customerRepo = CustomerRepository();
  final _channelRepo = ChannelRepository();

  /// True while a phone lookup is in flight (drives the search spinner).
  final RxBool isLookingUp = false.obs;

  final RxMap<String, int> cartQuantities = <String, int>{}.obs;

  // Customer / order info
  final RxString customerName = ''.obs;
  final RxString customerPhone = ''.obs;
  final RxString selectedDeliveryArea = ''.obs;
  final RxString deliveryAreaId = ''.obs;
  final RxDouble deliveryFee = 0.0.obs;
  final RxString deliveryAddress = ''.obs;
  final RxString tableNumber = ''.obs;
  final RxString orderType = OrderType.takeaway.obs;

  /// The platform's own order id (Talabaty/Eshyai). Required by the backend
  /// on third-party channels so a POS ticket can be reconciled with the app.
  final RxString externalReference = ''.obs;

  /// Per-channel price overrides for the selected channel, {menuItemId: price}.
  /// Empty means "no overrides" — base menu prices apply. Kept in sync by
  /// [setOrderType] so the cashier always sees the price the customer pays.
  final RxMap<String, double> channelPrices = <String, double>{}.obs;
  final RxString paymentMethod = 'cash'.obs;
  final RxBool isLoading = false.obs;
  final RxString error = ''.obs;

  // Stable per-checkout idempotency key: generated once for a submit
  // attempt and reused on retry, so a double-tap (or a retry after a
  // timeout) can never create two invoices. Reset after success/clear.
  String? _idempotencyKey;
  static final _rand = Random();

  String _ensureIdempotencyKey() {
    _idempotencyKey ??=
        '${DateTime.now().microsecondsSinceEpoch}-${_rand.nextInt(0x7fffffff)}';
    return _idempotencyKey!;
  }

  int getQuantity(String itemId) => cartQuantities[itemId] ?? 0;
  bool get isEmpty => cartQuantities.isEmpty;
  int get cartItemCount =>
      cartQuantities.values.fold(0, (sum, qty) => sum + qty);

  void addItem(MenuItemModel item) {
    cartQuantities[item.id] = (cartQuantities[item.id] ?? 0) + 1;
  }

  void removeItem(MenuItemModel item) {
    final current = cartQuantities[item.id] ?? 0;
    if (current <= 1) {
      cartQuantities.remove(item.id);
    } else {
      cartQuantities[item.id] = current - 1;
    }
  }

  void clearCart() {
    cartQuantities.clear();
    customerName.value = '';
    customerPhone.value = '';
    selectedDeliveryArea.value = '';
    deliveryAreaId.value = '';
    deliveryFee.value = 0.0;
    deliveryAddress.value = '';
    tableNumber.value = '';
    externalReference.value = '';
    orderType.value = OrderType.takeaway;
    channelPrices.clear();
    paymentMethod.value = 'cash';
    error.value = '';
    _idempotencyKey = null;
  }

  /// Switch the active sales channel and load its price overrides.
  ///
  /// Always call this instead of assigning `orderType.value` directly — the
  /// override map must be refreshed with the channel, otherwise the cashier
  /// would see in-store prices on a Talabaty order while the backend charges
  /// the marked-up ones.
  Future<void> setOrderType(String type) async {
    if (orderType.value == type && channelPrices.isNotEmpty) return;

    orderType.value = type;

    // Platform reference only applies to third-party channels.
    if (!OrderType.isThirdParty(type)) externalReference.value = '';

    await _loadChannelPrices(type);
  }

  Future<void> _loadChannelPrices(String type) async {
    try {
      final prices = await _channelRepo.getChannelPrices(type);
      channelPrices
        ..clear()
        ..addAll(prices);
    } catch (_) {
      // Pricing is an enhancement, never a checkout blocker: on failure fall
      // back to base menu prices. The backend is authoritative regardless and
      // re-prices every line when the invoice is created.
      channelPrices.clear();
    }
  }

  /// Price of an item on the currently selected channel — the channel
  /// override when one exists, the base menu price otherwise.
  double effectivePrice(MenuItemModel item) =>
      channelPrices[item.id] ?? item.price;

  /// Items-only subtotal (no delivery fee), priced for the active channel.
  double calculateSubtotal(List<MenuItemModel> allItems) {
    final byId = {for (final item in allItems) item.id: item};
    double total = 0;
    for (final entry in cartQuantities.entries) {
      final item = byId[entry.key];
      if (item != null) total += effectivePrice(item) * entry.value;
    }
    return total;
  }

  /// Delivery fee currently applied (only for delivery orders).
  double get appliedDeliveryFee =>
      orderType.value == OrderType.delivery ? deliveryFee.value : 0.0;

  /// Grand total shown to the cashier — matches the backend calculation
  /// (subtotal + delivery fee for delivery orders).
  double calculateTotal(List<MenuItemModel> allItems) =>
      calculateSubtotal(allItems) + appliedDeliveryFee;

  /// Returns an Arabic error message if the order is missing required
  /// fields for its type, or null when it is ready to submit. Mirrors
  /// the backend StoreInvoiceRequest rules so the user gets instant
  /// feedback instead of a silent 422.
  String? validateOrder() {
    if (cartQuantities.isEmpty) return 'السلة فارغة';
    if (orderType.value == OrderType.delivery) {
      if (deliveryAreaId.value.isEmpty) return 'الرجاء اختيار منطقة التوصيل';
      if (deliveryAddress.value.trim().isEmpty) {
        return 'الرجاء إدخال عنوان التوصيل';
      }
    }
    if (orderType.value == OrderType.dineIn &&
        tableNumber.value.trim().isEmpty) {
      return 'الرجاء إدخال رقم الطاولة';
    }
    if (OrderType.isThirdParty(orderType.value) &&
        externalReference.value.trim().isEmpty) {
      return 'الرجاء إدخال رقم الطلب على ${OrderType.label(orderType.value)}';
    }
    return null;
  }

  Future<InvoiceModel?> createInvoice(List<MenuItemModel> allItems) async {
    final validationError = validateOrder();
    if (validationError != null) {
      error.value = validationError;
      return null;
    }
    isLoading.value = true;
    error.value = '';

    try {
      // Build line items from cart
      final byId = {for (final item in allItems) item.id: item};
      final lineItems = <Map<String, dynamic>>[];
      for (final entry in cartQuantities.entries) {
        final found = byId[entry.key];
        if (found != null) {
          lineItems.add({
            'menu_item_id': found.id,
            'quantity': entry.value,
          });
        }
      }

      final empName = Get.find<AuthController>().currentEmployee.value?.name;

      final body = <String, dynamic>{
        'order_type': orderType.value,
        'payment_method': paymentMethod.value,
        // Two-step lifecycle: submission creates an UNPAID invoice that
        // lands in the cashier's pending queue (الطلبات المعلقة). It only
        // becomes a finalized paid invoice when the cashier confirms
        // payment (markPaid) — which is also when it enters the reports.
        'paid': false,
        'idempotency_key': _ensureIdempotencyKey(),
        'items': lineItems,
        if (customerName.value.trim().isNotEmpty)
          'customer_name': customerName.value.trim(),
        if (customerPhone.value.trim().isNotEmpty)
          'customer_phone': customerPhone.value.trim(),
        if (orderType.value == OrderType.delivery && deliveryAreaId.value.isNotEmpty)
          'delivery_area_id': int.tryParse(deliveryAreaId.value),
        if (orderType.value == OrderType.delivery && deliveryAddress.value.trim().isNotEmpty)
          'delivery_address': deliveryAddress.value.trim(),
        if (orderType.value == OrderType.dineIn && tableNumber.value.trim().isNotEmpty)
          'table_number': tableNumber.value.trim(),
        if (OrderType.isThirdParty(orderType.value) &&
            externalReference.value.trim().isNotEmpty)
          'external_reference': externalReference.value.trim(),
      };

      final invoice = await _invoiceRepo.createInvoice(body);

      // Patch employeeName from current session since API returns it nested
      if (invoice.employeeName == null && empName != null) {
        invoice.employeeName = empName;
      }

      clearCart();
      return invoice;
    } on ApiException catch (e) {
      error.value = e.displayMessage;
      return null;
    } catch (_) {
      error.value = 'فشل إنشاء الفاتورة';
      return null;
    } finally {
      isLoading.value = false;
    }
  }

  /// Looks up a saved customer by the entered phone and fills the Rx
  /// fields (name / address / area + fee). Returns the customer when
  /// found so the caller can also sync its own text controllers. Silent
  /// and null-safe on failure — the lookup is a convenience and must
  /// never block checkout.
  Future<CustomerModel?> lookupByPhone() async {
    final phone = customerPhone.value.trim();
    if (phone.isEmpty) return null;
    isLookingUp.value = true;
    try {
      final c = await _customerRepo.findByPhone(phone);
      if (c != null) {
        if (c.name.isNotEmpty) customerName.value = c.name;
        if ((c.deliveryAddress ?? '').isNotEmpty) {
          deliveryAddress.value = c.deliveryAddress!;
        }
        if (c.deliveryAreaId != null &&
            Get.isRegistered<DeliveryAreaController>()) {
          final area = Get.find<DeliveryAreaController>()
              .deliveryAreas
              .firstWhereOrNull((a) => a.id == c.deliveryAreaId.toString());
          if (area != null) {
            setDeliveryArea(area.name, area.id, area.deliveryFee);
          }
        }
      }
      return c;
    } catch (_) {
      return null;
    } finally {
      isLookingUp.value = false;
    }
  }

  // Keep for backward compat with screens that set deliveryArea by name
  void setDeliveryArea(String name, String id, [double fee = 0.0]) {
    selectedDeliveryArea.value = name;
    deliveryAreaId.value = id;
    deliveryFee.value = fee;
  }
}
