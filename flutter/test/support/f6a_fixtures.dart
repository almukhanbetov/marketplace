/// JSON fixtures mirroring `GET /api/v1/seller/dashboard` (backend
/// `models.SellerDashboardSummary`, shape verified against the running API).
library;

Map<String, dynamic> sellerDashboardJson({
  String salesToday = '1237280.00',
  int ordersToday = 6,
  int ordersTotal = 10,
  String pendingBalance = '2787552.00',
  String availableBalance = '2626800.00',
  int activeOffers = 12,
  int lowStockOffers = 2,
  int lowStockThreshold = 5,
  double rating = 4.9,
  int reviewCount = 1243,
}) => {
  'sales_today': salesToday,
  'orders_today': ordersToday,
  'orders_total': ordersTotal,
  'pending_balance': pendingBalance,
  'available_balance': availableBalance,
  'active_offers': activeOffers,
  'low_stock_offers': lowStockOffers,
  'low_stock_threshold': lowStockThreshold,
  'rating': rating,
  'review_count': reviewCount,
};

Map<String, dynamic> sellerProfileJson({
  int id = 1,
  String name = 'TechStore',
  bool isVerified = true,
  bool isActive = true,
  double rating = 4.9,
  int reviewCount = 1243,
}) => {
  'id': id,
  'name': name,
  'slug': 'techstore',
  'description': 'Официальный продавец электроники',
  'rating': rating,
  'review_count': reviewCount,
  'is_verified': isVerified,
  'is_active': isActive,
  'product_count': 10,
  'active_offer_count': 12,
};
