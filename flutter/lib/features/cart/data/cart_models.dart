import '../../../shared/models/localized_text.dart';

/// `GET /me/cart` → `{ id, user_id, items[], summary }`. Every cart
/// mutation returns this same full shape, so the controller just replaces
/// its state (backend-confirmed, §13/§59).
class CartModel {
  const CartModel({
    required this.items,
    required this.itemCount,
    required this.subtotal,
    this.id,
  });

  final int? id;
  final List<CartItemModel> items;

  /// Total quantity across all lines (backend `summary.item_count`).
  final int itemCount;

  /// Exact decimal string — never re-derived on the client (§28/§65).
  final String subtotal;

  bool get isEmpty => items.isEmpty;

  /// Lines grouped by seller, preserving first-seen order (§20).
  List<CartSellerGroup> get groupedBySeller {
    final order = <int>[];
    final bySeller = <int, List<CartItemModel>>{};
    for (final it in items) {
      bySeller
          .putIfAbsent(it.seller.id, () {
            order.add(it.seller.id);
            return [];
          })
          .add(it);
    }
    return [
      for (final sid in order)
        CartSellerGroup(
          seller: bySeller[sid]!.first.seller,
          items: bySeller[sid]!,
        ),
    ];
  }

  static const empty = CartModel(items: [], itemCount: 0, subtotal: '0.00');

  factory CartModel.fromJson(Map<String, dynamic> j) {
    final rawItems = (j['items'] as List?) ?? const [];
    final summary = (j['summary'] as Map?) ?? const {};
    return CartModel(
      id: (j['id'] as num?)?.toInt(),
      items: rawItems
          .whereType<Map>()
          .map((m) => CartItemModel.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
      itemCount: (summary['item_count'] as num?)?.toInt() ?? 0,
      subtotal: summary['subtotal'] as String? ?? '0.00',
    );
  }
}

class CartSellerGroup {
  const CartSellerGroup({required this.seller, required this.items});
  final CartItemSeller seller;
  final List<CartItemModel> items;
}

class CartItemModel {
  const CartItemModel({
    required this.id,
    required this.quantity,
    required this.sellerOfferId,
    required this.product,
    required this.seller,
    required this.price,
    required this.deliveryDays,
    required this.availableQuantity,
    required this.isAvailable,
    required this.lineTotal,
    this.oldPrice,
  });

  /// Cart-item id — the key for PATCH / DELETE (NOT the product id).
  final int id;
  final int quantity;

  /// The marketplace identity of the line: same product from two sellers
  /// = two items, because their `sellerOfferId` differs (§15).
  final int sellerOfferId;

  final CartItemProduct product;
  final CartItemSeller seller;
  final String price;
  final String? oldPrice;
  final int deliveryDays;
  final int availableQuantity;
  final bool isAvailable;
  final String lineTotal;

  bool get atStockLimit => quantity >= availableQuantity;

  factory CartItemModel.fromJson(Map<String, dynamic> j) => CartItemModel(
    id: (j['id'] as num).toInt(),
    quantity: (j['quantity'] as num?)?.toInt() ?? 1,
    sellerOfferId: (j['seller_offer_id'] as num?)?.toInt() ?? 0,
    product: CartItemProduct.fromJson(
      Map<String, dynamic>.from(j['product'] as Map? ?? const {}),
    ),
    seller: CartItemSeller.fromJson(
      Map<String, dynamic>.from(j['seller'] as Map? ?? const {}),
    ),
    price: j['price'] as String? ?? '0',
    oldPrice: j['old_price'] as String?,
    deliveryDays: (j['delivery_days'] as num?)?.toInt() ?? 0,
    availableQuantity: (j['available_quantity'] as num?)?.toInt() ?? 0,
    isAvailable: j['is_available'] as bool? ?? true,
    lineTotal: j['line_total'] as String? ?? '0',
  );
}

class CartItemProduct {
  const CartItemProduct({
    required this.id,
    required this.brand,
    required this.name,
    this.primaryImage,
  });

  final int id;
  final String brand;
  final LocalizedText name;
  final String? primaryImage;

  factory CartItemProduct.fromJson(Map<String, dynamic> j) => CartItemProduct(
    id: (j['id'] as num?)?.toInt() ?? 0,
    brand: j['brand'] as String? ?? '',
    name: LocalizedText.fromJson(j['name']),
    primaryImage: j['primary_image'] as String?,
  );
}

class CartItemSeller {
  const CartItemSeller({
    required this.id,
    required this.name,
    required this.rating,
  });

  final int id;
  final String name;
  final double rating;

  factory CartItemSeller.fromJson(Map<String, dynamic> j) => CartItemSeller(
    id: (j['id'] as num?)?.toInt() ?? 0,
    name: j['name'] as String? ?? '',
    rating: (j['rating'] as num?)?.toDouble() ?? 0,
  );
}
