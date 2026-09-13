import '../../../shared/models/localized_text.dart';
import '../../catalog/data/catalog_models.dart';

/// One seller's public, purchasable listing of a product
/// (`GET /products/:id/offers` item, and `ProductDetail.best_offer`).
/// The backend already excludes inactive / out-of-stock offers.
class SellerOfferModel {
  const SellerOfferModel({
    required this.offerId,
    required this.sellerId,
    required this.sellerName,
    required this.sellerSlug,
    required this.sellerRating,
    required this.sellerVerified,
    required this.price,
    required this.discountPercent,
    required this.deliveryDays,
    required this.availableQuantity,
    this.oldPrice,
    this.sku = '',
  });

  final int offerId;
  final int sellerId;
  final String sellerName;
  final String sellerSlug;
  final double sellerRating;
  final bool sellerVerified;
  final String price;
  final String? oldPrice;
  final int discountPercent;
  final int deliveryDays;
  final int availableQuantity;
  final String sku;

  bool get hasDiscount => discountPercent > 0 && oldPrice != null;

  factory SellerOfferModel.fromJson(Map<String, dynamic> j) => SellerOfferModel(
    offerId: (j['offer_id'] as num).toInt(),
    sellerId: (j['seller_id'] as num).toInt(),
    sellerName: j['seller_name'] as String? ?? '',
    sellerSlug: j['seller_slug'] as String? ?? '',
    sellerRating: (j['seller_rating'] as num?)?.toDouble() ?? 0,
    sellerVerified: j['seller_verified'] as bool? ?? false,
    price: j['price'] as String? ?? '0',
    oldPrice: j['old_price'] as String?,
    discountPercent: (j['discount_percent'] as num?)?.toInt() ?? 0,
    deliveryDays: (j['delivery_days'] as num?)?.toInt() ?? 0,
    availableQuantity: (j['available_quantity'] as num?)?.toInt() ?? 0,
    sku: j['sku'] as String? ?? '',
  );
}

/// `GET /products/:id`. Embeds only the single best offer; the full offer
/// list is a separate endpoint.
class ProductDetailModel {
  const ProductDetailModel({
    required this.id,
    required this.slug,
    required this.brand,
    required this.name,
    required this.description,
    required this.category,
    required this.rating,
    required this.reviewCount,
    required this.images,
    required this.sellerCount,
    this.bestOffer,
  });

  final int id;
  final String slug;
  final String brand;
  final LocalizedText name;
  final LocalizedText description;
  final CategoryRefModel category;
  final double rating;
  final int reviewCount;
  final List<String> images;
  final SellerOfferModel? bestOffer;
  final int sellerCount;

  bool get hasOffers => bestOffer != null;
  bool get multiSeller => sellerCount > 1;

  factory ProductDetailModel.fromJson(Map<String, dynamic> j) =>
      ProductDetailModel(
        id: (j['id'] as num).toInt(),
        slug: j['slug'] as String? ?? '',
        brand: j['brand'] as String? ?? '',
        name: LocalizedText.fromJson(j['name']),
        description: LocalizedText.fromJson(j['description']),
        category: CategoryRefModel.fromJson(j['category']),
        rating: (j['rating'] as num?)?.toDouble() ?? 0,
        reviewCount: (j['review_count'] as num?)?.toInt() ?? 0,
        images: ((j['images'] as List?) ?? const [])
            .whereType<String>()
            .toList(),
        bestOffer: j['best_offer'] is Map
            ? SellerOfferModel.fromJson(
                Map<String, dynamic>.from(j['best_offer'] as Map),
              )
            : null,
        sellerCount: (j['seller_count'] as num?)?.toInt() ?? 0,
      );
}
