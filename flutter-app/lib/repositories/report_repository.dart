import 'package:dio/dio.dart';
import '../network/network.dart';
import '../network/api_endpoints.dart';

class ReportRepository {
  Future<Map<String, dynamic>> getDailyReport(
      {String? date, String? orderType}) async {
    try {
      final res = await Network.dio.get(ApiEndpoints.reportDaily,
          queryParameters: {
            'date': ?date,
            'order_type': ?orderType,
          });
      return (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>? ?? {};
    } on DioException catch (e) {
      throw Network.handleError(e);
    }
  }

  Future<Map<String, dynamic>> getRangeReport(
      {String? dateFrom, String? dateTo, String? orderType}) async {
    try {
      final res = await Network.dio.get(ApiEndpoints.reportRange,
          queryParameters: {
            'date_from': ?dateFrom,
            'date_to': ?dateTo,
            'order_type': ?orderType,
          });
      return (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>? ?? {};
    } on DioException catch (e) {
      throw Network.handleError(e);
    }
  }

  Future<Map<String, dynamic>> getWeeklyReport(
      {String? startDate, String? orderType}) async {
    try {
      final res = await Network.dio.get(ApiEndpoints.reportWeekly,
          queryParameters: {
            'start_date': ?startDate,
            'order_type': ?orderType,
          });
      return (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>? ?? {};
    } on DioException catch (e) {
      throw Network.handleError(e);
    }
  }

  Future<Map<String, dynamic>> getMonthlyReport(
      {int? year, int? month, String? orderType}) async {
    try {
      final res = await Network.dio.get(ApiEndpoints.reportMonthly,
          queryParameters: {
            'year': ?year,
            'month': ?month,
            'order_type': ?orderType,
          });
      return (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>? ?? {};
    } on DioException catch (e) {
      throw Network.handleError(e);
    }
  }

  /// Full itemized quantities sold in a date range (defaults to today on
  /// the backend) — no limit, unlike best-selling-items. `data['items']`
  /// is the detailed list, `data['items_map']` is {"Burger": 20, ...}.
  Future<Map<String, dynamic>> getItemizedReport({
    String? dateFrom,
    String? dateTo,
    String? orderType,
    int? productId,
    int? categoryId,
  }) async {
    try {
      final res = await Network.dio.get(ApiEndpoints.reportItemized,
          queryParameters: {
            'date_from': ?dateFrom,
            'date_to': ?dateTo,
            'order_type': ?orderType,
            'product_id': ?productId,
            'category_id': ?categoryId,
          });
      return (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>? ?? {};
    } on DioException catch (e) {
      throw Network.handleError(e);
    }
  }

  /// Product × order-source pivot: every product sold in the range with its
  /// quantity and revenue per channel, aggregated server-side. Parse with
  /// [ProductSalesReport.fromJson].
  Future<Map<String, dynamic>> getProductSalesByChannel({
    String? dateFrom,
    String? dateTo,
    String? orderType,
    int? productId,
    int? categoryId,
  }) async {
    try {
      final res = await Network.dio.get(ApiEndpoints.reportProductSalesByChannel,
          queryParameters: {
            'date_from': ?dateFrom,
            'date_to': ?dateTo,
            'order_type': ?orderType,
            'product_id': ?productId,
            'category_id': ?categoryId,
          });
      return (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>? ?? {};
    } on DioException catch (e) {
      throw Network.handleError(e);
    }
  }

  Future<List<dynamic>> getBestSellingItems({
    String? dateFrom,
    String? dateTo,
    int limit = 20,
  }) async {
    try {
      final res = await Network.dio.get(ApiEndpoints.reportBestSelling,
          queryParameters: {
            'date_from': ?dateFrom,
            'date_to': ?dateTo,
            'limit': limit,
          });
      return (res.data as Map<String, dynamic>)['data'] as List? ?? [];
    } on DioException catch (e) {
      throw Network.handleError(e);
    }
  }

  Future<List<dynamic>> getSalesByEmployee({String? dateFrom, String? dateTo}) async {
    try {
      final res = await Network.dio.get(ApiEndpoints.reportByEmployee,
          queryParameters: {
            'date_from': ?dateFrom,
            'date_to': ?dateTo,
          });
      return (res.data as Map<String, dynamic>)['data'] as List? ?? [];
    } on DioException catch (e) {
      throw Network.handleError(e);
    }
  }

  Future<List<dynamic>> getSalesByDeliveryArea({String? dateFrom, String? dateTo}) async {
    try {
      final res = await Network.dio.get(ApiEndpoints.reportByDeliveryArea,
          queryParameters: {
            'date_from': ?dateFrom,
            'date_to': ?dateTo,
          });
      return (res.data as Map<String, dynamic>)['data'] as List? ?? [];
    } on DioException catch (e) {
      throw Network.handleError(e);
    }
  }

  Future<List<dynamic>> getSalesByCategory({String? dateFrom, String? dateTo}) async {
    try {
      final res = await Network.dio.get(ApiEndpoints.reportByCategory,
          queryParameters: {
            'date_from': ?dateFrom,
            'date_to': ?dateTo,
          });
      return (res.data as Map<String, dynamic>)['data'] as List? ?? [];
    } on DioException catch (e) {
      throw Network.handleError(e);
    }
  }
}
