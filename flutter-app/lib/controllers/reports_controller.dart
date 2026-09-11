import 'package:get/get.dart';
import '../repositories/report_repository.dart';
import '../models/channel_model.dart';
import '../models/product_sales_model.dart';
import '../services/order_type_meta.dart';
import '../core/api_exception.dart';
import '../core/json_parsing.dart';

enum ReportFilter { today, week, month, custom }
enum OrderTypeFilter { all, delivery, pickup }

class ReportsController extends GetxController {
  final _repo = ReportRepository();

  final Rx<ReportFilter> filter = ReportFilter.today.obs;
  final Rx<OrderTypeFilter> orderTypeFilter = OrderTypeFilter.all.obs;
  final Rx<DateTime?> customFrom = Rx<DateTime?>(null);
  final Rx<DateTime?> customTo = Rx<DateTime?>(null);

  final RxBool isLoading = false.obs;
  final RxString error = ''.obs;

  // Report data
  final RxDouble totalSales = 0.0.obs;
  final RxInt invoiceCount = 0.obs;
  final RxInt totalItems = 0.obs;
  final RxDouble averageInvoice = 0.0.obs;
  final RxInt deliveryCount = 0.obs;
  final RxInt pickupCount = 0.obs;
  final RxDouble deliverySales = 0.0.obs;
  final RxList<MapEntry<String, int>> topItems = <MapEntry<String, int>>[].obs;

  /// Per-channel breakdown for the active period — the unified multi-channel
  /// summary (dine-in / takeaway / delivery / coffee shop / Talabaty /
  /// Eshyai), each with its own sales, commission and net.
  final RxList<ChannelSalesModel> channelBreakdown = <ChannelSalesModel>[].obs;

  /// Platform commission charged in the period, and sales net of it.
  final RxDouble totalCommission = 0.0.obs;
  final RxDouble totalNetSales = 0.0.obs;

  /// When set, every report is restricted to this channel code — this is what
  /// makes "Talabaty only" / "Eshyai only" reporting independent. Null shows
  /// all channels combined. Takes precedence over [orderTypeFilter].
  final RxnString channelFilter = RxnString();

  /// Channels that actually sold in the period, biggest first — for lists
  /// that should not render six mostly-empty rows.
  List<ChannelSalesModel> get activeChannels =>
      channelBreakdown.where((c) => c.invoiceCount > 0).toList()
        ..sort((a, b) => b.totalSales.compareTo(a.totalSales));

  /// Third-party platform rows only (Talabat, Eshyai, Otlob).
  List<ChannelSalesModel> get thirdPartyChannels =>
      channelBreakdown.where((c) => c.isThirdParty).toList();

  /// Revenue-by-source rows in a stable display order: the four primary
  /// sources (coffee shop, Talabat, Otlob, other) are always listed — even
  /// at zero — so the weekly report always reads the same way; any other
  /// channel appears only when it actually sold something.
  List<ChannelSalesModel> get sourceRows {
    final byCode = {for (final c in channelBreakdown) c.channelCode: c};
    final rows = <ChannelSalesModel>[];
    for (final code in OrderType.all) {
      final c = byCode[code];
      if (c == null) continue;
      if (c.invoiceCount > 0 || OrderType.primarySources.contains(code)) {
        rows.add(c);
      }
    }
    // Channels the backend knows but OrderType does not (future additions).
    for (final c in channelBreakdown) {
      if (!OrderType.all.contains(c.channelCode) && c.invoiceCount > 0) {
        rows.add(c);
      }
    }
    return rows;
  }

  // ── Product × source pivot (weekly stock-taking) ───────────────
  final Rx<ProductSalesReport> productSales = ProductSalesReport.empty.obs;
  final RxBool productSalesLoading = false.obs;

  /// Optional category restriction for the product pivot (server-side).
  final RxnInt categoryFilter = RxnInt();

  /// Free-text product filter applied client-side to the loaded pivot.
  final RxString productSearch = ''.obs;

