/// JSON fixtures mirroring the real `/me/cart`, `/me/favorites` and
/// `/me/addresses` responses (shapes verified against the running API,
/// Stage F4).
library;

import 'package:nova_marketplace/features/catalog/data/catalog_models.dart';

/// A [ProductCardModel] for `toggle(known:)` calls in controller tests.
ProductCardModel favoriteModel({int id = 1, String name = 'iPhone 17 Pro'}) =>
    ProductCardModel.fromJson(favoriteCardJson(id: id, nameRu: name));

Map<String, dynamic> cartItemJson({
  int id = 881,
  int quantity = 1,
  int sellerOfferId = 1,
  int productId = 1,
  String productName = 'iPhone 17 Pro 256GB',
  int sellerId = 1,
  String sellerName = 'TechStore',
  double sellerRating = 4.9,
  String price = '620000.00',
  String? oldPrice = '699000.00',
  int deliveryDays = 1,
  int availableQuantity = 5,
  bool isAvailable = true,
  String? lineTotal,
}) => {
  'id': id,
  'quantity': quantity,
  'seller_offer_id': sellerOfferId,
  'product': {
    'id': productId,
    'brand': 'Apple',
    'name': {'ru': productName, 'kk': productName, 'en': productName},
    'primary_image': 'https://example.com/p$productId.jpg',
  },
  'seller': {'id': sellerId, 'name': sellerName, 'rating': sellerRating},
  'price': price,
  'old_price': oldPrice,
  'delivery_days': deliveryDays,
  'available_quantity': availableQuantity,
  'is_available': isAvailable,
  'line_total': lineTotal ?? price,
};

Map<String, dynamic> cartJson({
  int id = 2,
  int userId = 11,
  List<Map<String, dynamic>>? items,
  int? itemCount,
  String? subtotal,
}) {
  final list = items ?? const <Map<String, dynamic>>[];
  return {
    'id': id,
    'user_id': userId,
    'items': list,
    'summary': {
      'item_count':
          itemCount ??
          list.fold<int>(0, (n, it) => n + (it['quantity'] as int? ?? 0)),
      'subtotal': subtotal ?? '0.00',
    },
  };
}

Map<String, dynamic> addressJson({
  int id = 1,
  int userId = 11,
  String? title = 'Дом',
  String city = 'Алматы',
  String street = 'ул. Достык',
  String house = '89',
  String? apartment = '12',
  String? postalCode = '050000',
  bool isDefault = true,
}) => {
  'id': id,
  'user_id': userId,
  'title': title,
  'city': city,
  'street': street,
  'house': house,
  'apartment': apartment,
  'postal_code': postalCode,
  'is_default': isDefault,
};

Map<String, dynamic> favoriteCardJson({
  int id = 1,
  String nameRu = 'iPhone 17 Pro 256GB',
  String price = '620000.00',
}) => {
  'id': id,
  'slug': 'fav-$id',
  'brand': 'Apple',
  'name': {'ru': nameRu, 'kk': nameRu, 'en': nameRu},
  'category': {
    'id': 1,
    'slug': 'electronics',
    'name': {'ru': 'Электроника', 'kk': 'Электроника', 'en': 'Electronics'},
  },
  'rating': 4.3,
  'review_count': 928,
  'primary_image': 'https://example.com/p$id.jpg',
  'price': price,
  'old_price': null,
  'discount_percent': 0,
  'best_offer_id': 100 + id,
  'seller_name': 'TechStore',
  'seller_rating': 4.9,
  'seller_count': 2,
  'min_delivery_days': 1,
};
