/// JSON fixtures for `GET /seller/offers` and `GET /seller/inventory`
/// (shapes verified against the running backend, Stage F6B).
library;

Map<String, dynamic> sellerOfferJson({
  int id = 675,
  int productId = 1,
  String name = 'iPhone 17 Pro 256GB',
  String brand = 'Apple',
  String sku = 'SKU-001',
  String price = '620000.00',
  String? oldPrice = '699000.00',
  int deliveryDays = 2,
  bool isActive = true,
  int available = 7,
  int reserved = 0,
  bool isLowStock = false,
}) => {
  'id': id,
  'product_id': productId,
  'product_name': {'ru': name, 'kk': name, 'en': name},
  'brand': brand,
  'primary_image': 'https://example.com/p$productId.jpg',
  'sku': sku,
  'price': price,
  'old_price': oldPrice,
  'delivery_days': deliveryDays,
  'is_active': isActive,
  'available_quantity': available,
  'reserved_quantity': reserved,
  'is_low_stock': isLowStock,
  'created_at': '2026-08-30T23:02:56.468898+05:00',
  'updated_at': '2026-08-30T23:02:56.468898+05:00',
};

Map<String, dynamic> sellerInventoryJson({
  int offerId = 1,
  int productId = 1,
  String name = 'iPhone 17 Pro 256GB',
  String sku = 'SKU-001-1',
  int available = 4,
  int reserved = 0,
  bool isLowStock = true,
}) => {
  'offer_id': offerId,
  'product_id': productId,
  'product_name': {'ru': name, 'kk': name, 'en': name},
  'sku': sku,
  'available_quantity': available,
  'reserved_quantity': reserved,
  'is_low_stock': isLowStock,
  'updated_at': '2026-09-10T19:10:59.382617+05:00',
};