  /// Columns to show in the pivot: the primary sources always, plus any
  /// other channel with sales — or only the selected channel when filtered.
  List<ProductSalesChannel> get pivotColumns {
    final r = productSales.value;
    if (channelFilter.value != null && channelFilter.value!.isNotEmpty) {
      return r.channels;
    }
    return r.channels
        .where((c) =>
            c.totalQuantity > 0 || OrderType.primarySources.contains(c.code))
        .toList();
  }

  List<ProductSalesRow> get pivotRows {
    final q = productSearch.value.trim().toLowerCase();
    final rows = productSales.value.products;
    if (q.isEmpty) return rows;
    return rows.where((r) => r.name.toLowerCase().contains(q)).toList();
  }

  void setCategoryFilter(int? categoryId) {
    categoryFilter.value = categoryId;
    _reloadProductSales();
  }

  void setProductSearch(String text) => productSearch.value = text;

  Future<void> _reloadProductSales() async {
    final f = filter.value;
    await _loadProductSales(
      _filterFrom(f, customFrom.value),
      _filterTo(f, customTo.value),
      _orderTypeParam,
    );
  }

  Future<void> _loadProductSales(
      String? dateFrom, String? dateTo, String? orderType) async {
    productSalesLoading.value = true;
    try {
      final data = await _repo.getProductSalesByChannel(
        dateFrom: dateFrom,
        dateTo: dateTo,
        orderType: orderType,
        categoryId: categoryFilter.value,
      );
      productSales.value = ProductSalesReport.fromJson(data);
    } on ApiException catch (e) {
      error.value = e.displayMessage;
      productSales.value = ProductSalesReport.empty;
    } catch (_) {
      productSales.value = ProductSalesReport.empty;
    } finally {
      productSalesLoading.value = false;
    }
  }

  @override
  void onInit() {
    super.onInit();
    applyFilter(ReportFilter.today);
  }

  /// Re-fetches the current filter fresh from the API. Called every time
  /// the Reports screen is opened so the numbers are never stale.
  Future<void> refreshCurrent() => applyFilter(
        filter.value,
        from: customFrom.value,
        to: customTo.value,
      );

  Future<void> applyFilter(
    ReportFilter f, {
    DateTime? from,
    DateTime? to,
    OrderTypeFilter? typeFilter,
  }) async {
    filter.value = f;
    if (typeFilter != null) orderTypeFilter.value = typeFilter;
    if (f == ReportFilter.custom) {
      customFrom.value = from;
      customTo.value = to;
    }

    isLoading.value = true;
    error.value = '';

    try {
      await _loadReportData(f, from: from, to: to);
    } on ApiException catch (e) {
      error.value = e.displayMessage;
    } catch (_) {
      error.value = 'فشل تحميل التقارير';
    } finally {
      isLoading.value = false;
    }
  }

  /// Backend `order_type` value for the active filter, or null for all.
  /// An explicit channel filter wins — selecting "طلباتي" must report that
  /// channel alone regardless of the delivery/pickup toggle.
  String? get _orderTypeParam {
    final channel = channelFilter.value;
    if (channel != null && channel.isNotEmpty) return channel;

    return switch (orderTypeFilter.value) {
      OrderTypeFilter.delivery => 'delivery',
      OrderTypeFilter.pickup => 'takeaway',
      OrderTypeFilter.all => null,
    };
  }

  /// Restrict all reports to a single channel (pass null to clear).
  void setChannelFilter(String? code) {
    channelFilter.value = code;
    refreshCurrent();
  }

