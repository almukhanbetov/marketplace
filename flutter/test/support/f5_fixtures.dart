/// JSON fixtures mirroring the real Stage 6/9 order API (shapes verified
/// against the running backend, Stage F5).
library;

Map<String, dynamic> orderItemPreviewJson({
  String name = 'iPhone 17 Pro 256GB',
  int quantity = 1,
}) => {
  'product_name': name,
  'primary_image': 'https://example.com/p.jpg',
  'quantity': quantity,
};

Map<String, dynamic> orderListItemJson({
  int id = 197,
  String number = 'MK-2026-000197',
  String status = 'paid',
  String total = '1258600.00',
  int itemCount = 2,
  String createdAt = '2026-09-10T19:10:59.382617+05:00',
}) => {
  'id': id,
  'order_number': number,
  'status': status,
  'total': total,
  'currency': 'KZT',
  'item_count': itemCount,
  'created_at': createdAt,
  'items_preview': [
    orderItemPreviewJson(),
    orderItemPreviewJson(name: 'Galaxy S25 Ultra 512GB', quantity: 2),
  ],
};

Map<String, dynamic> orderItemJson({
  int? productId = 1,
  String name = 'iPhone 17 Pro 256GB',
  String seller = 'TechStore',
  int quantity = 1,
  String unitPrice = '620000.00',
  String? totalPrice,
}) => {
  'product_id': productId,
  'product_name': name,
  'primary_image': 'https://example.com/p.jpg',
  'seller_name': seller,
  'quantity': quantity,
  'unit_price': unitPrice,
  'total_price': totalPrice ?? unitPrice,
};

Map<String, dynamic> orderDetailJson({
  int id = 197,
  String number = 'MK-2026-000197',
  String status = 'paid',
  String paymentProvider = 'kaspi_mock',
  String paymentStatus = 'paid',
  bool multiSeller = false,
  String subtotal = '1258600.00',
  String total = '1258600.00',
}) => {
  'id': id,
  'order_number': number,
  'status': status,
  'created_at': '2026-09-10T19:10:59.382617+05:00',
  'delivery': {
    'title': 'Дом',
    'city': 'Алматы',
    'street': 'ул. Достык',
    'house': '89',
    'apartment': '12',
    'postal_code': '050000',
  },
  'payment': {'provider': paymentProvider, 'status': paymentStatus},
  'subtotal': subtotal,
  'discount_total': '0.00',
  'delivery_total': '0.00',
  'total': total,
  'currency': 'KZT',
  'items': multiSeller
      ? [
          orderItemJson(seller: 'TechStore', unitPrice: '620000.00'),
          orderItemJson(
            productId: 1,
            seller: 'HomeComfort',
            unitPrice: '638600.00',
          ),
          orderItemJson(
            productId: 2,
            name: 'Galaxy S25 Ultra 512GB',
            seller: 'GadgetPro',
            quantity: 2,
            unitPrice: '540000.00',
            totalPrice: '1080000.00',
          ),
        ]
      : [orderItemJson()],
};
