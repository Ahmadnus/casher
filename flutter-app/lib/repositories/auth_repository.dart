import 'package:dio/dio.dart';
import '../network/network.dart';
import '../network/api_endpoints.dart';
import '../models/employee_model.dart';

class AuthRepository {
  Future<Map<String, dynamic>> loginWithCredentials({
    required String username,
    required String password,
    String deviceName = 'Flutter POS',
  }) async {
    try {
      final res = await Network.dio.post(ApiEndpoints.login, data: {
        'mode': 'credentials',
        'username': username,
        'password': password,
        'device_name': deviceName,
        'remember': true,
      });
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Network.handleError(e);
    }
  }

  Future<Map<String, dynamic>> loginWithPin({
    required String pin,
    String deviceName = 'Flutter POS',
  }) async {
    try {
      final res = await Network.dio.post(ApiEndpoints.login, data: {
        'mode': 'pin',
        'pin': pin,
        'device_name': deviceName,
      });
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Network.handleError(e);
    }
  }

  Future<EmployeeModel?> getMe() async {
    try {
      final res = await Network.dio.get(ApiEndpoints.me);
      final data = (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>?;
      return data != null ? EmployeeModel.fromJson(data) : null;
    } on DioException catch (e) {
      throw Network.handleError(e);
    }
  }

  Future<void> logout() async {
    try {
      await Network.dio.post(ApiEndpoints.logout);
    } on DioException catch (e) {
      throw Network.handleError(e);
    }
  }

  Future<void> logoutAll() async {
    try {
      await Network.dio.post(ApiEndpoints.logoutAll);
    } on DioException catch (e) {
      throw Network.handleError(e);
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await Network.dio.post(ApiEndpoints.changePassword, data: {
        'current_password': currentPassword,
        'password': newPassword,
        'password_confirmation': newPassword,
      });
    } on DioException catch (e) {
      throw Network.handleError(e);
    }
  }
}
