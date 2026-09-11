import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../models/invoice_model.dart';
import '../models/employee_model.dart';
import '../repositories/invoice_repository.dart';
import '../core/api_exception.dart';
import '../services/order_printing.dart';
import '../services/order_type_meta.dart';
import 'auth_controller.dart';

class InvoiceController extends GetxController with WidgetsBindingObserver {
  final _repo = InvoiceRepository();

  final RxList<InvoiceModel> invoices = <InvoiceModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxString searchQuery = ''.obs;
  final Rx<DateTime?> filterFrom = Rx<DateTime?>(null);
  final Rx<DateTime?> filterTo = Rx<DateTime?>(null);
  /// Active channel code, '' for all. Values come from [OrderType].
  final RxString orderTypeFilter = ''.obs;
  final RxString error = ''.obs;

  /// Unpaid invoices awaiting payment, refreshed every 5s so a floor
  /// waiter's "Create Invoice" tap shows up on the cashier's screen without
  /// them having to do anything — see [_startPendingPolling].
  final RxList<InvoiceModel> pendingInvoices = <InvoiceModel>[].obs;
  Timer? _pollTimer;

  // Whether the signed-in employee's role should see pending invoices at
  // all — separate from whether the app is currently foregrounded, so a
  // background/foreground cycle can resume polling without re-checking
  // AuthController.
  bool _pollingEligible = false;

  static const _pendingViewerRoles = {
    'cashier', 'manager', 'admin', 'super_admin',
  };

  int _currentPage = 1;
  bool _hasMore = true;

  @override
  void onInit() {
    super.onInit();
    loadInvoices();

    WidgetsBinding.instance.addObserver(this);

    final auth = Get.find<AuthController>();
    ever<EmployeeModel?>(auth.currentEmployee, (emp) {
      if (emp != null && _pendingViewerRoles.contains(emp.role)) {
        _pollingEligible = true;
        _startPendingPolling();
      } else {
        _pollingEligible = false;
        _stopPendingPolling();
      }
    });
    final currentRole = auth.currentEmployee.value?.role;
    if (currentRole != null && _pendingViewerRoles.contains(currentRole)) {
      _pollingEligible = true;
      _startPendingPolling();
    }
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_pollingEligible) return;

    switch (state) {
      case AppLifecycleState.resumed:
        // Refetch immediately on resume — the 5s tick alone would leave
        // the list stale for up to 5 more seconds right when the cashier
        // is most likely to be looking at it.
        _startPendingPolling();
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        _pollTimer?.cancel();
        _pollTimer = null;
    }
  }

  void _startPendingPolling() {
    _fetchPendingInvoices();
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
        const Duration(seconds: 5), (_) => _fetchPendingInvoices());
  }

  void _stopPendingPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    pendingInvoices.clear();
  }

  Future<void> _fetchPendingInvoices() async {
    try {
      // Newest first: the cashier must see the latest incoming order at
      // the top of the pending queue without scrolling.
      final paginated = await _repo.getInvoices(
        status: 'unpaid',
        perPage: 50,
        sortDir: 'desc',
      );
      pendingInvoices.value = paginated.items;
    } catch (_) {
      // Silent — the next 5s tick retries automatically.
    }
  }

  /// Immediate pending-queue refresh — called right after an order is
  /// submitted so the sender sees it in the queue without waiting for
  /// the next 5-second poll tick.
  Future<void> refreshPending() => _fetchPendingInvoices();

  Future<void> loadInvoices({bool reset = true}) async {
    if (reset) {
      _currentPage = 1;
      _hasMore = true;
      invoices.clear();
    }
    if (!_hasMore) return;

    isLoading.value = true;
    error.value = '';
    try {
      final from = filterFrom.value != null
          ? '${filterFrom.value!.year}-${filterFrom.value!.month.toString().padLeft(2, '0')}-${filterFrom.value!.day.toString().padLeft(2, '0')}'
          : null;
      final to = filterTo.value != null
          ? '${filterTo.value!.year}-${filterTo.value!.month.toString().padLeft(2, '0')}-${filterTo.value!.day.toString().padLeft(2, '0')}'
          : null;

      final paginated = await _repo.getInvoices(
        search: searchQuery.value.trim().isEmpty ? null : searchQuery.value.trim(),
        dateFrom: from,
        dateTo: to,
        orderType: orderTypeFilter.value.isEmpty ? null : orderTypeFilter.value,
        page: _currentPage,
        perPage: 20,
      );

      if (reset) {
        invoices.value = paginated.items;
      } else {
        invoices.addAll(paginated.items);
      }
      _hasMore = paginated.hasMore;
      _currentPage++;
    } on ApiException catch (e) {
      error.value = e.displayMessage;
    } catch (_) {
      error.value = 'فشل تحميل الفواتير';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadMore() => loadInvoices(reset: false);

  /// Switch the invoice list to one sales channel (null = all channels).
  /// Re-queries the API rather than filtering locally, so paging stays
  /// correct and a platform's list is complete instead of being whatever
  /// happened to be on the current page.
  void setChannelFilter(String? code) {
    final next = code ?? '';
    if (orderTypeFilter.value == next) return;
    orderTypeFilter.value = next;
    loadInvoices();
  }

  /// Arabic label of the active channel filter, or null when showing all.
  String? get activeChannelLabel => orderTypeFilter.value.isEmpty
      ? null
      : OrderType.label(orderTypeFilter.value);

  List<InvoiceModel> get filteredInvoices => invoices.toList();

  void clearFilters() {
    searchQuery.value = '';
    filterFrom.value = null;
    filterTo.value = null;
    orderTypeFilter.value = '';
    loadInvoices();
  }

  Future<Map<String, dynamic>?> getPrintData(dynamic invoiceId) async {
    try {
      return await _repo.getPrintData(invoiceId);
    } on ApiException {
      return null;
    }
  }

  Future<bool> markPaid(InvoiceModel invoice, {String paymentMethod = 'cash'}) async {
    try {
      final updated = await _repo.markPaid(invoice.id, paymentMethod: paymentMethod);
      final idx = invoices.indexWhere((i) => i.id == invoice.id);
      if (idx >= 0) invoices[idx] = updated;
      pendingInvoices.removeWhere((i) => i.id == invoice.id);
      // Payment confirmed → print both jobs sequentially: kitchen
      // slip (no prices) first, then the priced customer invoice.
      // Fire-and-forget; a print failure never fails the payment.
      autoPrintOnPayment(updated);
      return true;
    } on ApiException catch (e) {
      error.value = e.displayMessage;
      return false;
    }
  }

  Future<bool> refund(InvoiceModel invoice) async {
    try {
      final updated = await _repo.refund(invoice.id);
      final idx = invoices.indexWhere((i) => i.id == invoice.id);
      if (idx >= 0) invoices[idx] = updated;
      return true;
    } on ApiException catch (e) {
      error.value = e.displayMessage;
      return false;
    }
  }
}
