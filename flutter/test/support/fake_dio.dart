import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:nova_marketplace/core/api/token_refresher.dart';
import 'package:nova_marketplace/core/auth/token_store.dart';

/// A scripted [HttpClientAdapter] — each entry in [responder] gets the
/// request and returns the mock response for it.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.responder);

  final ResponseBody Function(RequestOptions options, int callIndex) responder;
  int calls = 0;
  final List<RequestOptions> received = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    received.add(options);
    return responder(options, calls++);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonBody(int status, Map<String, dynamic> body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

ResponseBody ok(Map<String, dynamic> data) => jsonBody(200, {'data': data});

ResponseBody okRaw(Object? data) => jsonBody(200, {'data': data});

ResponseBody okList(
  List<Object?> items, {
  int? limit,
  int? offset,
  int? total,
}) => jsonBody(200, {
  'data': items,
  'meta': {
    'limit': limit ?? items.length,
    'offset': offset ?? 0,
    'total': total ?? items.length,
  },
});

ResponseBody notFoundBody(String code) => jsonBody(404, {
  'error': {'code': code, 'message': 'not found'},
});

ResponseBody unauthorizedBody() => jsonBody(401, {
  'error': {'code': 'UNAUTHORIZED', 'message': 'nope'},
});

/// Counts refresh() calls; returns [token] (or null to simulate a dead
/// session). When [store] is given it also writes the new access token
/// there — mirroring the real `RefTokenRefresher`, which persists via
/// `AuthRepositoryImpl` so the request interceptor re-reads it.
class CountingRefresher implements TokenRefresher {
  CountingRefresher({this.token = 'refreshed-access', this.store});

  String? token;
  final TokenStore? store;
  int refreshCalls = 0;
  int sessionExpiredCalls = 0;
  Duration delay = const Duration(milliseconds: 5);

  @override
  Future<String?> refresh() async {
    refreshCalls++;
    await Future<void>.delayed(delay);
    if (token != null) {
      store?.setAccessToken(
        token!,
        DateTime.now().add(const Duration(minutes: 15)),
      );
    }
    return token;
  }

  @override
  void onSessionExpired() => sessionExpiredCalls++;
}
