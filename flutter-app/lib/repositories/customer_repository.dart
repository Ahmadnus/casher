import 'package:dio/dio.dart';
import '../network/network.dart';
import '../network/api_endpoints.dart';
import '../models/customer_model.dart';
import '../models/api_response.dart';

class CustomerRepository {
  Future<PaginatedResponse<CustomerModel>> getCustomers({
    String? search,
    int perPage = 20,
  }) async {
    try {
      final res = await Network.dio.get(ApiEndpoints.customers,
          queryParameters: {
            if (search != null && search.isNotEmpty) 'search': search,
            'per_page': perPage,
          });
      return PaginatedResponse.fromJson(
        (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
        CustomerModel.fromJson,
      );
    } on DioException catch (e) {
      throw Network.handleError(e);
    }
  }

  Future<CustomerModel?> findByPhone(String phone) async {
    try {
      final res = await Network.dio.get(ApiEndpoints.customerByPhone,
          queryParameters: {'phone': phone});
      final data = (res.data as Map<String, dynamic>)['data'];
      if (data == null) return null;
      return CustomerModel.fromJson(data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Network.handleError(e);
    }
  }

  Future<CustomerModel> createCustomer(Map<String, dynamic> body) async {
    try {
      final res = await Network.dio.post(ApiEndpoints.customers, data: body);
      return CustomerModel.fromJson(
          (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Network.handleError(e);
    }
  }

  Future<CustomerModel> updateCustomer(int id, Map<String, dynamic> body) async {
    try {
      final res = await Network.dio.put(ApiEndpoints.customer(id), data: body);
      return CustomerModel.fromJson(
          (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Network.handleError(e);
    }
  }

  Future<void> deleteCustomer(int id) async {
    try {
      await Network.dio.delete(ApiEndpoints.customer(id));
    } on DioException catch (e) {
      throw Network.handleError(e);
    }
  }
}
