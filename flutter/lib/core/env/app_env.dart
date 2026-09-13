/// Compile-time environment configuration.
///
/// Nothing here is hardcoded to a deployment — every value comes from
/// `--dart-define` flags passed at build/run time, with development-only
/// fallbacks so `flutter run` works out of the box against a local backend.
///
/// Example (physical Android device on the same LAN as the API host):
/// ```
/// flutter run \
///   --dart-define=API_BASE_URL=http://192.168.1.42:8081/api/v1 \
///   --dart-define=APP_ENV=development
/// ```
///
/// Example (production):
/// ```
/// flutter build apk --release \
///   --dart-define=API_BASE_URL=https://api.nova.kz/api/v1 \
///   --dart-define=APP_ENV=production
/// ```
library;

/// Deployment flavour. Only affects client behaviour (logging verbosity,
/// asserting on insecure config) — never business logic, which is 100%
/// owned by the Go backend.
enum AppEnvFlavor { development, staging, production }

class AppEnv {
  const AppEnv._();

  /// Base URL of the Go REST API, including the `/api/v1` suffix.
  ///
  /// Dev fallback is the Android-emulator loopback alias (`10.0.2.2`) on
  /// the port the local backend currently uses (8081). Override for every
  /// other target — see the class doc comment and `docs/ANDROID_IOS.md`.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8081/api/v1',
  );

  static const String _rawEnv = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );

  static AppEnvFlavor get flavor => switch (_rawEnv) {
    'production' => AppEnvFlavor.production,
    'staging' => AppEnvFlavor.staging,
    _ => AppEnvFlavor.development,
  };

  static bool get isProduction => flavor == AppEnvFlavor.production;
  static bool get isDevelopment => flavor == AppEnvFlavor.development;

  /// Network + verbose logging is allowed only outside production, and
  /// never logs Authorization headers, tokens, cookies or passwords
  /// (enforced in [ApiClient]'s interceptor).
  static bool get enableNetworkLogging => !isProduction;

  /// Connect / receive timeout for API calls.
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 20);
}
