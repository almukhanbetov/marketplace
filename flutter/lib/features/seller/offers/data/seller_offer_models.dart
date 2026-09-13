import '../../../../shared/models/localized_text.dart';

/// One row of `GET /api/v1/seller/offers` (backend `models.SellerOfferItem`)
/// — the seller's own private view of their offer. [id] is the **offer id**
/// used for every mutation; it is never [productId] or the seller id
/// (Stage F6B §9). Money stays an exact decimal string.
class SellerOfferModel {
  const SellerOfferModel({
    required this.id,
    required this.productId,
    required this.productName,
    required this.brand,
    required this.sku,
    required this.price,
    required this.deliveryDays,
    required this.isActive,
    required this.availableQuantity,
    required this.reservedQuantity,
    required this.isLowStock,
    this.primaryImage,
    this.oldPrice,
  });

  /// `seller_offers.id` — the key for PUT / PATCH.
  final int id;
  final int productId;
  final LocalizedText productName;
  final String brand;
  final String sku;
  final String price;
  final String? oldPrice;
  final int deliveryDays;
  final bool isActive;
  final int availableQuantity;
  final int reservedQuantity;

  /// Backend-computed (`available_quantity <= threshold`) — never recomputed
  /// on the client (Stage F6B §16).
  final bool isLowStock;
  final String? primaryImage;

  bool get hasOldPrice =>
      oldPrice != null && oldPrice!.isNotEmpty && oldPrice != price;

  factory SellerOfferModel.fromJson(Map<String, dynamic> j) => SellerOfferModel(
    id: (j['id'] as num).toInt(),
    productId: (j['product_id'] as num?)?.toInt() ?? 0,
    productName: LocalizedText.fromJson(j['product_name']),
    brand: j['brand'] as String? ?? '',
    sku: j['sku'] as String? ?? '',
    price: j['price'] as String? ?? '0',
    oldPrice: j['old_price'] as String?,
    deliveryDays: (j['delivery_days'] as num?)?.toInt() ?? 0,
    isActive: j['is_active'] as bool? ?? true,
    availableQuantity: (j['available_quantity'] as num?)?.toInt() ?? 0,
    reservedQuantity: (j['reserved_quantity'] as num?)?.toInt() ?? 0,
    isLowStock: j['is_low_stock'] as bool? ?? false,
    primaryImage: j['primary_image'] as String?,
  );
}

/// `POST /seller/offers` body — a seller offer against an EXISTING catalog
/// product; the backend never creates a product from this (§7).
class NewOfferInput {
  const NewOfferInput({
    required this.productId,
    required this.sku,
    required this.price,
    required this.deliveryDays,
    required this.stock,
    this.oldPrice,
  });

  final int productId;
  final String sku;
  final String price;
  final String? oldPrice;
  final int deliveryDays;
  final int stock;

  Map<String, dynamic> toJson() => {
    'product_id': productId,
    'sku': sku.trim(),
    'price': price.trim(),
    'old_price': (oldPrice ?? '').trim(), // "" clears / omits it
    'delivery_days': deliveryDays,
    'stock': stock,
  };
}

/// `PUT /seller/offers/:offerId` body — only the four mutable fields the
/// backend accepts; seller / product ownership can never change here (§11).
class EditOfferInput {
  const EditOfferInput({
    required this.sku,
    required this.price,
    required this.deliveryDays,
    this.oldPrice,
  });

  final String sku;
  final String price;
  final String? oldPrice;
  final int deliveryDays;

  Map<String, dynamic> toJson() => {
    'sku': sku.trim(),
    'price': price.trim(),
    'old_price': (oldPrice ?? '').trim(),
    'delivery_days': deliveryDays,
  };

  factory EditOfferInput.fromOffer(SellerOfferModel o) => EditOfferInput(
    sku: o.sku,
    price: o.price,
    oldPrice: o.oldPrice,
    deliveryDays: o.deliveryDays,
  );
}

/// Server-side status filter for the offers list.
enum SellerOfferFilter {
  all(null, 'seller.offers.filter.all'),
  active('active', 'seller.offers.filter.active'),
  inactive('inactive', 'seller.offers.filter.inactive');

  const SellerOfferFilter(this.wire, this.labelKey);
  final String? wire;
  final String labelKey;
}
