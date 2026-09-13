import '../../../shared/models/localized_text.dart';

/// `GET /sellers` item — never any user PII or financials.
class SellerSummaryModel {
  const SellerSummaryModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.description,
    required this.rating,
    required this.reviewCount,
    required this.isVerified,
    required this.activeOfferCount,
  });

  final int id;
  final String name;
  final String slug;
  final String description;
  final double rating;
  final int reviewCount;
  final bool isVerified;
  final int activeOfferCount;

  factory SellerSummaryModel.fromJson(Map<String, dynamic> j) =>
      SellerSummaryModel(
        id: (j['id'] as num).toInt(),
        name: j['name'] as String? ?? '',
        slug: j['slug'] as String? ?? '',
        description: j['description'] as String? ?? '',
        rating: (j['rating'] as num?)?.toDouble() ?? 0,
        reviewCount: (j['review_count'] as num?)?.toInt() ?? 0,
        isVerified: j['is_verified'] as bool? ?? false,
        activeOfferCount: (j['active_offer_count'] as num?)?.toInt() ?? 0,
      );
}

/// `GET /sellers/:id` — the public seller profile.
class SellerDetailModel {
  const SellerDetailModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.description,
    required this.rating,
    required this.reviewCount,
    required this.isVerified,
    required this.isActive,
    required this.productCount,
    required this.activeOfferCount,
  });

  final int id;
  final String name;
  final String slug;
  final String description;
  final double rating;
  final int reviewCount;
  final bool isVerified;
  final bool isActive;
  final int productCount;
  final int activeOfferCount;

  factory SellerDetailModel.fromJson(Map<String, dynamic> j) =>
      SellerDetailModel(
        id: (j['id'] as num).toInt(),
        name: j['name'] as String? ?? '',
        slug: j['slug'] as String? ?? '',
        description: j['description'] as String? ?? '',
        rating: (j['rating'] as num?)?.toDouble() ?? 0,
        reviewCount: (j['review_count'] as num?)?.toInt() ?? 0,
        isVerified: j['is_verified'] as bool? ?? false,
        isActive: j['is_active'] as bool? ?? true,
        productCount: (j['product_count'] as num?)?.toInt() ?? 0,
        activeOfferCount: (j['active_offer_count'] as num?)?.toInt() ?? 0,
      );
}

/// `GET /sellers/:id/products` item — price is always THIS seller's own
/// offer, never the marketplace-wide cheapest.
class SellerProductModel {
  const SellerProductModel({
    required this.productId,
    required this.slug,
    required this.name,
    required this.brand,
    required this.rating,
    required this.reviewCount,
    required this.offerId,
    required this.price,
    required this.discountPercent,
    required this.deliveryDays,
    required this.availableQuantity,
    this.primaryImage,
    this.oldPrice,
  });

  final int productId;
  final String slug;
  final LocalizedText name;
  final String brand;
  final double rating;
  final int reviewCount;
  final String? primaryImage;
  final int offerId;
  final String price;
  final String? oldPrice;
  final int discountPercent;
  final int deliveryDays;
  final int availableQuantity;

  bool get hasDiscount => discountPercent > 0 && oldPrice != null;

  factory SellerProductModel.fromJson(Map<String, dynamic> j) =>
      SellerProductModel(
        productId: (j['product_id'] as num).toInt(),
        slug: j['slug'] as String? ?? '',
        name: LocalizedText.fromJson(j['name']),
        brand: j['brand'] as String? ?? '',
        rating: (j['rating'] as num?)?.toDouble() ?? 0,
        reviewCount: (j['review_count'] as num?)?.toInt() ?? 0,
        primaryImage: j['primary_image'] as String?,
        offerId: (j['offer_id'] as num?)?.toInt() ?? 0,
        price: j['price'] as String? ?? '0',
        oldPrice: j['old_price'] as String?,
        discountPercent: (j['discount_percent'] as num?)?.toInt() ?? 0,
        deliveryDays: (j['delivery_days'] as num?)?.toInt() ?? 0,
        availableQuantity: (j['available_quantity'] as num?)?.toInt() ?? 0,
      );
}
