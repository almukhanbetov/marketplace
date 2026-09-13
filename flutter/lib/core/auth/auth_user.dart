/// The authenticated user as returned by `GET /api/v1/auth/me`
/// (`models.UserDetail` on the backend). Never carries a password hash or
/// any token — the backend builds this field-by-field.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.fullName,
    required this.role,
    required this.isActive,
    this.email,
    this.phone,
    this.sellerId,
    this.ordersCount = 0,
    this.favoritesCount = 0,
    this.addressesCount = 0,
  });

  final int id;
  final String? email;
  final String? phone;
  final String fullName;

  /// One of `customer` | `seller` | `admin` (backend `users_role_check`).
  final String role;
  final bool isActive;

  /// Set only when [role] == `seller` AND the linked sellers row is
  /// active. Seller-private screens key off this, not off [role] alone.
  final int? sellerId;

  final int ordersCount;
  final int favoritesCount;
  final int addressesCount;

  bool get isCustomer => role == 'customer';
  bool get isSeller => role == 'seller';
  bool get isAdmin => role == 'admin';
  bool get hasSellerAccount => isSeller && sellerId != null;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: (json['id'] as num).toInt(),
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      fullName: (json['full_name'] as String?) ?? '',
      role: (json['role'] as String?) ?? 'customer',
      isActive: (json['is_active'] as bool?) ?? true,
      sellerId: (json['seller_id'] as num?)?.toInt(),
      ordersCount: (json['orders_count'] as num?)?.toInt() ?? 0,
      favoritesCount: (json['favorites_count'] as num?)?.toInt() ?? 0,
      addressesCount: (json['addresses_count'] as num?)?.toInt() ?? 0,
    );
  }
}
