import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_marketplace/core/api/api_client.dart';
import 'package:nova_marketplace/core/api/token_refresher.dart';
import 'package:nova_marketplace/core/auth/token_store.dart';
import 'package:nova_marketplace/core/errors/api_exception.dart';
import 'package:nova_marketplace/features/catalog/application/product_query.dart';
import 'package:nova_marketplace/features/catalog/data/catalog_repository.dart';
import 'package:nova_marketplace/features/product/data/product_repository.dart';
import 'package:nova_marketplace/features/reviews/data/review_repository.dart';
import 'package:nova_marketplace/features/seller/data/seller_public_repository.dart';

import 'support/catalog_fixtures.dart';
import 'support/fake_dio.dart';
import 'support/test_harness.dart';

ApiClient clientFor(FakeAdapter adapter) => ApiClient(
  tokenStore: TokenStore(FakeSecureStore()),
  tokenRefresher: const NoopTokenRefresher(),
  dio: Dio()..httpClientAdapter = adapter,
);

void main() {
  test('categories parse (localized name + parent/child)', () async {
    final adapter = FakeAdapter(
      (o, i) => okRaw([
        categoryJson(id: 1, slug: 'electronics', childCount: 2),
        categoryJson(id: 2, slug: 'smartphones', parentId: 1, childCount: 0),
      ]),
    );
    final cats = await CatalogRepository(clientFor(adapter)).getCategories();
    expect(cats, hasLength(2));
    expect(cats.first.isRoot, isTrue);
    expect(cats[1].parentId, 1);
    expect(cats.first.name.en, 'Electronics');
  });

  test('products list parses items + meta and forwards query params', () async {
    final adapter = FakeAdapter(
      (o, i) => okList(
        [productCardJson(id: 1), productCardJson(id: 2)],
        limit: 20,
        offset: 0,
        total: 40,
      ),
    );
    final repo = CatalogRepository(clientFor(adapter));
    final page = await repo.getProducts(
      const ProductQuery(
        search: 'iphone',
        categorySlug: 'electronics',
        minRating: 4,
        sort: ProductSort.priceAsc,
      ),
    );
    expect(page.items, hasLength(2));
    expect(page.meta.total, 40);
    expect(page.hasMore, isTrue);
    expect(page.items.first.price, '620000.00');

    final q = adapter.received.single.uri.queryParameters;
    expect(q['search'], 'iphone');
    expect(q['category'], 'electronics');
    expect(q['rating'], '4');
    expect(q['sort'], 'price_asc');
    expect(q['limit'], '20');
  });

  test('product detail: embeds best_offer + images + seller_count', () async {
    final adapter = FakeAdapter(
      (o, i) => ok(productDetailJson(sellerCount: 4)),
    );
    final p = await ProductRepository(clientFor(adapter)).getProduct(1);
    expect(p.images, hasLength(2));
    expect(p.bestOffer!.sellerName, 'TechStore');
    expect(p.multiSeller, isTrue);
    expect(p.name.ru, 'iPhone 17 Pro');
  });

  test(
    'product detail 404 → ApiException(notFound / PRODUCT_NOT_FOUND)',
    () async {
      final adapter = FakeAdapter((o, i) => notFoundBody('PRODUCT_NOT_FOUND'));
      await expectLater(
        ProductRepository(clientFor(adapter)).getProduct(999),
        throwsA(
          isA<ApiException>()
              .having((e) => e.kind, 'kind', ApiErrorKind.notFound)
              .having((e) => e.code, 'code', 'PRODUCT_NOT_FOUND'),
        ),
      );
    },
  );

  test('offers: all seller offers, order preserved', () async {
    final adapter = FakeAdapter(
      (o, i) => okRaw([
        offerJson(offerId: 1, seller: 'TechStore', price: '600000.00'),
        offerJson(
          offerId: 2,
          seller: 'GadgetPro',
          price: '610000.00',
          verified: false,
        ),
        offerJson(offerId: 3, seller: 'HomeComfort', price: '620000.00'),
      ]),
    );
    final offers = await ProductRepository(clientFor(adapter)).getOffers(1);
    expect(offers.map((o) => o.sellerName), [
      'TechStore',
      'GadgetPro',
      'HomeComfort',
    ]);
    expect(offers[1].sellerVerified, isFalse);
  });

  test('seller detail + seller products (seller-specific price)', () async {
    final adapter = FakeAdapter((o, i) {
      if (o.path.endsWith('/products')) {
        return okList([sellerProductJson(price: '615000.00')], total: 10);
      }
      return ok(sellerDetailJson());
    });
    final repo = SellerPublicRepository(clientFor(adapter));
    final seller = await repo.getSeller(1);
    expect(seller.productCount, 10);
    final products = await repo.getSellerProducts(1);
    expect(products.items.single.price, '615000.00');
    expect(products.meta.total, 10);
  });

  test('reviews parse (safe display name, rating, date)', () async {
    final adapter = FakeAdapter(
      (o, i) => okList([
        reviewJson(id: 1, rating: 5),
        reviewJson(id: 2, rating: 3),
      ], total: 2),
    );
    final page = await ReviewRepository(
      clientFor(adapter),
    ).getProductReviews(1);
    expect(page.items, hasLength(2));
    expect(page.items.first.userDisplayName, 'Айгерим К.');
    expect(page.items.first.rating, 5);
    expect(page.items.first.createdAt.year, 2026);
  });

  test(
    'sampleBrands extracts unique sorted brands from a bounded sample',
    () async {
      final adapter = FakeAdapter(
        (o, i) => okList([
          productCardJson(id: 1, brand: 'Samsung'),
          productCardJson(id: 2, brand: 'Apple'),
          productCardJson(id: 3, brand: 'Apple'),
          productCardJson(id: 4, brand: 'Xiaomi'),
        ]),
      );
      final brands = await CatalogRepository(
        clientFor(adapter),
      ).sampleBrands(const ProductQuery());
      expect(brands, ['Apple', 'Samsung', 'Xiaomi']);
      expect(adapter.received.single.uri.queryParameters['limit'], '100');
    },
  );
}