  Future<void> _loadReportData(
    ReportFilter f, {
    DateTime? from,
    DateTime? to,
  }) async {
    Map<String, dynamic> data = {};
    final orderType = _orderTypeParam;

    switch (f) {
      case ReportFilter.today:
        data = await _repo.getDailyReport(orderType: orderType);
        break;
      case ReportFilter.week:
        data = await _repo.getWeeklyReport(orderType: orderType);
        break;
      case ReportFilter.month:
        data = await _repo.getMonthlyReport(orderType: orderType);
        break;
      case ReportFilter.custom:
        data = await _repo.getRangeReport(
          dateFrom: _formatDate(from ?? DateTime.now()),
          dateTo: _formatDate(to ?? DateTime.now()),
          orderType: orderType,
        );
        break;
    }

    totalSales.value = asDouble(data['total_sales']);
    invoiceCount.value = asInt(data['invoice_count']);
    // Weekly/monthly payloads have no average_invoice field — derive it.
    final avg = asDouble(data['average_invoice']);
    averageInvoice.value = avg > 0
        ? avg
        : (invoiceCount.value > 0 ? totalSales.value / invoiceCount.value : 0.0);

    // Full itemized breakdown (no cap, honors the order-type filter):
    // every item sold in the period with its total quantity, so the
    // "today" filter doubles as the daily inventory-reconciliation list.
    final dateFrom = _filterFrom(f, from);
    final dateTo = _filterTo(f, to);
    final itemized = await _repo.getItemizedReport(
      dateFrom: dateFrom,
      dateTo: dateTo,
      orderType: orderType,
    );
    final items = itemized['items'] as List? ?? [];
    topItems.value = items
        .map((e) => MapEntry(
              e['name'].toString(),
              asInt(e['total_quantity']),
            ))
        .toList();

    totalItems.value = asInt(data['total_items']);

    // Product × source pivot for the same period / channel filter.
    await _loadProductSales(dateFrom, dateTo, orderType);

    totalCommission.value = asDouble(data['commission']);
    totalNetSales.value = asDouble(data['net_sales']);

    // Per-channel breakdown, returned with every summary report. Note this
    // reflects the *filtered* set, so with a channel filter active only that
    // channel carries figures — which is exactly the independent per-channel
    // report ("Talabaty only", "Eshyai only").
    final byChannel = data['by_channel'];
    channelBreakdown.value = byChannel is List
        ? byChannel
            .map((e) => ChannelSalesModel.fromJson(e as Map<String, dynamic>))
            .toList()
        : <ChannelSalesModel>[];

    // Delivery / pickup split from the per-order-type breakdown the
    // backend now returns with every summary report.
    final byType = data['by_order_type'];
    if (byType is Map) {
      final delivery = byType['delivery'];
      deliveryCount.value =
          delivery is Map ? asInt(delivery['invoice_count']) : 0;
      deliverySales.value =
          delivery is Map ? asDouble(delivery['total_sales']) : 0.0;

      // "استلام" card counts everything picked up at the counter.
      int pickup = 0;
      for (final type in ['takeaway', 'coffee_shop', 'dine_in']) {
        final entry = byType[type];
        if (entry is Map) pickup += asInt(entry['invoice_count']);
      }
      pickupCount.value = pickup;
    } else {
      deliveryCount.value = 0;
      pickupCount.value = 0;
      deliverySales.value = 0.0;
    }
  }

  void setOrderTypeFilter(OrderTypeFilter t) {
    applyFilter(filter.value,
        from: customFrom.value, to: customTo.value, typeFilter: t);
  }

  /// {"Burger": 20, "Pizza": 40} — item name → total quantity sold in the
  /// active period. With the default "today" filter this is the daily
  /// itemized sales map for inventory reconciliation.
  Map<String, int> get itemizedMap => Map.fromEntries(topItems);

  // Convenience getters used by ReportsScreen
  List<MapEntry<String, int>> get mostOrdered =>
      topItems.take(5).toList();
  List<MapEntry<String, int>> get leastOrdered =>
      topItems.reversed.take(5).toList();
  List<MapEntry<String, int>> get itemFrequency => topItems.toList();

  String? _filterFrom(ReportFilter f, DateTime? custom) {
    final now = DateTime.now();
    switch (f) {
      case ReportFilter.today:
        return _formatDate(now);
      case ReportFilter.week:
        return _formatDate(now.subtract(Duration(days: now.weekday - 1)));
      case ReportFilter.month:
        return _formatDate(DateTime(now.year, now.month, 1));
      case ReportFilter.custom:
        return custom != null ? _formatDate(custom) : null;
    }
  }

  String? _filterTo(ReportFilter f, DateTime? custom) {
    final now = DateTime.now();
    if (f == ReportFilter.custom && custom != null) {
      return _formatDate(custom);
    }
    return _formatDate(now);
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
