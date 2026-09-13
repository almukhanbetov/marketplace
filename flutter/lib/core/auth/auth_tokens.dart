/// A freshly issued / rotated credential pair from the native auth
/// transport (`X-Client: nova-mobile`).
///
/// The backend returns this shape (Stage F2 §10) for mobile
/// login / register / refresh:
/// ```json
/// { "access_token": "...", "access_expires_at": "...",
///   "refresh_token": "...", "refresh_expires_at": "..." }
/// ```
/// Web gets only the access token in the body; the refresh token stays in
/// an HttpOnly cookie. A native client has no cookie jar, so it needs the
/// value in hand to put it in the OS keychain.
class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.accessTokenExpiresAt,
    required this.refreshToken,
    this.refreshTokenExpiresAt,
  });

  final String accessToken;
  final DateTime accessTokenExpiresAt;
  final String refreshToken;
  final DateTime? refreshTokenExpiresAt;

  bool get isAccessTokenExpired => DateTime.now().isAfter(
    accessTokenExpiresAt.subtract(const Duration(seconds: 30)),
  );

  /// Parses the `data` object of a mobile login/register/refresh response.
  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      accessToken: json['access_token'] as String,
      accessTokenExpiresAt:
          _parseDate(json['access_expires_at']) ??
          DateTime.now().add(const Duration(minutes: 15)),
      refreshToken: (json['refresh_token'] as String?) ?? '',
      refreshTokenExpiresAt: _parseDate(json['refresh_expires_at']),
    );
  }

  static DateTime? _parseDate(Object? v) =>
      v is String ? DateTime.tryParse(v) : null;
}
