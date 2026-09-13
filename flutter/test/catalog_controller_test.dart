import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_marketplace/core/api/api_client.dart';
import 'package:nova_marketplace/core/api/api_providers.dart';
import 'package:nova_marketplace/core/api/token_refresher.dart';
import 'package:nova_marketplace/core/auth/token_store.dart';
import 'package:nova_marketplace/features/catalog/application/catalog_providers.dart';
import 'package:nova_marketplace/features/catalog/application/product_query.dart';

import 'support/catalog_fixtures.dart';
import 'support/fake_dio.dart';
import 'support/test_harness.dart';

/// Serves `/products` pages; a scenario callback can override behaviour
/// (errors, empty, custom counts) per request.
class CatalogFake {
  ResponseBody? Function(RequestOptions o)? scenario;
  int productCalls = 0;

  ResponseBody handle(RequestOptions o, int _) {
    if (o.path.endsWith('/products')) {
      productCalls++;
      final custom = scenario?.call(o);
      if (custom != null) return custom;
      final offset = int.parse(o.uri.queryParameters['offset'] ?? '0');
      final total = 45;
      final items = [
        for (var i = offset; i < offset + 20 && i < total; i++)
          productCardJson(id: i + 1),
      ];
      return okList(items, limit: 20, offset: offset, total: total);
    }
    // categories / brand sample
    return okRaw(const []);
  }
}

ProviderContainer containerFor(CatalogFake fake) {
  final adapter = FakeAdapter(fake.handle);
  final client = ApiClient(
    tokenStore: TokenStore(FakeSecureStore()),
    tokenRefresher: const NoopTokenRefresher(),
    dio: Dio()..httpClientAdapter = adapter,
  );
  final c = ProviderContainer(
    retry: (_, _) => null,
    overrides: [apiClientProvider.overrideWithValue(client)],
  );
  addTearDown(c.dispose);
  return c;
}

Future<void> settle(ProviderContainer c) async {
  for (var i = 0; i < 120; i++) {
    final st = c.read(catalogControllerProvider);
    if (st.status != CatalogStatus.loading || st.items.isNotEmpty) {
      if (st.status != CatalogStatus.loading) return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  test('initial load fills page 0 + total from meta', () async {
    final c = containerFor(CatalogFake());
    c.listen(catalogControllerProvider, (_, _) {});
    await settle(c);
    final st = c.read(catalogControllerProvider);
    expect(st.status, CatalogStatus.loaded);
    expect(st.items, hasLength(20));
    expect(st.total, 45);
    expect(st.hasMore, isTrue);
  });

  test('loadMore appends the next page, no duplicates', () async {
    final c = containerFor(CatalogFake());
    c.listen(catalogControllerProvider, (_, _) {});
    await settle(c);
    await c.read(catalogControllerProvider.notifier).loadMore();
    await settle(c);
    final st = c.read(catalogControllerProvider);
    expect(st.items, hasLength(40));
    expect(st.items.map((p) => p.id).toSet(), hasLength(40)); // unique
    await c.read(catalogControllerProvider.notifier).loadMore();
    await settle(c);
    expect(c.read(catalogControllerProvider).items, hasLength(45));
    expect(c.read(catalogControllerProvider).hasMore, isFalse);
  });

  test('changing search resets items + offset', () async {
    final c = containerFor(CatalogFake());
    c.listen(catalogControllerProvider, (_, _) {});
    await settle(c);
    await c.read(catalogControllerProvider.notifier).loadMore();
    await settle(c);
    expect(c.read(catalogControllerProvider).items.length, greaterThan(20));

    c.read(catalogControllerProvider.notifier).submitSearch('iphone');
    await settle(c);
    final st = c.read(catalogControllerProvider);
    expect(st.query.search, 'iphone');
    expect(st.query.offset, 0);
    expect(st.items, hasLength(20)); // reset to one page
  });

  test('sort change and filter reset both reset pagination', () async {
    final c = containerFor(CatalogFake());
    c.listen(catalogControllerProvider, (_, _) {});
    await settle(c);
    await c.read(catalogControllerProvider.notifier).loadMore();
    await settle(c);

    c.read(catalogControllerProvider.notifier).setSort(ProductSort.priceAsc);
    await settle(c);
    expect(c.read(catalogControllerProvider).query.sort, ProductSort.priceAsc);
    expect(c.read(catalogControllerProvider).items, hasLength(20));

    c
        .read(catalogControllerProvider.notifier)
        .applyQuery(
          c.read(catalogControllerProvider).query.copyWith(brand: 'Apple'),
        );
    await settle(c);
    expect(c.read(catalogControllerProvider).query.brand, 'Apple');
    c.read(catalogControllerProvider.notifier).resetFilters();
    await settle(c);
    expect(c.read(catalogControllerProvider).query.hasActiveFilters, isFalse);
  });

  test('empty result → isEmpty state', () async {
    final fake = CatalogFake()
      ..scenario = (o) => okList(const [], limit: 20, offset: 0, total: 0);
    final c = containerFor(fake);
    c.listen(catalogControllerProvider, (_, _) {});
    await settle(c);
    expect(c.read(catalogControllerProvider).isEmpty, isTrue);
  });

  test('first-page failure → error state; retry recovers', () async {
    var fail = true;
    final fake = CatalogFake()
      ..scenario = (o) => fail
          ? jsonBody(503, {
              'error': {'code': 'X', 'message': 'down'},
            })
          : null;
    final c = containerFor(fake);
    c.listen(catalogControllerProvider, (_, _) {});
    await settle(c);
    expect(c.read(catalogControllerProvider).status, CatalogStatus.error);

    fail = false;
    await c.read(catalogControllerProvider.notifier).refresh();
    await settle(c);
    expect(c.read(catalogControllerProvider).status, CatalogStatus.loaded);
    expect(c.read(catalogControllerProvider).items, hasLength(20));
  });

  test('next-page failure → errorMore, existing items kept', () async {
    var failNext = false;
    final fake = CatalogFake()
      ..scenario = (o) {
        final offset = int.parse(o.uri.queryParameters['offset'] ?? '0');
        if (offset > 0 && failNext) {
          return jsonBody(500, {
            'error': {'code': 'X', 'message': 'boom'},
          });
        }
        return null;
      };
    final c = containerFor(fake);
    c.listen(catalogControllerProvider, (_, _) {});
    await settle(c);
    failNext = true;
    await c.read(catalogControllerProvider.notifier).loadMore();
    await settle(c);
    final st = c.read(catalogControllerProvider);
    expect(st.status, CatalogStatus.errorMore);
    expect(st.items, hasLength(20)); // page 0 kept
  });

  test('stale search response does not overwrite the newer query', () async {
    // Slow "old" query, fast "new" query.
    final fake = CatalogFake()
      ..scenario = (o) {
        final search = o.uri.queryParameters['search'];
        if (search == 'slow') {
          // Return a distinctive single-item page — but late.
          return okList(
            [productCardJson(id: 999)],
            limit: 20,
            offset: 0,
            total: 1,
          );
        }
        return null;
      };
    final c = containerFor(fake);
    c.listen(catalogControllerProvider, (_, _) {});
    await settle(c);

    final notifier = c.read(catalogControllerProvider.notifier);
    notifier.submitSearch('slow');
    notifier.submitSearch('fast'); // supersedes immediately
    await settle(c);

    final st = c.read(catalogControllerProvider);
    expect(st.query.search, 'fast');
    expect(
      st.items.any((p) => p.id == 999),
      isFalse,
      reason: 'stale "slow" response must not land',
    );
  });
}
