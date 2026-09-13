import '../../../core/auth/auth_controller.dart';
import '../../../core/router/routes.dart';

/// Where to send the user right after a successful login / register
/// (Stage F2 §32/§37).
///
///  - a [returnTo] the guard captured wins (they were heading somewhere),
///  - otherwise: customer / seller → home; admin → the web-only notice.
String landingRouteFor(AuthUserRole role, {String? returnTo}) {
  if (returnTo != null && returnTo.isNotEmpty && returnTo != Routes.login) {
    return returnTo;
  }
  return switch (role) {
    AuthUserRole.admin => Routes.adminNotice,
    AuthUserRole.customer || AuthUserRole.seller => Routes.home,
  };
}
