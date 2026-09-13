/// JSON fixtures mirroring the real backend catalog responses (shapes
/// verified against the running API).
library;

Map<String, dynamic> categoryJson({
  int id = 1,
  String slug = 'electronics',
  int? parentId,
  int childCount = 2,
}) => {
  'id': id,
  'parent_id': parentId,
  'slug': slug,
  'name': {'ru': 'Электроника', 'kk': 'Электроника', 'en': 'Electronics'},
  'image_url': null,
  'sort_order': 1,
  'is_active': true,
  'child_count': childCount,
};

Map<String, dynamic> productCardJson({
  int id = 1,
  String price = '620000.00',
  String? oldPrice = '699000.00',
  int discount = 11,
  int sellerCount = 3,
  String nameRu = 'iPhone 17 Pro',
  String brand = 'Apple',
}) => {
  'id': id,
  'slug': 'p-$id',
  'brand': brand,
  'name': {'ru': nameRu, 'kk': '$nameRu kk', 'en': '$nameRu en'},
  'category': {
    'id': 1,
    'slug': 'electronics',
    'name': {'ru': 'Электроника', 'kk': 'Электроника', 'en': 'Electronics'},
  },
  'rating': 4.3,
  'review_count': 928,
  'primary_image': 'https://example.com/p$id.jpg',
  'price': price,
  'old_price': oldPrice,
  'discount_percent': discount,
  'best_offer_id': 100 + id,
  'seller_name': 'TechStore',
  'seller_rating': 4.9,
  'seller_count': sellerCount,
  'min_delivery_days': 1,
};

Map<String, dynamic> offerJson({
  int offerId = 675,
  int sellerId = 1,
  String seller = 'TechStore',
  String price = '620000.00',
  bool verified = true,
  int delivery = 2,
  int qty = 17,
}) => {
  'offer_id': offerId,
  'seller_id': sellerId,
  'seller_name': seller,
  'seller_slug': seller.toLowerCase(),
  'seller_rating': 4.9,
  'seller_verified': verified,
  'sku': 'SKU-$offerId',
  'price': price,
  'old_price': null,
  'discount_percent': 0,
  'delivery_days': delivery,
  'available_quantity': qty,
};

Map<String, dynamic> productDetailJson({
  int id = 1,
  int sellerCount = 3,
  List<String> images = const [
    'https://example.com/1.jpg',
    'https://example.com/2.jpg',
  ],
}) => {
  'id': id,
  'slug': 'p-$id',
  'brand': 'Apple',
  'name': {
    'ru': 'iPhone 17 Pro',
    'kk': 'iPhone 17 Pro kk',
    'en': 'iPhone 17 Pro en',
  },
  'description': {'ru': 'Описание', 'kk': 'Сипаттама', 'en': 'Description'},
  'category': {
    'id': 1,
    'slug': 'electronics',
    'name': {'ru': 'Электроника', 'kk': 'Электроника', 'en': 'Electronics'},
  },
  'rating': 4.3,
  'review_count': 928,
  'images': images,
  'best_offer': offerJson(),
  'seller_count': sellerCount,
};

Map<String, dynamic> sellerDetailJson({int id = 1, bool active = true}) => {
  'id': id,
  'name': 'TechStore',
  'slug': 'techstore',
  'description': 'Официальный продавец электроники',
  'rating': 4.9,
  'review_count': 1243,
  'is_verified': true,
  'is_active': active,
  'product_count': 10,
  'active_offer_count': 12,
};

Map<String, dynamic> sellerProductJson({
  int productId = 1,
  String price = '615000.00',
}) => {
  'product_id': productId,
  'slug': 'p-$productId',
  'name': {'ru': 'iPhone', 'kk': 'iPhone', 'en': 'iPhone'},
  'brand': 'Apple',
  'rating': 4.3,
  'review_count': 928,
  'primary_image': 'https://example.com/p$productId.jpg',
  'offer_id': 675,
  'sku': 'SKU-675',
  'price': price,
  'old_price': null,
  'discount_percent': 0,
  'delivery_days': 2,
  'available_quantity': 5,
};

Map<String, dynamic> reviewJson({int id = 1, int rating = 4}) => {
  'id': id,
  'rating': rating,
  'text': 'Хорошее качество',
  'user_display_name': 'Айгерим К.',
  'created_at': '2026-09-10T17:35:24.937542+05:00',
};
