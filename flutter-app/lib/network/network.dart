import 'package:dio/dio.dart';
import '../storage/hive_storage.dart';
import '../core/api_exception.dart';

/// Single source of truth for all HTTP communication.
/// Every repository must use [Network.dio] — never create a Dio instance elsewhere.
class Network {
  // ── Base URL ────────────────────────────────────────────────
  // HTTPS is mandatory: Android 9+ blocks cleartext HTTP in release
  // builds, and the Bearer token must never travel unencrypted.
  // TEMP (local print-flow test — revert before release):

  // Overridable at build time for local/staging testing:
  //   flutter build web --dart-define=API_BASE_URL=http://127.0.0.1:8000/api
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://casher.jiljam.com/api',
  );

  static const int _connectTimeoutMs = 20000;
  static const int _receiveTimeoutMs = 20000;
  static const int _sendTimeoutMs    = 20000;

  static const String _tokenKey = 'authToken';

  // ── Dio singleton ───────────────────────────────────────────
  static late final Dio _dio;
  static bool _initialized = false;

  /// Call [Network.init()] once in main() after HiveStorage.init().
  /// Every subsequent access uses the same Dio instance.
  static void init() {
    if (_initialized) return;

    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(milliseconds: _connectTimeoutMs),
        receiveTimeout: const Duration(milliseconds: _receiveTimeoutMs),
        sendTimeout:    const Duration(milliseconds: _sendTimeoutMs),
        headers: {
          'Accept':       'application/json',
          'Content-Type': 'application/json',
        },
        responseType: ResponseType.json,
      ),
    );

    _dio.interceptors.add(_buildAuthInterceptor());
    _dio.interceptors.add(_buildErrorInterceptor());

    _initialized = true;
  }

  static Dio get dio {
    assert(_initialized, 'Call Network.init() before accessing Network.dio');
    return _dio;
  }

  // ── Authorization interceptor ────────────────────────────────
  /// Attaches the stored Sanctum Bearer token to every outgoing request.
  static Interceptor _buildAuthInterceptor() {
    return InterceptorsWrapper(
      onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
        final t = token;
        if (t != null && t.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $t';
          // cPanel strips Authorization on shared hosting; the backend
          // reads X-Auth-Token as its primary token source.
          options.headers['X-Auth-Token'] = t;
        }
        handler.next(options);
      },
    );
  }

  // ── Response / Error interceptor ────────────────────────────
  /// Clears the stored token when the server returns 401.
  static Interceptor _buildErrorInterceptor() {
    return InterceptorsWrapper(
      onResponse: (Response response, ResponseInterceptorHandler handler) {
        handler.next(response);
      },
      onError: (DioException err, ErrorInterceptorHandler handler) {
        if (err.response?.statusCode == 401) {
          // Token expired or revoked — clear local copy so the
          // AuthController reactive var goes null and AuthGate
          // navigates back to LoginScreen automatically.
          clearToken();
        }
        handler.next(err);
      },
    );
  }

  // ── Token helpers ─────────────────────────────────────────────
  static String? get token =>
      HiveStorage.settings.get(_tokenKey) as String?;

  static Future<void> saveToken(String t) =>
      HiveStorage.settings.put(_tokenKey, t);

  static Future<void> clearToken() =>
      HiveStorage.settings.delete(_tokenKey);

  // ── DioException → ApiException ──────────────────────────────
  /// Call this inside every repository catch block.
  static ApiException handleError(DioException e) {
    final res = e.response;

    if (res != null) {
      final data = res.data;
      String message = 'حدث خطأ في الخادم';
      Map<String, dynamic>? errors;

      if (data is Map<String, dynamic>) {
        message = data['message'] as String? ?? message;
        errors  = data['errors']  as Map<String, dynamic>?;
      }

      return ApiException(
        message:    message,
        statusCode: res.statusCode,
        errors:     errors,
      );
    }

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return const ApiException(
          message:    'انتهت مهلة الاتصال. تحقق من الشبكة',
          statusCode: 408,
        );
      case DioExceptionType.connectionError:
        return const ApiException(
          message:    'تعذر الاتصال بالخادم. تحقق من إعدادات الشبكة',
          statusCode: 0,
        );
      default:
        return ApiException(message: e.message ?? 'خطأ غير معروف');
    }
  }
}