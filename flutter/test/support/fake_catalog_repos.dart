import 'package:nova_marketplace/core/api/api_client.dart';
import 'package:nova_marketplace/core/errors/api_exception.dart';
import 'package:nova_marketplace/features/catalog/application/product_query.dart';
import 'package:nova_marketplace/features/catalog/data/catalog_models.dart';
import 'package:nova_marketplace/features/catalog/data/catalog_repository.dart';
import 'package:nova_marketplace/features/product/data/product_models.dart';
import 'package:nova_marketplace/features/product/data/product_repository.dart';
import 'package:nova_marketplace/features/reviews/data/review_models.dart';
import 'package:nova_marketplace/features/reviews/data/review_repository.dart';
import 'package:nova_marketplace/features/seller/data/seller_public_models.dart';
import 'package:nova_marketplace/features/seller/data/seller_public_repository.dart';
import 'package:nova_marketplace/shared/models/localized_text.dart';
import 'package:nova_marketplace/shared/models/paginated.dart';
import 'package:dio/dio.dart';

import 'catalog_fixtures.dart';

LocalizedText _lt(String v) => LocalizedText(ru: v, kk: '$v kk', en: '$v en');

ProductCardModel cardModel({
  int id = 1,
  String name = 'iPhone 17 Pro Max Ultra',
}) => ProductCardModel(
  id: id,
  slug: 'p-$id',
  brand: 'Apple',
  name: _lt(name),
  category: const CategoryRefModel(id: 1, slug: 'e', name: LocalizedText.empty),
  rating: 4.4,
  reviewCount: 812,
  primaryImage: null,
  price: '620000.00',
  oldPrice: '699000.00',
  discountPercent: 11,
  bestOfferId: 100,
  sellerName: 'TechStore',
  sellerRating: 4.9,
  sellerCount: 3,
  minDeliveryDays: 1,
);

class FakeCatalogRepository implements CatalogRepository {
  FakeCatalogRepository({this.categories = const [], this.products});

  final List<CategoryModel> categories;
  Paginated<ProductCardModel>? products;

  @override
  Future<List<CategoryModel>> getCategories() async => categories;

  @override
  Future<Paginated<ProductCardModel>> getProducts(
    ProductQuery query, {
    CancelToken? cancelToken,
  }) async =>
      products ??
      Paginated(
        items: [cardModel(id: 1), cardModel(id: 2)],
        meta: const ApiListMeta(limit: 20, offset: 0, total: 2),
      );

  @override
  Future<List<String>> sampleBrands(ProductQuery base) async => [
    'Apple',
    'Samsung',
  ];
}

class FakeProductRepository implements ProductRepository {
  FakeProductRepository({
    this.detail,
    this.offers = const [],
    this.throwNotFound = false,
  });

  ProductDetailModel? detail;
  List<SellerOfferModel> offers;
  bool throwNotFound;

  @override
  Future<ProductDetailModel> getProduct(int id) async {
    if (throwNotFound) {
      throw ApiException(
        kind: ApiErrorKind.notFound,
        code: 'PRODUCT_NOT_FOUND',
        message: 'x',
        statusCode: 404,
      );
    }
    return detail ?? ProductDetailModel.fromJson(productDetailJson(id: id));
  }

  @override
  Future<List<SellerOfferModel>> getOffers(int id) async => offers;
}

class FakeSellerRepository implements SellerPublicRepository {
  FakeSellerRepository({this.detail, this.products});

  SellerDetailModel? detail;
  Paginated<SellerProductModel>? products;

  @override
  Future<SellerDetailModel> getSeller(int id) async =>
      detail ?? SellerDetailModel.fromJson(sellerDetailJson(id: id));

  @override
  Future<Paginated<SellerProductModel>> getSellerProducts(
    int id, {
    int offset = 0,
    int limit = 20,
  }) async => products ?? const Paginated.empty();
}

class FakeReviewRepository implements ReviewRepository {
  FakeReviewRepository({this.page});
  Paginated<ReviewModel>? page;

  @override
  Future<Paginated<ReviewModel>> getProductReviews(
    int productId, {
    int offset = 0,
    int limit = 10,
  }) async => page ?? const Paginated.empty();
}
