import 'dart:async';
import 'package:dio/dio.dart';
import 'secure_storage.dart';

// Singleton Dio instance used by all services
late final Dio dio;
Future<void> Function()? _authExpiredHandler;

void setAuthExpiredHandler(Future<void> Function()? handler) {
  _authExpiredHandler = handler;
}

Future<void> notifyAuthExpired({int? expectedRevision}) async {
  if (expectedRevision != null && credentialRevision != expectedRevision) {
    return;
  }
  await _authExpiredHandler?.call();
}

void initApiClient(String baseUrl, {bool includeAuthInterceptor = true}) {
  dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ),
  );
  dio.interceptors.add(_TransientGetRetryInterceptor(dio));
  if (includeAuthInterceptor) {
    dio.interceptors.add(_AuthInterceptor(dio));
  }
}

class _TransientGetRetryInterceptor extends Interceptor {
  final Dio _dio;

  _TransientGetRetryInterceptor(this._dio);

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final request = err.requestOptions;
    final canRetry =
        request.method.toUpperCase() == 'GET' &&
        request.extra['_noTransientRetry'] != true &&
        request.extra['_transientGetRetry'] != true &&
        _isTransient(err);
    if (!canRetry) {
      handler.next(err);
      return;
    }

    request.extra['_transientGetRetry'] = true;
    await Future<void>.delayed(const Duration(milliseconds: 250));
    try {
      handler.resolve(await _dio.fetch(request));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  bool _isTransient(DioException error) {
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return true;
    }
    final status = error.response?.statusCode;
    return status != null && status >= 500 && status <= 599;
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String title;
  final String? detail;
  final String? errorCode;
  final Map<String, String>? fieldErrors;

  ApiException({
    required this.statusCode,
    required this.title,
    this.detail,
    this.errorCode,
    this.fieldErrors,
  });

  @override
  String toString() => 'ApiException($statusCode): $title — $detail';
}

ApiException parseApiError(DioException e) {
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
      errorCode: data['errorCode']?.toString(),
      fieldErrors: fieldErrors.isNotEmpty ? fieldErrors : null,
    );
  }
  return ApiException(
    statusCode: e.response?.statusCode ?? 0,
    title: e.message ?? 'Network error',
  );
}

class _AuthInterceptor extends Interceptor {
  final Dio _dio;
  int? _refreshRevision;
  Future<({String access, int revision})>? _refreshing;
  _AuthInterceptor(this._dio);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra['_skipAuth'] == true) {
      options.headers.remove('Authorization');
      handler.next(options);
      return;
    }
    final credentials = await readCredentials();
    final token = credentials.access;
    if (options.extra.containsKey('_requestAccess') &&
        (options.extra['_requestAccess'] != token ||
            options.extra['_requestCredentialRevision'] !=
                credentials.revision)) {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.cancel,
          error: 'Authentication session changed',
        ),
      );
      return;
    }
    options.extra['_requestAccess'] = token;
    options.extra['_requestCredentialRevision'] = credentials.revision;
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    } else {
      options.headers.remove('Authorization');
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401 &&
        !err.requestOptions.path.contains('/auth/')) {
      final request = err.requestOptions;
      final access = request.extra['_requestAccess'] as String?;
      final requestRevision =
          request.extra['_requestCredentialRevision'] as int?;
      if (access == null ||
          requestRevision == null ||
          request.extra['_authRetried'] == true) {
        handler.reject(err);
        return;
      }
      Future<({String access, int revision})>? pendingRefresh;
      try {
        if (_refreshRevision != requestRevision || _refreshing == null) {
          if (credentialRevision != requestRevision) {
            handler.reject(err);
            return;
          }
          _refreshRevision = requestRevision;
          _refreshing = _refreshTokens(access, requestRevision);
        }
        pendingRefresh = _refreshing!;
        final renewed = await pendingRefresh;
        if (credentialRevision != renewed.revision) {
          handler.reject(err);
          return;
        }
        request.extra['_authRetried'] = true;
        request.extra['_requestAccess'] = renewed.access;
        request.extra['_requestCredentialRevision'] = renewed.revision;
        request.headers['Authorization'] = 'Bearer ${renewed.access}';
        final retried = await _dio.fetch(request);
        handler.resolve(retried);
      } catch (_) {
        if (identical(_refreshing, pendingRefresh)) _refreshing = null;
        handler.reject(err);
      }
      return;
    }
    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        error: parseApiError(err),
        type: err.type,
      ),
    );
  }

  Future<({String access, int revision})> _refreshTokens(
    String access,
    int requestRevision,
  ) async {
    final credentials = await readCredentials();
    if (credentials.access != access ||
        credentials.revision != requestRevision) {
      throw StateError('Authentication session changed');
    }
    final refresh = credentials.refresh;
    if (refresh == null) {
      await _expireCredentials(credentials.revision);
      throw StateError('No refresh token');
    }
    try {
      final response = await _dio.post(
        '/api/v1/auth/refresh',
        data: {'refreshToken': refresh},
        options: Options(extra: {'_skipAuth': true}),
      );
      final newAccess = response.data['data']['accessToken'] as String;
      final newRefresh = response.data['data']['refreshToken'] as String;
      final revision = await replaceTokensIfCurrent(
        expectedRevision: credentials.revision,
        access: newAccess,
        refresh: newRefresh,
      );
      if (revision == null) throw StateError('Authentication session changed');
      return (access: newAccess, revision: revision);
    } catch (error) {
      if (error is DioException &&
          {400, 401, 403}.contains(error.response?.statusCode)) {
        await _expireCredentials(credentials.revision);
      }
      rethrow;
    }
  }

  Future<void> _expireCredentials(int expectedRevision) async {
    final revision = await clearTokensIfCurrent(expectedRevision);
    if (revision != null) await notifyAuthExpired(expectedRevision: revision);
  }
}

// Convenience: unwrap ApiResponse<T>.data
dynamic unwrap(Response res) => res.data['data'];
