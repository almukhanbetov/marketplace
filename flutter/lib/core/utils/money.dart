import '../../shared/constants/app_constants.dart';

/// The backend sends every monetary value as an exact decimal string
/// (`"620000.00"`), never a float. The app treats it as an opaque display
/// value: parse only for formatting, never for math that the backend is
/// authoritative on (totals, commissions, balances — Stage F1 §50).
class Money {
  const Money._();

  /// Non-breaking space (U+00A0): groups thousands and separates the
  /// amount from the currency symbol without ever letting "620 000 ₸" wrap
  /// across a line.
  static const nbsp = '\u00A0';

  /// `"620000.00"` → `"620 000 ₸"`.
  static String format(String? decimalString, {bool withSymbol = true}) {
    final symbol = withSymbol ? '$nbsp${AppConstants.currencySymbol}' : '';
    if (decimalString == null || decimalString.isEmpty) {
      return withSymbol ? '0$symbol' : '0';
    }
    final dot = decimalString.indexOf('.');
    final whole = dot >= 0 ? decimalString.substring(0, dot) : decimalString;
    return '${_group(whole)}$symbol';
  }

  /// For the rare display-only case that needs a number (e.g. an installment
  /// estimate). Never feed the result back to the backend.
  static double toDouble(String? decimalString) =>
      double.tryParse(decimalString ?? '') ?? 0;

  static String _group(String digits) {
    final neg = digits.startsWith('-');
    final d = neg ? digits.substring(1) : digits;
    final buf = StringBuffer();
    for (var i = 0; i < d.length; i++) {
      if (i > 0 && (d.length - i) % 3 == 0) buf.write(nbsp);
      buf.write(d[i]);
    }
    return neg ? '-$buf' : buf.toString();
  }
}
