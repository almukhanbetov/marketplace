/// Typed request bodies for the auth endpoints — no raw `Map` is passed
/// around the app (Stage F2 §20).
library;

/// `POST /auth/login` — the backend accepts `email` OR `phone` plus
/// `password`. [identifier] is whatever the user typed; [asJson] routes it
/// to the right field.
class LoginRequest {
  const LoginRequest({required this.identifier, required this.password});

  final String identifier;
  final String password;

  bool get _looksLikeEmail => identifier.contains('@');

  Map<String, dynamic> toJson() => {
    if (_looksLikeEmail)
      'email': identifier.trim()
    else
      'phone': identifier.trim(),
    'password': password,
  };
}

/// `POST /auth/register` — always creates a `customer` account; there is
/// no role field, by construction.
class RegisterRequest {
  const RegisterRequest({
    required this.fullName,
    required this.password,
    this.email,
    this.phone,
  });

  final String fullName;
  final String password;
  final String? email;
  final String? phone;

  Map<String, dynamic> toJson() => {
    'full_name': fullName.trim(),
    'password': password,
    if (email != null && email!.trim().isNotEmpty) 'email': email!.trim(),
    if (phone != null && phone!.trim().isNotEmpty) 'phone': phone!.trim(),
  };
}
