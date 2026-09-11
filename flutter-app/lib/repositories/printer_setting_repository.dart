import 'package:dio/dio.dart';
import '../network/network.dart';
import '../network/api_endpoints.dart';
import '../models/printer_setting_api_model.dart';

class PrinterSettingRepository {
  Future<List<PrinterSettingApiModel>> getPrinterSettings({String? type}) async {
    try {
      final res = await Network.dio.get(ApiEndpoints.printerSettings,
          queryParameters: {'type': ?type});
      final items = (res.data as Map<String, dynamic>)['data'] as List? ?? [];
      return items
          .map((e) => PrinterSettingApiModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Network.handleError(e);
    }
  }

  Future<PrinterSettingApiModel> createPrinterSetting(Map<String, dynamic> body) async {
    try {
      final res = await Network.dio.post(ApiEndpoints.printerSettings, data: body);
      return PrinterSettingApiModel.fromJson(
          (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Network.handleError(e);
    }
  }

  Future<PrinterSettingApiModel> updatePrinterSetting(int id, Map<String, dynamic> body) async {
    try {
      final res = await Network.dio.put(ApiEndpoints.printerSetting(id), data: body);
      return PrinterSettingApiModel.fromJson(
          (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Network.handleError(e);
    }
  }

  Future<PrinterSettingApiModel> setDefault(int id) async {
    try {
      final res = await Network.dio.patch(ApiEndpoints.setDefaultPrinter(id));
      return PrinterSettingApiModel.fromJson(
          (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Network.handleError(e);
    }
  }

  Future<void> deletePrinterSetting(int id) async {
    try {
      await Network.dio.delete(ApiEndpoints.printerSetting(id));
    } on DioException catch (e) {
      throw Network.handleError(e);
    }
  }
}
