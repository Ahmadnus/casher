import '../core/json_parsing.dart';

class DashboardModel {
  final double todaySales;
  final int todayOrders;
  final int todayInvoiceCount;
  final double revenueThisMonth;
  final int employeesCount;
  final int customersCount;
  final int pendingOrdersCount;
  final List<TopSellingItem> topSellingItems;

  const DashboardModel({
    required this.todaySales,
    required this.todayOrders,
    required this.todayInvoiceCount,
    required this.revenueThisMonth,
    required this.employeesCount,
    required this.customersCount,
    required this.pendingOrdersCount,
    required this.topSellingItems,
  });

  factory DashboardModel.fromJson(Map<String, dynamic> json) {
    final rawTop = json['top_selling_items'] as List? ?? [];
    return DashboardModel(
      todaySales: asDouble(json['today_sales']),
      todayOrders: asInt(json['today_orders']),
      todayInvoiceCount: asInt(json['today_invoice_count']),
      revenueThisMonth: asDouble(json['revenue_this_month']),
      employeesCount: asInt(json['employees_count']),
      customersCount: asInt(json['customers_count']),
      pendingOrdersCount: asInt(json['pending_orders_count']),
      topSellingItems: rawTop
          .map((e) => TopSellingItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  factory DashboardModel.empty() => const DashboardModel(
        todaySales: 0,
        todayOrders: 0,
        todayInvoiceCount: 0,
        revenueThisMonth: 0,
        employeesCount: 0,
        customersCount: 0,
        pendingOrdersCount: 0,
        topSellingItems: [],
      );
}

class TopSellingItem {
  final String name;
  final int totalQuantity;
  final double totalRevenue;

  const TopSellingItem({
    required this.name,
    required this.totalQuantity,
    required this.totalRevenue,
  });

  factory TopSellingItem.fromJson(Map<String, dynamic> json) {
    return TopSellingItem(
      name: json['name'] as String? ?? '',
      totalQuantity: asInt(json['total_quantity']),
      totalRevenue: asDouble(json['total_revenue']),
    );
  }
}
