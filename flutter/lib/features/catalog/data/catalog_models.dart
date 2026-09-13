import '../../../shared/models/localized_text.dart';

/// `GET /categories` item — root or child (`parentId` set), `childCount`
/// for "has subcategories" affordances.
class CategoryModel {
  const CategoryModel({
    required this.id,
    required this.slug,
    required this.name,
    this.parentId,
    this.imageUrl,
    this.childCount = 0,
  });

  final int id;
  final String slug;
  final LocalizedText name;
  final int? parentId;
  final String? imageUrl;
  final int childCount;

  bool get isRoot => parentId == null;

  factory CategoryModel.fromJson(Map<String, dynamic> j) => CategoryModel(
    id: (j['id'] as num).toInt(),
    slug: j['slug'] as String? ?? '',
    name: LocalizedText.fromJson(j['name']),
    parentId: (j['parent_id'] as num?)?.toInt(),
    imageUrl: j['image_url'] as String?,
    childCount: (j['child_count'] as num?)?.toInt() ?? 0,
  );
}

/// Compact category reference embedded in a product.
class CategoryRefModel {
  const CategoryRefModel({
    required this.id,
    required this.slug,
    required this.name,
  });

  final int id;
  final String slug;
  final LocalizedText name;

  factory CategoryRefModel.fromJson(Object? json) {
    if (json is! Map) {
      return const CategoryRefModel(id: 0, slug: '', name: LocalizedText.empty);
    }
    return CategoryRefModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      slug: json['slug'] as String? ?? '',
      name: LocalizedText.fromJson(json['name']),
    );
  }
}

/// `GET /products` list item. Priced from the marketplace's best available
/// offer (see the backend's ProductService doc comment). All money values
/// are exact decimal strings — kept verbatim, formatted only for display.
class ProductCardModel {
  const ProductCardModel({
    required this.id,
    required this.slug,
    required this.brand,
    required this.name,
    required this.category,
    required this.rating,
    required this.reviewCount,
    required this.price,
    required this.discountPercent,
    required this.bestOfferId,
    required this.sellerName,
    required this.sellerRating,
    required this.sellerCount,
    required this.minDeliveryDays,
    this.primaryImage,
    this.oldPrice,
  });

  final int id;
  final String slug;
  final String brand;
  final LocalizedText name;
  final CategoryRefModel category;
  final double rating;
  final int reviewCount;
  final String? primaryImage;
  final String price; // "620000.00"
  final String? oldPrice; // "699000.00" | null
  final int discountPercent;
  final int bestOfferId;
  final String sellerName;
  final double sellerRating;
  final int sellerCount;
  final int minDeliveryDays;

  bool get hasDiscount => discountPercent > 0 && oldPrice != null;
  bool get multiSeller => sellerCount > 1;

  factory ProductCardModel.fromJson(Map<String, dynamic> j) => ProductCardModel(
    id: (j['id'] as num).toInt(),
    slug: j['slug'] as String? ?? '',
    brand: j['brand'] as String? ?? '',
    name: LocalizedText.fromJson(j['name']),
    category: CategoryRefModel.fromJson(j['category']),
    rating: (j['rating'] as num?)?.toDouble() ?? 0,
    reviewCount: (j['review_count'] as num?)?.toInt() ?? 0,
    primaryImage: j['primary_image'] as String?,
    price: j['price'] as String? ?? '0',
    oldPrice: j['old_price'] as String?,
    discountPercent: (j['discount_percent'] as num?)?.toInt() ?? 0,
    bestOfferId: (j['best_offer_id'] as num?)?.toInt() ?? 0,
    sellerName: j['seller_name'] as String? ?? '',
    sellerRating: (j['seller_rating'] as num?)?.toDouble() ?? 0,
    sellerCount: (j['seller_count'] as num?)?.toInt() ?? 0,
    minDeliveryDays: (j['min_delivery_days'] as num?)?.toInt() ?? 0,
  );
}
