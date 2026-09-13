import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_marketplace/core/api/api_client.dart';
import 'package:nova_marketplace/core/errors/api_exception.dart';
import 'package:nova_marketplace/core/utils/money.dart';

void main() {
  group('ApiException.fromDio', () {
    RequestOptions ro() => RequestOptions(path: '/x');

    test('maps 401 → unauthorized and reads the backend error envelope', () {
      final e = ApiException.fromDio(
        DioException(
          requestOptions: ro(),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: ro(),
            statusCode: 401,
            data: {
              'error': {'code': 'INVALID_CREDENTIALS', 'message': 'nope'},
            },
          ),
        ),
      );
      expect(e.kind, ApiErrorKind.unauthorized);
      expect(e.code, 'INVALID_CREDENTIALS');
      expect(e.statusCode, 401);
    });

    test('maps 403 → forbidden, 409 → conflict, 429 → rateLimited', () {
      ApiException at(int status) => ApiException.fromDio(
        DioException(
          requestOptions: ro(),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: ro(),
            statusCode: status,
            data: const {},
          ),
        ),
      );
      expect(at(403).kind, ApiErrorKind.forbidden);
      expect(at(409).kind, ApiErrorKind.conflict);
      expect(at(429).kind, ApiErrorKind.rateLimited);
      expect(at(500).kind, ApiErrorKind.server);
    });

    test('maps timeout and connection errors to transport kinds', () {
      expect(
        ApiException.fromDio(
          DioException(
            requestOptions: ro(),
            type: DioExceptionType.connectionTimeout,
          ),
        ).kind,
        ApiErrorKind.timeout,
      );
      expect(
        ApiException.fromDio(
          DioException(
            requestOptions: ro(),
            type: DioExceptionType.connectionError,
          ),
        ).kind,
        ApiErrorKind.network,
      );
    });
  });

  group('ApiListMeta', () {
    test('parses limit/offset/total and computes hasMore', () {
      final m = ApiListMeta.fromJson({'limit': 20, 'offset': 0, 'total': 45});
      expect(m.hasMore, isTrue);
      final last = ApiListMeta.fromJson({
        'limit': 20,
        'offset': 40,
        'total': 45,
      });
      expect(last.hasMore, isFalse);
    });

    test('defaults to an empty page for a null meta', () {
      final m = ApiListMeta.fromJson(null);
      expect(m.total, 0);
      expect(m.hasMore, isFalse);
    });
  });

  group('Money.format', () {
    test('groups thousands with a thin space and appends the tenge symbol', () {
      expect(Money.format('620000.00'), '620\u00A0000\u00A0₸');
      expect(Money.format('1150000.00'), '1\u00A0150\u00A0000\u00A0₸');
      expect(Money.format('98000.00', withSymbol: false), '98\u00A0000');
      expect(Money.format(null), '0\u00A0₸');
      expect(Money.format('500.00'), '500\u00A0₸');
    });
  });
}
