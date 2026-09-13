import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../auth/token_store.dart';
import '../env/app_env.dart';
import '../errors/api_exception.dart';
import 'token_refresher.dart';

/// The single Dio instance for the whole app. Feature repositories are
/// given this [ApiClient] (never a bare `Dio`) so behaviour — auth header,
/// request id, envelope unwrapping, 401 refresh-and-retry, error mapping —
/// is defined exactly once.
///
/// Response envelope (from `backend/internal/response`):
///   success single : { "data": <object> }
///   success list   : { "data": [ ... ], "meta": { limit, offset, total } }
///   error          : { "error": { "code": "...", "message": "..." } }
///
/// [get]/[post]/... return the already-unwrapped `data` (as `dynamic`);
/// [getList] additionally returns `meta`. Every failure is thrown as an
/// [ApiException].
class ApiClient {
  factory ApiClient({
    required TokenStore tokenStore,
    required TokenRefresher tokenRefresher,
    Dio? dio,
  }) => ApiClient._(tokenStore, tokenRefresher, dio ?? Dio());

  ApiClient._(this._tokenStore, this._tokenRefresher, this._dio) {
    _configure();
  }

  void _configure() {
    _dio.options
      ..baseUrl = AppEnv.apiBaseUrl
      ..connectTimeout = AppEnv.connectTimeout
      ..receiveTimeout = AppEnv.receiveTimeout
      ..contentType = Headers.jsonContentType
      ..responseType = ResponseType.json
      // We validate status ourselves so the 401 interceptor can act.
      ..validateStatus = (status) => status != null && status < 500;

    _dio.interceptors.add(_authAndRetryInterceptor());
    if (AppEnv.enableNetworkLogging) {
      _dio.interceptors.add(_redactingLogInterceptor());
    }
  }

  final Dio _dio;
  final TokenStore _tokenStore;
  final TokenRefresher _tokenRefresher;
  static const _uuid = Uuid();

  /// Shared single-flight refresh — concurrent 401s wait on one call.
  Future<String?>? _refreshInFlight;

  // ---------------------------------------------------------------------------
  // Public verbs
  // ---------------------------------------------------------------------------

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) => _send(
    () => _dio.get<dynamic>(
      path,
      queryParameters: _clean(query),
      cancelToken: cancelToken,
    ),
  );

  Future<({dynamic data, ApiListMeta meta})> getList(
    String path, {
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) async {
    final res = await _sendRaw(
      () => _dio.get<dynamic>(
        path,
        queryParameters: _clean(query),
        cancelToken: cancelToken,
      ),
    );
    final body = res.data;
    if (body is Map) {
      return (
        data: body['data'],
        meta: ApiListMeta.fromJson(body['meta'] as Map?),
      );
    }
    throw ApiException.parse();
  }

  Future<dynamic> post(
    String path, {
    Object? body,
    Map<String, dynamic>? headers,
  }) => _send(
    () => _dio.post<dynamic>(
      path,
      data: body,
      options: Options(headers: headers),
    ),
  );

  Future<dynamic> put(String path, {Object? body}) =>
      _send(() => _dio.put<dynamic>(path, data: body));

  Future<dynamic> patch(String path, {Object? body}) =>
      _send(() => _dio.patch<dynamic>(path, data: body));

  Future<dynamic> delete(String path, {Object? body}) =>
      _send(() => _dio.delete<dynamic>(path, data: body));

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  Future<dynamic> _send(Future<Response<dynamic>> Function() run) async {
    final res = await _sendRaw(run);
    final body = res.data;
    if (body is Map && body.containsKey('data')) return body['data'];
    // Some endpoints (204-ish) may return an empty body.
    return body;
  }

  Future<Response<dynamic>> _sendRaw(
    Future<Response<dynamic>> Function() run,
  ) async {
    try {
      final res = await run();
      if (res.statusCode != null && res.statusCode! >= 400) {
        throw DioException(
          requestOptions: res.requestOptions,
          response: res,
          type: DioExceptionType.badResponse,
        );
      }
      return res;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Interceptor _authAndRetryInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) {
        options.headers['X-Request-ID'] = _uuid.v4();
        // A native client identifies itself so the backend can return the
        // refresh token in the body instead of an HttpOnly cookie
        // (see docs/AUTH_COMPAT.md). Harmless if the backend ignores it.
        options.headers['X-Client'] = 'nova-mobile';
        final token = _tokenStore.accessToken;
        if (token != null && !_noBearer(options.path)) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onResponse: (response, handler) async {
        final status = response.statusCode ?? 0;
        final isRetry = response.requestOptions.extra['__retried'] == true;
        if (status == 401 &&
            !_noRefreshRetry(response.requestOptions.path) &&
            !isRetry) {
          final newToken = await _refreshOnce();
          if (newToken != null) {
            final opts = response.requestOptions
              ..extra['__retried'] = true
              ..headers['Authorization'] = 'Bearer $newToken';
            try {
              final retried = await _dio.fetch<dynamic>(opts);
              return handler.resolve(retried);
            } on DioException catch (e) {
              return handler.reject(e);
            }
          }
          _tokenRefresher.onSessionExpired();
        }
        handler.next(response);
      },
    );
  }

  Future<String?> _refreshOnce() {
    return _refreshInFlight ??= _tokenRefresher.refresh().whenComplete(() {
      _refreshInFlight = null;
    });
  }

  Interceptor _redactingLogInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) {
        debugPrint('→ ${options.method} ${options.uri}');
        handler.next(options);
      },
      onResponse: (response, handler) {
        debugPrint('← ${response.statusCode} ${response.requestOptions.uri}');
        handler.next(response);
      },
      onError: (e, handler) {
        debugPrint(
          '✗ ${e.response?.statusCode ?? e.type} ${e.requestOptions.uri}',
        );
        handler.next(e);
      },
    );
  }

  /// The four endpoints that carry the refresh credential themselves —
  /// they take NO `Authorization` header (login/register/refresh are
  /// pre-auth; plain logout uses the refresh token). `/auth/me` and
  /// `/auth/logout-all` are NOT in this set: they need the bearer.
  static bool _noBearer(String path) =>
      path.endsWith('/auth/login') ||
      path.endsWith('/auth/register') ||
      path.endsWith('/auth/refresh') ||
      path.endsWith('/auth/logout');

  /// Never run the 401 → refresh → retry loop for the token-transport
  /// endpoints (recursion) or for logout-all (pointless — you're leaving).
  static bool _noRefreshRetry(String path) =>
      _noBearer(path) || path.endsWith('/auth/logout-all');

  static Map<String, dynamic>? _clean(Map<String, dynamic>? query) {
    if (query == null) return null;
    final out = <String, dynamic>{};
    query.forEach((k, v) {
      if (v == null) return;
      if (v is String && v.isEmpty) return;
      out[k] = v;
    });
    return out.isEmpty ? null : out;
  }
}

/// Pagination metadata mirrored from the backend's `meta` object.
class ApiListMeta {
  const ApiListMeta({
    required this.limit,
    required this.offset,
    required this.total,
  });

  final int limit;
  final int offset;
  final int total;

  bool get hasMore => offset + limit < total;

  factory ApiListMeta.fromJson(Map<dynamic, dynamic>? json) {
    if (json == null) return const ApiListMeta(limit: 0, offset: 0, total: 0);
    return ApiListMeta(
      limit: (json['limit'] as num?)?.toInt() ?? 0,
      offset: (json['offset'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }
}
