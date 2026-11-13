/// Environment configuration — all values come from `--dart-define` /
/// `--dart-define-from-file` (see env.example.json). No secrets belong here:
/// the Entra mobile app is a public client and tokens stay in MSAL's
/// platform keystore/keychain.
class AppConfig {
  AppConfig._();

  /// Base URL of the WorkTrack Next.js backend.
  /// Android emulator loopback is 10.0.2.2, not localhost.
  static const String apiBaseUrl = String.fromEnvironment(
    'WT_API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );

  /// Entra tenant id (directory id) — single-tenant.
  static const String entraTenantId = String.fromEnvironment('WT_ENTRA_TENANT_ID');

  /// Application (client) id of the Entra *mobile* public-client registration.
  static const String entraClientId = String.fromEnvironment('WT_ENTRA_CLIENT_ID');

  /// Delegated scope for the WorkTrack API, e.g.
  /// `api://<worktrack-api-app-id>/WorkTrack.Access`.
  /// Must equal the backend's ENTRA_API_AUDIENCE + ENTRA_API_SCOPE.
  static const String apiScope = String.fromEnvironment(
    'WT_API_SCOPE',
    defaultValue: 'WorkTrack.Access',
  );

  /// Optional second scope for verified email lookup during invitation
  /// redemption (Microsoft Graph User.Read).
  static const String graphScope = String.fromEnvironment(
    'WT_GRAPH_SCOPE',
    defaultValue: 'User.Read',
  );

  /// Android MSAL redirect URI: `msauth://<package>/<base64url signature hash>`.
  static const String androidRedirectUri = String.fromEnvironment('WT_ANDROID_REDIRECT_URI');

  /// iOS redirect URI (optional — MSAL derives the default when omitted).
  static const String iosRedirectUri = String.fromEnvironment('WT_IOS_REDIRECT_URI');

  static String get entraAuthority => 'https://login.microsoftonline.com/$entraTenantId';

  /// Full scope string MSAL requests, e.g. `api://app-id/WorkTrack.Access`.
  /// When WT_API_SCOPE is a bare scope name it is combined with the API
  /// identifier derived from WT_API_AUDIENCE if provided; otherwise the
  /// scope is used verbatim (recommended: pass the full `api://...` value).
  static const String apiAudience = String.fromEnvironment('WT_API_AUDIENCE');

  static String get worktrackScope =>
      apiAudience.isEmpty ? apiScope : '$apiAudience/$apiScope';

  static bool get isConfigured =>
      entraTenantId.isNotEmpty && entraClientId.isNotEmpty && apiAudience.isNotEmpty;
}
