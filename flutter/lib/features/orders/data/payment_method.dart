import 'package:flutter/material.dart';

/// The payment providers the backend accepts (Stage 6 `payments.provider`
/// CHECK constraint — verified against `models/order.go`). All four are
/// **mock** in F5: the backend simulates an instant "paid" result, there is
/// no real gateway call and no card data is ever collected.
///
/// This enum is the single source of truth for payment options — labels and
/// wire values live here so a later stage can swap the mock flow for a real
/// SDK without touching the checkout UI (§66).
enum PaymentMethod {
  card('card', Icons.credit_card_rounded),
  kaspi('kaspi_mock', Icons.account_balance_wallet_rounded),
  applePay('apple_pay_mock', Icons.apple_rounded),
  googlePay('google_pay_mock', Icons.g_mobiledata_rounded);

  const PaymentMethod(this.wire, this.icon);

  /// The exact string sent as `payment_provider` in `POST /me/orders`.
  final String wire;
  final IconData icon;

  /// Localization key for the human label (see `strings_*`).
  String get labelKey => 'payment.method.$name';

  /// F5 shows every configured mock method on both platforms — payments are
  /// simulated, so there is no benefit to hiding Apple Pay on Android etc.,
  /// and the real-API tests expect all four to be selectable. A later stage
  /// with real SDKs would gate this by `Theme.of(context).platform`.
  static const all = PaymentMethod.values;

  static PaymentMethod fromWire(String wire) => PaymentMethod.values.firstWhere(
    (m) => m.wire == wire,
    orElse: () => PaymentMethod.card,
  );
}
