import 'package:dio/dio.dart';
import '../network/network.dart';
import '../network/api_endpoints.dart';
import '../models/settings_model.dart';

class SettingsRepository {
  Future<SettingsModel> getSettings() async {
    try {
      final res = await Network.dio.get(ApiEndpoints.settings);
      return SettingsModel.fromJson(
          (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Network.handleError(e);
    }
  }

  /// POST is used (not PUT) because the Laravel route accepts multipart
  /// form data for the optional logo file upload.
  Future<SettingsModel> updateSettings(Map<String, dynamic> body) async {
    try {
      final res = await Network.dio.post(ApiEndpoints.settings, data: body);
      return SettingsModel.fromJson(
          (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Network.handleError(e);
    }
  }
}
