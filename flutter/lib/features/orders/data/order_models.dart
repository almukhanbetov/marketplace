import 'payment_method.dart';

/// Typed views of the Stage 6/9 order API. Every monetary field stays an
/// exact backend decimal string — never parsed to a double for anything
/// authoritative (Stage F5 §5). Customer-facing only: the backend already
/// omits commission / seller-net / balances from these payloads, and this
/// layer would ignore them anyway (§41).

/// One row of `GET /me/orders`.
class OrderListItemModel {
  const OrderListItemModel({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.total,
    required this.currency,
    required this.itemCount,
    required this.createdAt,
    required this.itemsPreview,
  });

  final int id;
  final String orderNumber;
  final OrderStatus status;
  final String total;
  final String currency;
  final int itemCount;
  final DateTime createdAt;
  final List<OrderItemPreviewModel> itemsPreview;

  factory OrderListItemModel.fromJson(Map<String, dynamic> j) =>
      OrderListItemModel(
        id: (j['id'] as num).toInt(),
        orderNumber: j['order_number'] as String? ?? '',
        status: OrderStatus.fromWire(j['status'] as String?),
        total: j['total'] as String? ?? '0',
        currency: j['currency'] as String? ?? 'KZT',
        itemCount: (j['item_count'] as num?)?.toInt() ?? 0,
        createdAt:
            DateTime.tryParse(j['created_at'] as String? ?? '')?.toLocal() ??
            DateTime.fromMillisecondsSinceEpoch(0),
        itemsPreview: ((j['items_preview'] as List?) ?? const [])
            .whereType<Map>()
            .map(
              (m) =>
                  OrderItemPreviewModel.fromJson(Map<String, dynamic>.from(m)),
            )
            .toList(),
      );
}

class OrderItemPreviewModel {
  const OrderItemPreviewModel({
    required this.productName,
    required this.quantity,
    this.primaryImage,
  });

  final String productName;
  final int quantity;
  final String? primaryImage;

  factory OrderItemPreviewModel.fromJson(Map<String, dynamic> j) =>
      OrderItemPreviewModel(
        productName: j['product_name'] as String? ?? '',
        quantity: (j['quantity'] as num?)?.toInt() ?? 1,
        primaryImage: j['primary_image'] as String?,
      );
}

/// `GET /me/orders/:orderId` and the body of `POST /me/orders` (both are
/// the backend `OrderDetail` shape).
class OrderDetailModel {
  const OrderDetailModel({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.createdAt,
    required this.delivery,
    required this.payment,
    required this.subtotal,
    required this.discountTotal,
    required this.deliveryTotal,
    required this.total,
    required this.currency,
    required this.items,
  });

  final int id;
  final String orderNumber;
  final OrderStatus status;
  final DateTime createdAt;
  final OrderAddressSnapshotModel delivery;
  final OrderPaymentModel? payment;
  final String subtotal;
  final String discountTotal;
  final String deliveryTotal;
  final String total;
  final String currency;
  final List<OrderItemModel> items;

  int get itemCount => items.fold(0, (n, it) => n + it.quantity);

  /// Items grouped by seller name, preserving first-seen order. A single
  /// customer order can span multiple sellers (§40) — the backend response
  /// carries no `seller_id`, so the display name is the grouping key.
  List<OrderSellerGroup> get groupedBySeller {
    final order = <String>[];
    final bySeller = <String, List<OrderItemModel>>{};
    for (final it in items) {
      bySeller
          .putIfAbsent(it.sellerName, () {
            order.add(it.sellerName);
            return [];
          })
          .add(it);
    }
    return [
      for (final name in order)
        OrderSellerGroup(sellerName: name, items: bySeller[name]!),
    ];
  }

  factory OrderDetailModel.fromJson(Map<String, dynamic> j) => OrderDetailModel(
    id: (j['id'] as num).toInt(),
    orderNumber: j['order_number'] as String? ?? '',
    status: OrderStatus.fromWire(j['status'] as String?),
    createdAt:
        DateTime.tryParse(j['created_at'] as String? ?? '')?.toLocal() ??
        DateTime.fromMillisecondsSinceEpoch(0),
    delivery: OrderAddressSnapshotModel.fromJson(
      Map<String, dynamic>.from(j['delivery'] as Map? ?? const {}),
    ),
    payment: j['payment'] is Map
        ? OrderPaymentModel.fromJson(
            Map<String, dynamic>.from(j['payment'] as Map),
          )
        : null,
    subtotal: j['subtotal'] as String? ?? '0',
    discountTotal: j['discount_total'] as String? ?? '0',
    deliveryTotal: j['delivery_total'] as String? ?? '0',
    total: j['total'] as String? ?? '0',
    currency: j['currency'] as String? ?? 'KZT',
    items: ((j['items'] as List?) ?? const [])
        .whereType<Map>()
        .map((m) => OrderItemModel.fromJson(Map<String, dynamic>.from(m)))
        .toList(),
  );
}

