/// JSON fixtures for `GET /seller/finance` and `/seller/payouts`
/// (shapes verified against the running backend, Stage F6D).
library;

Map<String, dynamic> sellerFinanceJson({
  String grossSales = '8118752.00',
  String commissionTotal = '811875.20',
  String sellerNetTotal = '7306876.80',
  String pendingBalance = '4678876.80',
  String availableBalance = '2626800.00',
  String paidOutTotal = '51200.00',
}) => {
  'gross_sales': grossSales,
  'commission_total': commissionTotal,
  'seller_net_total': sellerNetTotal,
  'pending_balance': pendingBalance,
  'available_balance': availableBalance,
  'paid_out_total': paidOutTotal,
};

Map<String, dynamic> sellerPayoutJson({
  int id = 119,
  String amount = '50000.00',
  String status = 'pending',
  String requestedAt = '2026-09-10T22:07:53.746934+05:00',
  String? processedAt,
}) => {
  'id': id,
  'amount': amount,
  'status': status,
  'requested_at': requestedAt,
  'processed_at': processedAt,
};
