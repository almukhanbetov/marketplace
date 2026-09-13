/// App-wide constants that are not environment config (those live in
/// `core/env/app_env.dart`) and not design tokens (those live in
/// `core/theme`).
class AppConstants {
  const AppConstants._();

  /// Default catalog page size — matches the backend's own `defaultLimit`.
  static const int pageSize = 20;

  /// "Low stock" threshold the seller dashboard highlights — mirrors the
  /// backend's `models.LowStockThreshold`. The backend still computes the
  /// authoritative `is_low_stock` flag; this is display-only.
  static const int lowStockThreshold = 5;

  static const String currencyCode = 'KZT';
  static const String currencySymbol = '₸';

  /// Mock payment providers the checkout offers (backend
  /// `payments.provider` CHECK).
  static const List<String> paymentProviders = [
    'card',
    'kaspi_mock',
    'apple_pay_mock',
    'google_pay_mock',
  ];
}
