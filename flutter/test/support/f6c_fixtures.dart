/// JSON fixtures for `GET /seller/orders` and `GET /seller/orders/:id`
/// (shapes verified against the running backend, Stage F6C).
library;

Map<String, dynamic> sellerOrderListJson({
  int orderId = 145,
  String number = 'MK-2026-000145',
  String status = 'paid',
  String createdAt = '2026-09-10T21:41:04.899372+05:00',
  int sellerItemCount = 1,
  String gross = '558000.00',
  String commission = '62000.00',
  String net = '496000.00',
}) => {
  'order_id': orderId,
  'order_number': number,
  'status': status,
  'created_at': createdAt,
  'seller_item_count': sellerItemCount,
  'seller_gross_amount': gross,
  'seller_commission_amount': commission,
  'seller_net_amount': net,
};

Map<String, dynamic> sellerOrderItemJson({
  int? productId = 1,
  String name = 'iPhone 17 Pro 256GB',
  String sku = 'SKU-001',
  int quantity = 1,
  String unitPrice = '620000.00',
  String? totalPrice,
  String commission = '62000.00',
  String sellerAmount = '558000.00',
}) => {
  'product_id': productId,
  'product_name': name,
  'sku': sku,
  'quantity': quantity,
  'unit_price': unitPrice,
  'total_price': totalPrice ?? unitPrice,
  'commission_amount': commission,
  'seller_amount': sellerAmount,
};

Map<String, dynamic> sellerOrderDetailJson({
  int orderId = 145,
  String number = 'MK-2026-000145',
  String status = 'paid',
  List<Map<String, dynamic>>? items,
  String gross = '558000.00',
  String commission = '62000.00',
  String net = '496000.00',
}) => {
  'order_id': orderId,
  'order_number': number,
  'status': status,
  'created_at': '2026-09-10T21:41:04.899372+05:00',
  'delivery': {
    'title': 'Дом',
    'city': 'Алматы',
    'street': 'ул. Достык',
    'house': '89',
    'apartment': '12',
    'postal_code': '050000',
  },
  'items': items ?? [sellerOrderItemJson()],
  'seller_gross_amount': gross,
  'seller_commission_amount': commission,
  'seller_net_amount': net,
};
