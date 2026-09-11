import 'package:dio/dio.dart';
import '../network/network.dart';
import '../network/api_endpoints.dart';
import '../models/delivery_area_model.dart';

class DeliveryAreaRepository {
  Future<List<DeliveryAreaModel>> getActiveAreas() async {
    try {
      final res = await Network.dio.get(ApiEndpoints.activeDeliveryAreas);
      final items = (res.data as Map<String, dynamic>)['data'] as List? ?? [];
      return items.map((e) => DeliveryAreaModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw Network.handleError(e);
    }
  }

  Future<List<DeliveryAreaModel>> getAllAreas() async {
    try {
      final res = await Network.dio.get(ApiEndpoints.deliveryAreas,
          queryParameters: {'per_page': 100});
      final data = (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>?;
      final items = data?['items'] as List? ?? [];
      return items.map((e) => DeliveryAreaModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw Network.handleError(e);
    }
  }

  Future<DeliveryAreaModel> createArea(Map<String, dynamic> body) async {
    try {
      final res = await Network.dio.post(ApiEndpoints.deliveryAreas, data: body);
      return DeliveryAreaModel.fromJson(
          (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Network.handleError(e);
    }
  }

  Future<DeliveryAreaModel> updateArea(dynamic id, Map<String, dynamic> body) async {
    try {
      final res = await Network.dio.put(ApiEndpoints.deliveryArea(id), data: body);
      return DeliveryAreaModel.fromJson(
          (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Network.handleError(e);
    }
  }

  Future<DeliveryAreaModel> toggleActive(dynamic id) async {
    try {
      final res = await Network.dio.patch(ApiEndpoints.toggleDeliveryAreaActive(id));
      return DeliveryAreaModel.fromJson(
          (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Network.handleError(e);
    }
  }

  Future<void> deleteArea(dynamic id) async {
    try {
      await Network.dio.delete(ApiEndpoints.deliveryArea(id));
    } on DioException catch (e) {
      throw Network.handleError(e);
    }
  }
}
