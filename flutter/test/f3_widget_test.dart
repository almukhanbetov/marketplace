import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_marketplace/core/api/api_client.dart';
import 'package:nova_marketplace/core/storage/preferences_store.dart';
import 'package:nova_marketplace/core/storage/secure_storage.dart';
import 'package:nova_marketplace/core/theme/app_colors.dart';
import 'package:nova_marketplace/core/theme/app_theme.dart';
import 'package:nova_marketplace/features/catalog/data/catalog_repository.dart';
import 'package:nova_marketplace/features/product/data/product_models.dart';
import 'package:nova_marketplace/features/product/data/product_repository.dart';
import 'package:nova_marketplace/features/product/presentation/product_screen.dart';
import 'package:nova_marketplace/features/product/presentation/widgets/offer_sheet.dart';
import 'package:nova_marketplace/features/reviews/data/review_repository.dart';
import 'package:nova_marketplace/features/seller/data/seller_public_models.dart';
import 'package:nova_marketplace/features/seller/data/seller_public_repository.dart';
import 'package:nova_marketplace/features/seller/presentation/seller_public_screen.dart';
import 'package:nova_marketplace/shared/models/paginated.dart';
import 'package:nova_marketplace/shared/widgets/product_card.dart';
import 'package:nova_marketplace/shared/widgets/product_grid.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/catalog_fixtures.dart';
import 'support/fake_catalog_repos.dart';
import 'support/test_harness.dart';

Future<void> _pumpFutures(WidgetTester t) async {
  for (var i = 0; i < 25; i++) {
    await t.pump(const Duration(milliseconds: 40));
  }
}

Future<SharedPreferences> _prefs([Map<String, Object> seed = const {}]) async {
  SharedPreferences.setMockInitialValues(seed);
  return SharedPreferences.getInstance();
}

Future<Widget> _host(
  Widget child, {
  required SharedPreferences sp,
  CatalogRepository? catalog,
  ProductRepository? product,
  SellerPublicRepository? seller,
  ReviewRepository? review,
  ThemeData? theme,
}) async {
  return ProviderScope(
    retry: (_, _) => null,
    overrides: [
      sharedPreferencesProvider.overrideWithValue(sp),
      secureStoreProvider.overrideWithValue(FakeSecureStore()),
      if (catalog != null) catalogRepositoryProvider.overrideWithValue(catalog),
      if (product != null) productRepositoryProvider.overrideWithValue(product),
      if (seller != null)
        sellerPublicRepositoryProvider.overrideWithValue(seller),
      if (review != null) reviewRepositoryProvider.overrideWithValue(review),
    ],
    child: MaterialApp(theme: theme ?? AppTheme.dark(), home: child),
  );
}

