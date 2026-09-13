import 'auth_user.dart';

/// The session lifecycle — one enum, never a bag of booleans that can
/// contradict each other (Stage F2 §25).
///
///  - [unknown]        app just launched; nothing decided yet
///  - [restoring]      a stored refresh token is being exchanged
///  - [authenticated]  [AuthState.user] is set
///  - [unauthenticated] no session
///
/// The *login / register form submission* is a transient screen concern
/// (its own loading/error), not part of this — so there is no "loading" or
/// "error" status here to fight with [authenticated].
enum AuthStatus { unknown, restoring, authenticated, unauthenticated }

class AuthState {
  const AuthState({
    required this.status,
    this.user,
    this.restoreFailedTransiently = false,
  });

  final AuthStatus status;
  final AuthUser? user;

  /// Session restore hit a transient failure (offline / timeout / 5xx),
  /// NOT an invalid credential. The refresh token is kept; the app can
  /// retry. Screens use this to show a "can't reach NOVA" retry state
  /// instead of bouncing the user to login (Stage F2 §31/§71).
  final bool restoreFailedTransiently;

  const AuthState.unknown()
    : status = AuthStatus.unknown,
      user = null,
      restoreFailedTransiently = false;

  const AuthState.restoring()
    : status = AuthStatus.restoring,
      user = null,
      restoreFailedTransiently = false;

  const AuthState.unauthenticated({this.restoreFailedTransiently = false})
    : status = AuthStatus.unauthenticated,
      user = null;

  const AuthState.authenticated(AuthUser this.user)
    : status = AuthStatus.authenticated,
      restoreFailedTransiently = false;

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isResolving =>
      status == AuthStatus.unknown || status == AuthStatus.restoring;
  String? get role => user?.role;
}
