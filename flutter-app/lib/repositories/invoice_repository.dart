import 'package:dio/dio.dart';
import '../network/network.dart';
import '../network/api_endpoints.dart';
import '../models/invoice_model.dart';
import '../models/api_response.dart';

class InvoiceRepository {
  Future<PaginatedResponse<InvoiceModel>> getInvoices({
    String? search,
    String? status,
    String? orderType,
    String? dateFrom,
    String? dateTo,
    int page = 1,
    int perPage = 20,
    String sortDir = 'desc',
  }) async {
    try {
      final res = await Network.dio.get(ApiEndpoints.invoices,
          queryParameters: {
            if (search != null && search.isNotEmpty) 'search': search,
            'status': ?status,
            'order_type': ?orderType,
            'date_from': ?dateFrom,
            'date_to': ?dateTo,
            'page': page,
            'per_page': perPage,
            'sort_dir': sortDir,
          });
      return PaginatedResponse.fromJson(
        (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
        InvoiceModel.fromJson,
      );
    } on DioException catch (e) {
      throw Network.handleError(e);
    }
  }

  Future<InvoiceModel> createInvoice(Map<String, dynamic> body) async {
    try {
      final res = await Network.dio.post(ApiEndpoints.invoices, data: body);
      return InvoiceModel.fromJson(
          (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Network.handleError(e);
    }
  }

  Future<InvoiceModel> getInvoice(dynamic id) async {
    try {
      final res = await Network.dio.get(ApiEndpoints.invoice(id));
      return InvoiceModel.fromJson(
          (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Network.handleError(e);
    }
  }

  Future<Map<String, dynamic>> getPrintData(dynamic id) async {
    try {
      final res = await Network.dio.get(ApiEndpoints.invoicePrintData(id));
      return (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Network.handleError(e);
    }
  }

  Future<InvoiceModel> markPaid(dynamic id, {String paymentMethod = 'cash'}) async {
    try {
      final res = await Network.dio.patch(ApiEndpoints.markInvoicePaid(id),
          data: {'payment_method': paymentMethod});
      return InvoiceModel.fromJson(
          (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Network.handleError(e);
    }
  }

  Future<InvoiceModel> refund(dynamic id) async {
    try {
      final res = await Network.dio.patch(ApiEndpoints.refundInvoice(id));
      return InvoiceModel.fromJson(
          (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Network.handleError(e);
    }
  }

  Future<InvoiceModel> cancel(dynamic id) async {
    try {
      final res = await Network.dio.patch(ApiEndpoints.cancelInvoice(id));
      return InvoiceModel.fromJson(
          (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Network.handleError(e);
    }
  }

  Future<void> deleteInvoice(dynamic id) async {
    try {
      await Network.dio.delete(ApiEndpoints.invoice(id));
    } on DioException catch (e) {
      throw Network.handleError(e);
    }
  }
}