class OrderSellerGroup {
  const OrderSellerGroup({required this.sellerName, required this.items});
  final String sellerName;
  final List<OrderItemModel> items;

  String get groupTotal {
    // Display-only sum of already-authoritative per-line totals. Kept in
    // integer tiyin to avoid float drift; never sent back to the backend.
    var tiyin = 0;
    for (final it in items) {
      tiyin += _toTiyin(it.totalPrice);
    }
    final whole = tiyin ~/ 100;
    final frac = (tiyin % 100).toString().padLeft(2, '0');
    return '$whole.$frac';
  }

  static int _toTiyin(String decimal) {
    final dot = decimal.indexOf('.');
    if (dot < 0) return (int.tryParse(decimal) ?? 0) * 100;
    final whole = int.tryParse(decimal.substring(0, dot)) ?? 0;
    final fracStr = '${decimal.substring(dot + 1)}00'.substring(0, 2);
    final frac = int.tryParse(fracStr) ?? 0;
    return whole * 100 + frac;
  }
}

class OrderItemModel {
  const OrderItemModel({
    required this.productName,
    required this.sellerName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.productId,
    this.primaryImage,
  });

  final int? productId;
  final String productName;
  final String sellerName;
  final int quantity;
  final String unitPrice;
  final String totalPrice;
  final String? primaryImage;

  factory OrderItemModel.fromJson(Map<String, dynamic> j) => OrderItemModel(
    productId: (j['product_id'] as num?)?.toInt(),
    productName: j['product_name'] as String? ?? '',
    sellerName: j['seller_name'] as String? ?? '',
    quantity: (j['quantity'] as num?)?.toInt() ?? 1,
    unitPrice: j['unit_price'] as String? ?? '0',
    totalPrice: j['total_price'] as String? ?? '0',
    primaryImage: j['primary_image'] as String?,
  );
}

class OrderAddressSnapshotModel {
  const OrderAddressSnapshotModel({
    required this.city,
    required this.street,
    required this.house,
    this.title,
    this.apartment,
    this.postalCode,
  });

  final String? title;
  final String city;
  final String street;
  final String house;
  final String? apartment;
  final String? postalCode;

  /// "ул. Достык, 89, кв. 12"
  String get oneLine => [
    street,
    house,
    if ((apartment ?? '').isNotEmpty) 'кв. $apartment',
  ].where((p) => p.isNotEmpty).join(', ');

  factory OrderAddressSnapshotModel.fromJson(Map<String, dynamic> j) =>
      OrderAddressSnapshotModel(
        title: j['title'] as String?,
        city: j['city'] as String? ?? '',
        street: j['street'] as String? ?? '',
        house: j['house'] as String? ?? '',
        apartment: j['apartment'] as String?,
        postalCode: j['postal_code'] as String?,
      );
}

class OrderPaymentModel {
  const OrderPaymentModel({required this.provider, required this.status});

  final PaymentMethod provider;
  final PaymentStatus status;

  factory OrderPaymentModel.fromJson(Map<String, dynamic> j) =>
      OrderPaymentModel(
        provider: PaymentMethod.fromWire(j['provider'] as String? ?? 'card'),
        status: PaymentStatus.fromWire(j['status'] as String?),
      );
}

/// The result handed to the success screen after `POST /me/orders`. Just a
/// transient navigation payload — never persisted; the backend/DB is the
/// order's source of truth (§46).
class CreateOrderResult {
  const CreateOrderResult(this.order);
  final OrderDetailModel order;
}

/// `orders.status`. Stage 6 only produces `new` (briefly) then `paid`; the
/// rest are here for later stages so an unknown value still renders safely.
enum OrderStatus {
  newOrder('new'),
  confirmed('confirmed'),
  paid('paid'),
  processing('processing'),
  shipped('shipped'),
  delivered('delivered'),
  cancelled('cancelled'),
  returned('returned'),
  unknown('');

  const OrderStatus(this.wire);
  final String wire;

  String get labelKey => 'order.status.$name';

  static OrderStatus fromWire(String? wire) => OrderStatus.values.firstWhere(
    (s) => s.wire == wire,
    orElse: () => OrderStatus.unknown,
  );
}

enum PaymentStatus {
  paid('paid'),
  pending('pending'),
  failed('failed'),
  unknown('');

  const PaymentStatus(this.wire);
  final String wire;

  String get labelKey => 'payment.status.$name';

  static PaymentStatus fromWire(String? wire) => PaymentStatus.values
      .firstWhere((s) => s.wire == wire, orElse: () => PaymentStatus.unknown);
}
