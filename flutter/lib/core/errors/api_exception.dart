import 'package:dio/dio.dart';

/// A single, typed error surface for everything the API layer can throw.
///
/// The Go backend always answers errors as
/// `{ "error": { "code": "...", "message": "..." } }` with a matching HTTP
/// status (see `backend/internal/response`). [ApiException] carries both
/// the machine [code] (for logic + localized copy) and a safe fallback
/// [message] (already client-safe on the backend side — never a stack
/// trace or SQL text).
///
/// UI never renders raw JSON: it switches on [code] / [kind] and shows a
/// localized string (see `AppStrings.apiError`).
class ApiException implements Exception {
  ApiException({
    required this.kind,
    required this.code,
    required this.message,
    this.statusCode,
  });

  final ApiErrorKind kind;

  /// Backend error code (e.g. `INVALID_CREDENTIALS`, `INSUFFICIENT_STOCK`)
  /// or one of the synthetic codes below for transport-level failures.
  final String code;

  /// Client-safe fallback message from the backend, or a generic one for
  /// transport failures. Prefer a localized string keyed off [code].
  final String message;

  final int? statusCode;

  bool get isUnauthorized => kind == ApiErrorKind.unauthorized;
  bool get isForbidden => kind == ApiErrorKind.forbidden;
  bool get isNetwork => kind == ApiErrorKind.network;

  // ---- Synthetic codes (no backend equivalent) ----
  static const codeNetwork = 'NETWORK_ERROR';
  static const codeTimeout = 'TIMEOUT';
  static const codeCancelled = 'CANCELLED';
  static const codeParse = 'PARSE_ERROR';
  static const codeUnknown = 'UNKNOWN_ERROR';

  /// Builds an [ApiException] from any [DioException], mapping HTTP status
  /// and the backend error envelope onto [ApiErrorKind] + [code].
  factory ApiException.fromDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return ApiException(
          kind: ApiErrorKind.timeout,
          code: codeTimeout,
          message: 'The server took too long to respond.',
        );
      case DioExceptionType.connectionError:
      case DioExceptionType.badCertificate:
        return ApiException(
          kind: ApiErrorKind.network,
          code: codeNetwork,
          message: 'Could not reach the server.',
        );
      case DioExceptionType.cancel:
        return ApiException(
          kind: ApiErrorKind.cancelled,
          code: codeCancelled,
          message: 'Request cancelled.',
        );
      case DioExceptionType.badResponse:
        return ApiException._fromResponse(e.response);
      case DioExceptionType.unknown:
        return ApiException(
          kind: ApiErrorKind.unknown,
          code: codeUnknown,
          message: 'Something went wrong.',
        );
    }
  }

  factory ApiException._fromResponse(Response<dynamic>? response) {
    final status = response?.statusCode ?? 0;
    String code = codeUnknown;
    String message = 'Something went wrong.';

    final data = response?.data;
    if (data is Map && data['error'] is Map) {
      final err = data['error'] as Map;
      code = (err['code'] as String?)?.trim().isNotEmpty == true
          ? err['code'] as String
          : code;
      message = (err['message'] as String?)?.trim().isNotEmpty == true
          ? err['message'] as String
          : message;
    }

    final kind = switch (status) {
      401 => ApiErrorKind.unauthorized,
      403 => ApiErrorKind.forbidden,
      404 => ApiErrorKind.notFound,
      409 => ApiErrorKind.conflict,
      422 => ApiErrorKind.validation,
      429 => ApiErrorKind.rateLimited,
      >= 500 => ApiErrorKind.server,
      _ when status >= 400 => ApiErrorKind.validation,
      _ => ApiErrorKind.unknown,
    };

    return ApiException(
      kind: kind,
      code: code,
      message: message,
      statusCode: status,
    );
  }

  factory ApiException.parse() => ApiException(
    kind: ApiErrorKind.unknown,
    code: codeParse,
    message: 'The server response could not be read.',
  );

  @override
  String toString() => 'ApiException($kind, $code, status=$statusCode)';
}

enum ApiErrorKind {
  network,
  timeout,
  cancelled,
  unauthorized, // 401
  forbidden, // 403
  notFound, // 404
  conflict, // 409
  validation, // 400 / 422
  rateLimited, // 429
  server, // 5xx
  unknown,
}
