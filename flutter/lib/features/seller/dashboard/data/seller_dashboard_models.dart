/// Typed view of `GET /api/v1/seller/dashboard` (backend
/// `models.SellerDashboardSummary`). Only fields the backend actually
/// sends — no guessed metrics. Money stays an exact decimal string; the
/// app never does arithmetic on balances (Stage F6A §11).
class SellerDashboardModel {
  const SellerDashboardModel({
    required this.salesToday,
    required this.ordersToday,
    required this.ordersTotal,
    required this.pendingBalance,
    required this.availableBalance,
    required this.activeOffers,
    required this.lowStockOffers,
    required this.lowStockThreshold,
    required this.rating,
    required this.reviewCount,
  });

  /// Gross merchandise value for this seller's lines today (decimal string).
  final String salesToday;
  final int ordersToday;
  final int ordersTotal;

  /// Net funds not yet released (decimal string).
  final String pendingBalance;

  /// Net funds available to withdraw (decimal string).
  final String availableBalance;

  final int activeOffers;

  /// Count of the seller's offers at/under [lowStockThreshold] — the
  /// backend computes it; the app never recomputes the comparison.
  final int lowStockOffers;
  final int lowStockThreshold;

  final double rating;
  final int reviewCount;

  bool get hasLowStock => lowStockOffers > 0;

  factory SellerDashboardModel.fromJson(Map<String, dynamic> j) =>
      SellerDashboardModel(
        salesToday: j['sales_today'] as String? ?? '0',
        ordersToday: (j['orders_today'] as num?)?.toInt() ?? 0,
        ordersTotal: (j['orders_total'] as num?)?.toInt() ?? 0,
        pendingBalance: j['pending_balance'] as String? ?? '0',
        availableBalance: j['available_balance'] as String? ?? '0',
        activeOffers: (j['active_offers'] as num?)?.toInt() ?? 0,
        lowStockOffers: (j['low_stock_offers'] as num?)?.toInt() ?? 0,
        lowStockThreshold: (j['low_stock_threshold'] as num?)?.toInt() ?? 5,
        rating: (j['rating'] as num?)?.toDouble() ?? 0,
        reviewCount: (j['review_count'] as num?)?.toInt() ?? 0,
      );
}

/// What the dashboard screen renders: the metrics plus the seller's public
/// identity (name / verified), which comes from `GET /sellers/:id`. The
/// identity is best-effort — if it fails, [sellerName] falls back and
/// [identityLoaded] is false, but the metrics still render.
class SellerDashboardView {
  const SellerDashboardView({
    required this.metrics,
    required this.sellerName,
    required this.isVerified,
    required this.identityLoaded,
  });

  final SellerDashboardModel metrics;
  final String sellerName;
  final bool isVerified;
  final bool identityLoaded;
}
