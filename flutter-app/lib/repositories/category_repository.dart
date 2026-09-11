import 'package:dio/dio.dart';
import '../network/network.dart';
import '../platform/platform_support.dart' as platform;
import '../network/api_endpoints.dart';
import '../models/category_model.dart';

class CategoryRepository {
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

  Future<List<CategoryModel>> getActiveCategories() async {
    try {
      final res = await Network.dio.get(ApiEndpoints.activeCategories);
      final items = (res.data as Map<String, dynamic>)['data'] as List? ?? [];
      return items.map((e) => CategoryModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw Network.handleError(e);
    }
  }

  Future<List<CategoryModel>> getAllCategories() async {
    try {
      final res = await Network.dio.get(ApiEndpoints.categories,
          queryParameters: {'per_page': 100});
      final data = (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>?;
      final items = data?['items'] as List? ?? [];
      return items.map((e) => CategoryModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw Network.handleError(e);
    }
  }

  Future<CategoryModel> createCategory(Map<String, dynamic> body,
      {String? imagePath}) async {
    try {
      final data = await _buildBody(body, imagePath);
      final res = await Network.dio.post(ApiEndpoints.categories, data: data);
      return CategoryModel.fromJson(
          (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Network.handleError(e);
    }
  }

  Future<CategoryModel> updateCategory(int id, Map<String, dynamic> body,
      {String? imagePath}) async {
    try {
      final Response res;
      if (imagePath != null) {
        // PUT can't carry a multipart body in PHP — POST with a `_method`
        // override instead; Laravel routes it to the same update() action.
        final data = await _buildBody({...body, '_method': 'PUT'}, imagePath);
        res = await Network.dio.post(ApiEndpoints.category(id), data: data);
      } else {
        res = await Network.dio.put(ApiEndpoints.category(id), data: body);
      }
      return CategoryModel.fromJson(
          (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Network.handleError(e);
    }
  }

  Future<void> deleteCategory(int id) async {
    try {
      await Network.dio.delete(ApiEndpoints.category(id));
    } on DioException catch (e) {
      throw Network.handleError(e);
    }
  }
}
