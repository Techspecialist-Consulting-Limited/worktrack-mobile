import 'package:msal_auth/msal_auth.dart';

import '../../core/config/app_config.dart';

/// Wraps the native MSAL public client (single-account mode).
/// Tokens are cached by the platform MSAL SDK — this class never persists
/// or logs access tokens.
class MsalService {
  MsalService._();
  static final MsalService instance = MsalService._();

  SingleAccountPca? _pca;

  bool get isInitialized => _pca != null;

  Future<SingleAccountPca> _ensureInitialized() async {
    final existing = _pca;
    if (existing != null) return existing;

    if (!AppConfig.isConfigured) {
      throw StateError(
        'Missing Entra configuration. Build with '
        '--dart-define-from-file=env.json (see env.example.json).',
      );
    }

    _pca = await SingleAccountPca.create(
      clientId: AppConfig.entraClientId,
      androidConfig: AppConfig.androidRedirectUri.isEmpty
          ? null
          : AndroidConfig(
              // Bundled MSAL configuration asset (broker/prompt settings).
              configFilePath: 'assets/msal_config.json',
              redirectUri: AppConfig.androidRedirectUri,
            ),
      appleConfig: AppleConfig(
        authority: AppConfig.entraAuthority,
        authorityType: AuthorityType.aad,
        broker: Broker.msAuthenticator,
        redirectUri: AppConfig.iosRedirectUri.isEmpty ? null : AppConfig.iosRedirectUri,
      ),
    );
    return _pca!;
  }

  /// Interactive sign-in — always shows the account picker / consent UI.
  Future<AuthenticationResult> signIn() async {
    final pca = await _ensureInitialized();
    return pca.acquireToken(
      scopes: [AppConfig.worktrackScope],
      authority: AppConfig.entraAuthority,
      prompt: Prompt.selectAccount,
    );
  }

  /// Silent token acquisition using the MSAL cache / refresh token.
  /// Throws when no cached session exists or renewal fails.
  Future<AuthenticationResult> acquireTokenSilent() async {
    final pca = await _ensureInitialized();
    return pca.acquireTokenSilent(
      scopes: [AppConfig.worktrackScope],
      authority: AppConfig.entraAuthority,
    );
  }

  /// Currently signed-in account, or null when the cache is empty.
  Future<Account?> currentAccount() async {
    try {
      final pca = await _ensureInitialized();
      return await pca.currentAccount;
    } catch (_) {
      return null;
    }
  }

  /// Signs out of MSAL and clears the native token cache.
  Future<void> signOut() async {
    final pca = _pca;
    if (pca == null) return;
    try {
      await pca.signOut();
    } catch (_) {
      // Cache may already be empty — treat as signed out.
    }
    _pca = null;
  }
}
