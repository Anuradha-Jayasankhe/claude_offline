import 'package:dio/dio.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static const String _defaultBaseUrl = 'http://localhost:3000/api';
  static const String configuredBaseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: _defaultBaseUrl,
  );

  final String baseUrl;
  late final Dio _dio;

  ApiClient({String? baseUrl}) : baseUrl = baseUrl ?? configuredBaseUrl {
    _dio = Dio(
      BaseOptions(
        baseUrl: this.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    _dio.interceptors.add(AuthInterceptor());
    _dio.interceptors.add(TenantInterceptor());
    _dio.interceptors.add(
      LogInterceptor(requestBody: true, responseBody: true),
    );
  }

  Dio get dio => _dio;

  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    return _dio.get(path, queryParameters: queryParameters);
  }

  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    return _dio.post(path, data: data, queryParameters: queryParameters);
  }

  Future<Response> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    return _dio.put(path, data: data, queryParameters: queryParameters);
  }

  Future<Response> delete(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    return _dio.delete(path, queryParameters: queryParameters);
  }
}

class AuthInterceptor extends Interceptor {
  bool _isExpiredJwt(String token) {
    if (token.startsWith('platform-session-token') ||
        token.startsWith('store-session-token-')) {
      return false;
    }

    try {
      return JwtDecoder.isExpired(token);
    } catch (_) {
      return true;
    }
  }

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token != null && !_isExpiredJwt(token)) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      // Token expired, try to refresh
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString('refresh_token');

      if (refreshToken != null) {
        try {
          final dio = Dio(BaseOptions(baseUrl: err.requestOptions.baseUrl));
          final response = await dio.post(
            '/auth/refresh',
            data: {'refreshToken': refreshToken},
          );

          if (response.statusCode == 200) {
            final newToken = response.data['token'];
            await prefs.setString('auth_token', newToken);

            // Retry the original request with new token
            err.requestOptions.headers['Authorization'] = 'Bearer $newToken';
            final retryResponse = await dio.request(
              err.requestOptions.path,
              options: Options(
                method: err.requestOptions.method,
                headers: err.requestOptions.headers,
              ),
              data: err.requestOptions.data,
              queryParameters: err.requestOptions.queryParameters,
            );

            return handler.resolve(retryResponse);
          }
        } catch (e) {
          // Refresh failed, logout user
          await prefs.clear();
        }
      }
    }

    handler.next(err);
  }
}

class TenantInterceptor extends Interceptor {
  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final tenantId = prefs.getString('tenant_id');

    if (tenantId != null) {
      options.headers['x-tenant-id'] = tenantId;
    }

    handler.next(options);
  }
}
