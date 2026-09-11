import 'package:dio/dio.dart';
import '../network/network.dart';
import '../network/api_endpoints.dart';
import '../models/employee_model.dart';
import '../models/api_response.dart';

class EmployeeRepository {
  Future<PaginatedResponse<EmployeeModel>> getEmployees({
    String? search,
    String? role,
    bool? isActive,
    int page = 1,
    int perPage = 50,
  }) async {
    try {
      final res = await Network.dio.get(ApiEndpoints.employees,
          queryParameters: {
            if (search != null && search.isNotEmpty) 'search': search,
            'role': ?role,
            if (isActive != null) 'is_active': isActive.toString(),
            'per_page': perPage,
            'page': page,
          });
      return PaginatedResponse.fromJson(
        (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
        EmployeeModel.fromJson,
      );
    } on DioException catch (e) {
      throw Network.handleError(e);
    }
  }

  Future<List<String>> getRoles() async {
    try {
      final res = await Network.dio.get(ApiEndpoints.employeeRoles);
      final data = (res.data as Map<String, dynamic>)['data'] as List? ?? [];
      return data.map((e) => e.toString()).toList();
    } on DioException catch (e) {
      throw Network.handleError(e);
    }
  }

  Future<EmployeeModel> createEmployee(Map<String, dynamic> body) async {
    try {
      final res = await Network.dio.post(ApiEndpoints.employees, data: body);
      return EmployeeModel.fromJson(
          (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Network.handleError(e);
    }
  }

  Future<EmployeeModel> updateEmployee(dynamic id, Map<String, dynamic> body) async {
    try {
      final res = await Network.dio.put(ApiEndpoints.employee(id), data: body);
      return EmployeeModel.fromJson(
          (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Network.handleError(e);
    }
  }

  Future<EmployeeModel> toggleActive(dynamic id) async {
    try {
      final res = await Network.dio.patch(ApiEndpoints.toggleEmployeeActive(id));
      return EmployeeModel.fromJson(
          (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Network.handleError(e);
    }
  }

  Future<void> deleteEmployee(dynamic id) async {
    try {
      await Network.dio.delete(ApiEndpoints.employee(id));
    } on DioException catch (e) {
      throw Network.handleError(e);
    }
  }
}
