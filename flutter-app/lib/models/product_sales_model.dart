import '../core/json_parsing.dart';

/// One column of the product × order-source pivot: a channel with its
/// totals across every product row.
class ProductSalesChannel {
  final String code;
  final String name;
  final String? nameAr;
  final bool isThirdParty;
  final int totalQuantity;
  final double totalRevenue;

  const ProductSalesChannel({
    required this.code,
    required this.name,
    this.nameAr,
    required this.isThirdParty,
    required this.totalQuantity,
    required this.totalRevenue,
  });

  factory ProductSalesChannel.fromJson(Map<String, dynamic> j) =>
      ProductSalesChannel(
        code: asString(j['channel_code']),
        name: asString(j['channel_name']),
        nameAr: j['channel_name_ar'] as String?,
        isThirdParty: asBool(j['is_third_party']),
        totalQuantity: asInt(j['total_quantity']),
        totalRevenue: asDouble(j['total_revenue']),
      );
}

/// One row of the pivot: a product with its quantity/revenue per channel.
class ProductSalesRow {
  final int? menuItemId;
  final String name;
  final int? categoryId;
  final Map<String, int> quantities;
  final Map<String, double> revenue;
  final int totalQuantity;
  final double totalRevenue;

  const ProductSalesRow({
    required this.menuItemId,
    required this.name,
    required this.categoryId,
    required this.quantities,
    required this.revenue,
    required this.totalQuantity,
    required this.totalRevenue,
  });

  int qty(String channelCode) => quantities[channelCode] ?? 0;
  double rev(String channelCode) => revenue[channelCode] ?? 0.0;

  factory ProductSalesRow.fromJson(Map<String, dynamic> j) {
    final q = (j['quantities'] as Map?) ?? const {};
    final r = (j['revenue'] as Map?) ?? const {};
    return ProductSalesRow(
      menuItemId: j['menu_item_id'] == null ? null : asInt(j['menu_item_id']),
      name: asString(j['name']),
      categoryId: j['category_id'] == null ? null : asInt(j['category_id']),
      quantities: q.map((k, v) => MapEntry(k.toString(), asInt(v))),
      revenue: r.map((k, v) => MapEntry(k.toString(), asDouble(v))),
      totalQuantity: asInt(j['total_quantity']),
      totalRevenue: asDouble(j['total_revenue']),
    );
  }
}

/// `/reports/product-sales-by-channel` — the weekly stock-taking report.
class ProductSalesReport {
  final String dateFrom;
  final String dateTo;
  final List<ProductSalesChannel> channels;
  final List<ProductSalesRow> products;
  final int totalQuantity;
  final double totalRevenue;

  const ProductSalesReport({
    required this.dateFrom,
    required this.dateTo,
    required this.channels,
    required this.products,
    required this.totalQuantity,
    required this.totalRevenue,
  });

  static const empty = ProductSalesReport(
    dateFrom: '',
    dateTo: '',
    channels: [],
    products: [],
    totalQuantity: 0,
    totalRevenue: 0,
  );

  /// Channels that sold at least one unit in the period, so the table never
  /// renders a wall of empty columns.
  List<ProductSalesChannel> get activeChannels =>
      channels.where((c) => c.totalQuantity > 0).toList();

  factory ProductSalesReport.fromJson(Map<String, dynamic> j) =>
      ProductSalesReport(
        dateFrom: asString(j['date_from']),
        dateTo: asString(j['date_to']),
        channels: ((j['channels'] as List?) ?? const [])
            .map((e) => ProductSalesChannel.fromJson(e as Map<String, dynamic>))
            .toList(),
        products: ((j['products'] as List?) ?? const [])
            .map((e) => ProductSalesRow.fromJson(e as Map<String, dynamic>))
            .toList(),
        totalQuantity: asInt(j['total_quantity']),
        totalRevenue: asDouble(j['total_revenue']),
      );
}
