import 'package:dio/dio.dart';
import '../network/network.dart';
import '../platform/platform_support.dart' as platform;
import '../network/api_endpoints.dart';
import '../models/menu_item_model.dart';
import '../models/api_response.dart';

class MenuItemRepository {
  static String _fileName(String path) =>
      path.replaceAll('\\', '/').split('/').last;

  /// Builds multipart form data when [imagePath] is set (required for file
  /// uploads — PUT/PATCH requests can't carry multipart bodies in PHP, so
  /// updates route through POST with a `_method` override instead).
  ///
  /// Multipart fields are always plain text, so bools must become '1'/'0' —
  /// Laravel's `boolean` rule strictly rejects the literal strings
  /// "true"/"false" that a raw toString() would otherwise produce.
  Future<dynamic> _buildBody(
      Map<String, dynamic> fields, String? imagePath) async {
    if (imagePath == null) return fields;
    final normalized = fields.map((key, value) =>
        MapEntry(key, value is bool ? (value ? '1' : '0') : value));
    return FormData.fromMap({
      ...normalized,
      'image': await platform.multipartFromPath(imagePath,
          filename: _fileName(imagePath)),
    });
  }

  Future<List<MenuItemModel>> getAvailableItems({int? categoryId}) async {
    try {
      final res = await Network.dio.get(ApiEndpoints.availableMenuItems,
          queryParameters: {
            'category_id': ?categoryId,
          });
      final items = (res.data as Map<String, dynamic>)['data'] as List? ?? [];
      return items.map((e) => MenuItemModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw Network.handleError(e);
    }
  }

  Future<PaginatedResponse<MenuItemModel>> getMenuItems({
    String? search,
    int? categoryId,
    bool? isAvailable,
    int perPage = 100,
  }) async {
    try {
      final res = await Network.dio.get(ApiEndpoints.menuItems,
          queryParameters: {
            if (search != null && search.isNotEmpty) 'search': search,
            'category_id': ?categoryId,
            if (isAvailable != null) 'is_available': isAvailable.toString(),
            'per_page': perPage,
          });
      return PaginatedResponse.fromJson(
        (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
        MenuItemModel.fromJson,
      );
    } on DioException catch (e) {
      throw Network.handleError(e);
    }
  }

  Future<MenuItemModel> createMenuItem(Map<String, dynamic> body,
      {String? imagePath}) async {
    try {
      final data = await _buildBody(body, imagePath);
      final res = await Network.dio.post(ApiEndpoints.menuItems, data: data);
      return MenuItemModel.fromJson(
          (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Network.handleError(e);
    }
  }

  Future<MenuItemModel> updateMenuItem(dynamic id, Map<String, dynamic> body,
      {String? imagePath}) async {
    try {
      final Response res;
      if (imagePath != null) {
        // PUT can't carry a multipart body in PHP — POST with a `_method`
        // override instead; Laravel routes it to the same update() action.
        final data = await _buildBody({...body, '_method': 'PUT'}, imagePath);
        res = await Network.dio.post(ApiEndpoints.menuItem(id), data: data);
      } else {
        res = await Network.dio.put(ApiEndpoints.menuItem(id), data: body);
      }
      return MenuItemModel.fromJson(
          (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Network.handleError(e);
    }
  }

  Future<MenuItemModel> toggleAvailability(dynamic id) async {
    try {
      final res = await Network.dio.patch(ApiEndpoints.toggleMenuItemAvailability(id));
      return MenuItemModel.fromJson(
          (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Network.handleError(e);
    }
  }

  Future<void> deleteMenuItem(dynamic id) async {
    try {
      await Network.dio.delete(ApiEndpoints.menuItem(id));
    } on DioException catch (e) {
      throw Network.handleError(e);
    }
  }
}
