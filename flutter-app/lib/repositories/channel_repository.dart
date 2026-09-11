import 'package:dio/dio.dart';
import '../network/network.dart';
import '../network/api_endpoints.dart';
import '../models/channel_model.dart';

class ChannelRepository {
  /// Active sales channels for the POS channel selector.
  Future<List<ChannelModel>> getChannels({bool includeInactive = false}) async {
    try {
      final res = await Network.dio.get(
        ApiEndpoints.channels,
        queryParameters: {if (includeInactive) 'all': 1},
      );
      final data = (res.data as Map<String, dynamic>)['data'] as List? ?? [];
      return data
          .map((e) => ChannelModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Network.handleError(e);
    }
  }

  /// Effective prices for one channel, as {menuItemId: price}. Only items
  /// sellable on the channel are returned, so an id missing from this map
  /// means "hidden from this channel".
  Future<Map<String, double>> getChannelPrices(String code) async {
    try {
      final res = await Network.dio.get(ApiEndpoints.channelMenu(code));
      final data = (res.data as Map<String, dynamic>)['data'] as List? ?? [];
      return {
        for (final row in data.cast<Map<String, dynamic>>())
          row['id'].toString(): (row['price'] as num).toDouble(),
      };
    } on DioException catch (e) {
      throw Network.handleError(e);
    }
  }

  /// Update a channel's commission rate / activation.
  Future<ChannelModel> updateChannel(
      String code, Map<String, dynamic> body) async {
    try {
      final res = await Network.dio.patch(ApiEndpoints.channel(code), data: body);
      return ChannelModel.fromJson(
          (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Network.handleError(e);
    }
  }

  /// Bulk upsert of per-channel price overrides.
  Future<void> syncPrices(String code, List<Map<String, dynamic>> prices) async {
    try {
      await Network.dio
          .post(ApiEndpoints.channelPrices(code), data: {'prices': prices});
    } on DioException catch (e) {
      throw Network.handleError(e);
    }
  }

  /// Unified multi-channel sales summary.
  Future<ChannelSalesReport> getSalesByChannel({
    String? dateFrom,
    String? dateTo,
  }) async {
    try {
      final res = await Network.dio.get(
        ApiEndpoints.reportByChannel,
        queryParameters: {
          'date_from': ?dateFrom,
          'date_to': ?dateTo,
        },
      );
      return ChannelSalesReport.fromJson(
          (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Network.handleError(e);
    }
  }
}
