/// Typed view of `GET /api/v1/seller/finance` (backend
/// `models.SellerFinanceSummary`). Every field is an exact backend decimal
/// string — the app never does arithmetic on balances (Stage F6D §5). The
/// backend keeps `gross_sales - commission_total == seller_net_total` and
/// owns the pending/available split.
class SellerFinanceModel {
  const SellerFinanceModel({
    required this.grossSales,
    required this.commissionTotal,
    required this.sellerNetTotal,
    required this.pendingBalance,
    required this.availableBalance,
    required this.paidOutTotal,
  });

  /// Gross merchandise value of this seller's delivered/valid lines.
  final String grossSales;

  /// Total marketplace commission on those lines.
  final String commissionTotal;

  /// `grossSales - commissionTotal`.
  final String sellerNetTotal;

  /// Net funds not yet released — **NOT withdrawable** (§9).
  final String pendingBalance;

  /// Net funds ready to withdraw — the only pool a payout draws from (§9).
  final String availableBalance;

  /// Sum of all `paid` payouts.
  final String paidOutTotal;

  factory SellerFinanceModel.fromJson(Map<String, dynamic> j) =>
      SellerFinanceModel(
        grossSales: j['gross_sales'] as String? ?? '0',
        commissionTotal: j['commission_total'] as String? ?? '0',
        sellerNetTotal: j['seller_net_total'] as String? ?? '0',
        pendingBalance: j['pending_balance'] as String? ?? '0',
        availableBalance: j['available_balance'] as String? ?? '0',
        paidOutTotal: j['paid_out_total'] as String? ?? '0',
      );
}
