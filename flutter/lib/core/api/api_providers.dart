import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/token_store.dart';
import 'api_client.dart';
import 'token_refresher.dart';

/// The 401-interceptor's refresh hook. Backed by `AuthRepository.refresh()`
/// + `AuthController.forceLoggedOut()`, resolved lazily (see
/// [RefTokenRefresher]) so there is no provider cycle with
/// [apiClientProvider], which builds it.
final tokenRefresherProvider = Provider<TokenRefresher>((ref) {
  return RefTokenRefresher(ref);
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    tokenStore: ref.watch(tokenStoreProvider),
    tokenRefresher: ref.watch(tokenRefresherProvider),
  );
});
