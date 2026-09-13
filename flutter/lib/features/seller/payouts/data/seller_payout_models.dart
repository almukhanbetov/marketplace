/// `payouts.status` CHECK constraint. Stage 7 only ever creates `pending`;
/// `processing` / `paid` / `rejected` are set by a later settlement stage.
enum PayoutStatus {
  pending('pending'),
  processing('processing'),
  paid('paid'),
  rejected('rejected'),
  unknown('');

  const PayoutStatus(this.wire);
  final String wire;

  String get labelKey => 'payout.status.$name';

  static PayoutStatus fromWire(String? wire) => PayoutStatus.values.firstWhere(
    (s) => s.wire == wire,
    orElse: () => PayoutStatus.unknown,
  );
}

/// One row of `GET /api/v1/seller/payouts` (backend `models.Payout`).
/// `amount` stays an exact backend decimal string (Stage F6D §5).
class SellerPayoutModel {
  const SellerPayoutModel({
    required this.id,
    required this.amount,
    required this.status,
    required this.requestedAt,
    this.processedAt,
  });

  final int id;
  final String amount;
  final PayoutStatus status;
  final DateTime requestedAt;
  final DateTime? processedAt;

  factory SellerPayoutModel.fromJson(Map<String, dynamic> j) =>
      SellerPayoutModel(
        id: (j['id'] as num).toInt(),
        amount: j['amount'] as String? ?? '0',
        status: PayoutStatus.fromWire(j['status'] as String?),
        requestedAt:
            DateTime.tryParse(j['requested_at'] as String? ?? '')?.toLocal() ??
            DateTime.fromMillisecondsSinceEpoch(0),
        processedAt: (j['processed_at'] as String?) == null
            ? null
            : DateTime.tryParse(j['processed_at'] as String)?.toLocal(),
      );
}

/// The result handed back after `POST /seller/payouts` — a transient value,
/// never persisted; the backend/DB is the payout's source of truth.
class CreatePayoutResult {
  const CreatePayoutResult(this.payout);
  final SellerPayoutModel payout;
}
