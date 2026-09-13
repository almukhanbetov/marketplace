import '../../../orders/data/order_models.dart';

/// One row of `GET /api/v1/seller/orders` (backend
/// `models.SellerOrderSummary`) — a customer order that contains at least
/// one of THIS seller's lines, with totals computed from this seller's
/// lines only. The seller never sees another seller's lines or amounts
/// (Stage F6C §5). Money stays an exact decimal string; the seller order
/// API is read-only (§7/§16).
class SellerOrderListItem {
  const SellerOrderListItem({
    required this.orderId,
    required this.orderNumber,
    required this.status,
    required this.createdAt,
    required this.sellerItemCount,
    required this.sellerGrossAmount,
    required this.sellerCommissionAmount,
    required this.sellerNetAmount,
  });

  final int orderId;
  final String orderNumber;
  final OrderStatus status;
  final DateTime createdAt;
  final int sellerItemCount;

  /// Sum of this seller's `total_price` on the order.
  final String sellerGrossAmount;

  /// Commission the marketplace takes on this seller's lines.
  final String sellerCommissionAmount;

  /// What lands in this seller's balance (`gross - commission`).
  final String sellerNetAmount;

  factory SellerOrderListItem.fromJson(Map<String, dynamic> j) =>
      SellerOrderListItem(
        orderId: (j['order_id'] as num).toInt(),
        orderNumber: j['order_number'] as String? ?? '',
        status: OrderStatus.fromWire(j['status'] as String?),
        createdAt:
            DateTime.tryParse(j['created_at'] as String? ?? '')?.toLocal() ??
            DateTime.fromMillisecondsSinceEpoch(0),
        sellerItemCount: (j['seller_item_count'] as num?)?.toInt() ?? 0,
        sellerGrossAmount: j['seller_gross_amount'] as String? ?? '0',
        sellerCommissionAmount: j['seller_commission_amount'] as String? ?? '0',
        sellerNetAmount: j['seller_net_amount'] as String? ?? '0',
      );
}

/// `GET /api/v1/seller/orders/:orderId` (backend `models.SellerOrderDetail`).
/// `items` are only this seller's lines — the backend filters
/// `WHERE order_id = ? AND seller_id = ?` and returns `ORDER_NOT_FOUND`
/// when this seller has no line on the order (indistinguishable from a
/// nonexistent order — cannot be probed, §5).
class SellerOrderDetail {
  const SellerOrderDetail({
    required this.orderId,
    required this.orderNumber,
    required this.status,
    required this.createdAt,
    required this.delivery,
    required this.items,
    required this.sellerGrossAmount,
    required this.sellerCommissionAmount,
    required this.sellerNetAmount,
  });

  final int orderId;
  final String orderNumber;
  final OrderStatus status;
  final DateTime createdAt;

  /// Same address snapshot the customer's order shows — the seller needs it
  /// to ship (§4/§15); checkout never collects a separate name/phone.
  final OrderAddressSnapshotModel delivery;
  final List<SellerOrderItem> items;
  final String sellerGrossAmount;
  final String sellerCommissionAmount;
  final String sellerNetAmount;

  int get itemCount => items.fold(0, (n, it) => n + it.quantity);

  factory SellerOrderDetail.fromJson(Map<String, dynamic> j) =>
      SellerOrderDetail(
        orderId: (j['order_id'] as num).toInt(),
        orderNumber: j['order_number'] as String? ?? '',
        status: OrderStatus.fromWire(j['status'] as String?),
        createdAt:
            DateTime.tryParse(j['created_at'] as String? ?? '')?.toLocal() ??
            DateTime.fromMillisecondsSinceEpoch(0),
        delivery: OrderAddressSnapshotModel.fromJson(
          Map<String, dynamic>.from(j['delivery'] as Map? ?? const {}),
        ),
        items: ((j['items'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) => SellerOrderItem.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
        sellerGrossAmount: j['seller_gross_amount'] as String? ?? '0',
        sellerCommissionAmount: j['seller_commission_amount'] as String? ?? '0',
        sellerNetAmount: j['seller_net_amount'] as String? ?? '0',
      );
}

/// One of this seller's lines on an order — a historical snapshot. Prices
/// come from the order response, never from today's catalog (§8).
class SellerOrderItem {
  const SellerOrderItem({
    required this.productName,
    required this.sku,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    required this.commissionAmount,
    required this.sellerAmount,
    this.productId,
  });

  final int? productId;
  final String productName;
  final String sku;
  final int quantity;
  final String unitPrice;
  final String totalPrice;
  final String commissionAmount;
  final String sellerAmount;

  factory SellerOrderItem.fromJson(Map<String, dynamic> j) => SellerOrderItem(
    productId: (j['product_id'] as num?)?.toInt(),
    productName: j['product_name'] as String? ?? '',
    sku: j['sku'] as String? ?? '',
    quantity: (j['quantity'] as num?)?.toInt() ?? 1,
    unitPrice: j['unit_price'] as String? ?? '0',
    totalPrice: j['total_price'] as String? ?? '0',
    commissionAmount: j['commission_amount'] as String? ?? '0',
    sellerAmount: j['seller_amount'] as String? ?? '0',
  );
}