void main() {
  testWidgets('ProductCard renders without overflow at 360 / 390 / 430', (
    tester,
  ) async {
    final sp = await _prefs();
    for (final width in [360.0, 390.0, 430.0]) {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      // Cell width ≈ catalog 2-col grid cell.
      final cell = (width - 24 - 10) / 2;
      await tester.pumpWidget(
        await _host(
          Scaffold(
            body: SizedBox(
              width: cell,
              height: cell / 0.56,
              child: ProductCard(
                product: cardModel(
                  name:
                      'Смартфон Apple iPhone 17 Pro Max Ultra 1TB Космический титан',
                ),
              ),
            ),
          ),
          sp: sp,
        ),
      );
      await _pumpFutures(tester);
      expect(tester.takeException(), isNull, reason: 'overflow at ${width}px');
      expect(find.byType(ProductCard), findsOneWidget);
      expect(find.textContaining('620'), findsWidgets); // price rendered
    }
  });

  testWidgets('SliverProductGrid lays out cards, no overflow', (tester) async {
    final sp = await _prefs();
    await tester.pumpWidget(
      await _host(
        Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverProductGrid(
                products: [for (var i = 1; i <= 6; i++) cardModel(id: i)],
              ),
            ],
          ),
        ),
        sp: sp,
      ),
    );
    await _pumpFutures(tester);
    expect(tester.takeException(), isNull);
    expect(find.byType(ProductCard), findsWidgets);
  });

  testWidgets('light theme scaffold background is #FFFFFF on catalog widgets', (
    tester,
  ) async {
    final sp = await _prefs();
    await tester.pumpWidget(
      await _host(
        Scaffold(backgroundColor: AppTheme.light().extension<NovaColors>()!.bg),
        sp: sp,
        theme: AppTheme.light(),
      ),
    );
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, const Color(0xFFFFFFFF));
  });

  testWidgets('ProductScreen: not-found state', (tester) async {
    final sp = await _prefs();
    await tester.pumpWidget(
      await _host(
        const ProductScreen(productId: '999'),
        sp: sp,
        product: FakeProductRepository(throwNotFound: true),
        review: FakeReviewRepository(),
      ),
    );
    await _pumpFutures(tester);
    expect(find.text('Товар не найден'), findsOneWidget); // RU default
  });

  testWidgets('ProductScreen: data state shows name, price, multi-seller row', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final sp = await _prefs();
    final detail = ProductDetailModel.fromJson(
      productDetailJson(sellerCount: 3),
    );
    await tester.pumpWidget(
      await _host(
        const ProductScreen(productId: '1'),
        sp: sp,
        product: FakeProductRepository(
          detail: detail,
          offers: [
            SellerOfferModel.fromJson(
              offerJson(offerId: 1, seller: 'TechStore', price: '600000.00'),
            ),
            SellerOfferModel.fromJson(
              offerJson(offerId: 2, seller: 'GadgetPro', price: '610000.00'),
            ),
            SellerOfferModel.fromJson(
              offerJson(offerId: 3, seller: 'HomeComfort', price: '620000.00'),
            ),
          ],
        ),
        review: FakeReviewRepository(),
      ),
    );
    await _pumpFutures(tester);
    expect(tester.takeException(), isNull);
    expect(find.textContaining('iPhone'), findsWidgets);
    expect(
      find.textContaining('3'),
      findsWidgets,
    ); // "Предложения продавцов (3)"
    expect(
      find.textContaining('3'),
      findsWidgets,
    ); // "Предложения продавцов (3)"
  });

  testWidgets('offer sheet lists every seller offer + best-offer badge', (
    tester,
  ) async {
    final sp = await _prefs();
    final offers = [
      SellerOfferModel.fromJson(
        offerJson(offerId: 1, seller: 'TechStore', price: '600000.00'),
      ),
      SellerOfferModel.fromJson(
        offerJson(offerId: 2, seller: 'GadgetPro', price: '610000.00'),
      ),
      SellerOfferModel.fromJson(
        offerJson(offerId: 3, seller: 'HomeComfort', price: '650000.00'),
      ),
    ];
    late BuildContext ctx;
    await tester.pumpWidget(
      await _host(
        Builder(
          builder: (c) {
            ctx = c;
            return const Scaffold(body: SizedBox());
          },
        ),
        sp: sp,
      ),
    );
    // ignore: unawaited_futures
    showOfferSheet(ctx, offers: offers, selectedOfferId: 1);
    await tester.pumpAndSettle();
    expect(find.text('TechStore'), findsOneWidget);
    expect(find.text('GadgetPro'), findsOneWidget);
    expect(find.text('HomeComfort'), findsOneWidget);
    expect(find.text('Лучшее предложение'), findsOneWidget);
  });

  testWidgets('SellerPublicScreen renders header + seller-specific price', (
    tester,
  ) async {
    final sp = await _prefs();
    await tester.pumpWidget(
      await _host(
        const SellerPublicScreen(sellerId: 1),
        sp: sp,
        seller: FakeSellerRepository(
          detail: SellerDetailModel.fromJson(sellerDetailJson()),
          products: Paginated(
            items: [
              SellerProductModel.fromJson(
                sellerProductJson(price: '615000.00'),
              ),
            ],
            meta: const ApiListMeta(limit: 20, offset: 0, total: 1),
          ),
        ),
      ),
    );
    await _pumpFutures(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('TechStore'), findsWidgets);
    expect(find.textContaining('615'), findsWidgets);
  });
}
