import '../../../core/errors/api_exception.dart';
import '../../../core/localization/app_strings.dart';

/// Where an auth error should surface.
enum AuthErrorField { identifier, email, phone, password, none }

class AuthError {
  const AuthError(this.message, {this.field = AuthErrorField.none});
  final String message;
  final AuthErrorField field;
}

/// Turns anything thrown by `AuthRepository` into a localized [AuthError]
/// (Stage F2 §24) — the raw backend code / JSON never reaches the user.
AuthError mapAuthError(Object error, AppStrings s) {
  if (error is! ApiException) {
    return AuthError(s('error.UNKNOWN_ERROR'));
  }

  final field = switch (error.code) {
    'EMAIL_ALREADY_EXISTS' => AuthErrorField.email,
    'PHONE_ALREADY_EXISTS' => AuthErrorField.phone,
    'WEAK_PASSWORD' => AuthErrorField.password,
    'INVALID_CREDENTIALS' => AuthErrorField.password,
    _ => AuthErrorField.none,
  };

  // Prefer a code-specific localized string; the mapper in AppStrings
  // already falls back to a generic message for unknown codes.
  final message = switch (error.code) {
    'TOO_MANY_REQUESTS' => s('error.RATE_LIMITED'),
    _ => s.apiError(error.code),
  };

  return AuthError(message, field: field);
}
