import '../../../../shared/models/localized_text.dart';

/// One row of `GET /api/v1/seller/inventory` (backend
/// `models.SellerInventoryItem`). [offerId] is the key for the inventory
/// PATCH. [isLowStock] is the backend's own flag — the app never applies a
/// threshold of its own (Stage F6B §16).
class SellerInventoryItemModel {
  const SellerInventoryItemModel({
    required this.offerId,
    required this.productId,
    required this.productName,
    required this.sku,
    required this.availableQuantity,
    required this.reservedQuantity,
    required this.isLowStock,
  });

  final int offerId;
  final int productId;
  final LocalizedText productName;
  final String sku;
  final int availableQuantity;
  final int reservedQuantity;
  final bool isLowStock;

  factory SellerInventoryItemModel.fromJson(Map<String, dynamic> j) =>
      SellerInventoryItemModel(
        offerId: (j['offer_id'] as num).toInt(),
        productId: (j['product_id'] as num?)?.toInt() ?? 0,
        productName: LocalizedText.fromJson(j['product_name']),
        sku: j['sku'] as String? ?? '',
        availableQuantity: (j['available_quantity'] as num?)?.toInt() ?? 0,
        reservedQuantity: (j['reserved_quantity'] as num?)?.toInt() ?? 0,
        isLowStock: j['is_low_stock'] as bool? ?? false,
      );
}
