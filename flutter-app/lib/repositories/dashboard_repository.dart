import 'package:dio/dio.dart';
import '../network/network.dart';
import '../network/api_endpoints.dart';
import '../models/dashboard_model.dart';

class DashboardRepository {
  Future<DashboardModel> getSummary() async {
    try {
      final res = await Network.dio.get(ApiEndpoints.dashboard);
      return DashboardModel.fromJson(
          (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Network.handleError(e);
    }
  }
}
