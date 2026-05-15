import 'dart:async';
import 'package:dio/dio.dart';
import 'secure_storage.dart';

// Singleton Dio instance used by all services
late final Dio dio;

void initApiClient(String baseUrl) {
  dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {'Content-Type': 'application/json'},
  ));
  dio.interceptors.add(_AuthInterceptor(dio));
}

class ApiException implements Exception {
  final int statusCode;
  final String title;
  final String? detail;
  final Map<String, String>? fieldErrors;

  ApiException({
    required this.statusCode,
    required this.title,
    this.detail,
    this.fieldErrors,
  });

  @override
  String toString() => 'ApiException($statusCode): $title — $detail';
}

ApiException _parseError(DioException e) {
  final data = e.response?.data;
  if (data is Map) {
    final fieldErrors = <String, String>{};
    if (data['fieldErrors'] is Map) {
      (data['fieldErrors'] as Map).forEach((k, v) {
        fieldErrors[k.toString()] = v.toString();
      });
    }
    return ApiException(
      statusCode: e.response?.statusCode ?? 0,
      title: data['title']?.toString() ?? 'Unknown error',
      detail: data['detail']?.toString(),
      fieldErrors: fieldErrors.isNotEmpty ? fieldErrors : null,
    );
  }
  return ApiException(
    statusCode: e.response?.statusCode ?? 0,
    title: e.message ?? 'Network error',
  );
}

bool _isRefreshing = false;
final _pendingQueue = <Completer<void>>[];

class _AuthInterceptor extends QueuedInterceptorsWrapper {
  final Dio _dio;
  _AuthInterceptor(this._dio);

  @override
  Future<void> onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
      DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401 &&
        !err.requestOptions.path.contains('/auth/')) {
      if (_isRefreshing) {
        final c = Completer<void>();
        _pendingQueue.add(c);
        await c.future;
        final token = await getAccessToken();
        err.requestOptions.headers['Authorization'] = 'Bearer $token';
        try {
          final res = await _dio.fetch(err.requestOptions);
          handler.resolve(res);
          return;
        } catch (e) {
          handler.reject(err);
          return;
        }
      }

      _isRefreshing = true;
      try {
        final refresh = await getRefreshToken();
        if (refresh == null) throw Exception('no refresh token');

        final res = await _dio.post('/api/v1/auth/refresh',
            data: {'refreshToken': refresh},
            options: Options(headers: {'Authorization': null}));

        final newAccess = res.data['data']['accessToken'] as String;
        final newRefresh = res.data['data']['refreshToken'] as String;
        await saveTokens(access: newAccess, refresh: newRefresh);

        for (final c in _pendingQueue) {
          c.complete();
        }
        _pendingQueue.clear();

        err.requestOptions.headers['Authorization'] = 'Bearer $newAccess';
        final retried = await _dio.fetch(err.requestOptions);
        handler.resolve(retried);
      } catch (_) {
        for (final c in _pendingQueue) {
          c.completeError('refresh failed');
        }
        _pendingQueue.clear();
        await clearTokens();
        handler.reject(err);
      } finally {
        _isRefreshing = false;
      }
      return;
    }
    handler.reject(DioException(
      requestOptions: err.requestOptions,
      response: err.response,
      error: _parseError(err),
      type: err.type,
    ));
  }
}

// Convenience: unwrap ApiResponse<T>.data
dynamic unwrap(Response res) => res.data['data'];
