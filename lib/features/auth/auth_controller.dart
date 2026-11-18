import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:msal_auth/msal_auth.dart';

import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/secure_store.dart';
import 'models.dart';
import 'msal_service.dart';
import 'session_service.dart' show ApiException, SessionService;

enum AuthPhase { restoring, signedOut, selectingRole, ready }

class AuthState {
  const AuthState({
    required this.phase,
    this.session,
    this.selectedMembership,
    this.errorMessage,
    this.busy = false,
  });

  final AuthPhase phase;
  final SessionInfo? session;
  final MembershipInfo? selectedMembership;
  final String? errorMessage;
  final bool busy;

  AuthState copyWith({
    AuthPhase? phase,
    SessionInfo? session,
    MembershipInfo? selectedMembership,
    String? errorMessage,
    bool? busy,
    bool clearError = false,
    bool clearMembership = false,
    bool clearSession = false,
  }) =>
      AuthState(
        phase: phase ?? this.phase,
        session: clearSession ? null : (session ?? this.session),
        selectedMembership:
            clearMembership ? null : (selectedMembership ?? this.selectedMembership),
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        busy: busy ?? this.busy,
      );
}

final secureStoreProvider = Provider<SecureStore>((ref) => SecureStore());
final msalServiceProvider = Provider<MsalService>((ref) => MsalService.instance);

/// Holds the live API client + session service for the signed-in user.
/// The access token lives only in memory — MSAL owns the durable cache.
final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

class AuthController extends Notifier<AuthState> {
  String? _accessToken;
  late final ApiClient _api;
  late final SessionService _session;

  /// MSAL Android keeps a "current account" in its own preferences. When it
  /// drifts from the account actually in the token cache, silent acquisition
  /// fails with `current_account_mismatch` ("The signed in account does not
  /// match with the provided account"). It can only be fixed by clearing the
  /// stale cache and signing in again.
  bool _accountMismatch = false;

  /// Avoid an interactive-sign-in loop if the mismatch keeps coming back in
  /// the same app session.
  bool _mismatchRecoveryTried = false;

  @override
  AuthState build() {
    _api = ApiClient(
      baseUrl: AppConfig.apiBaseUrl,
      accessToken: () => _accessToken ?? '',
      role: () => state.selectedMembership?.role,
      onUnauthorized: _refreshTokenSilently,
    );
    _session = SessionService(_api);
    return const AuthState(phase: AuthPhase.restoring);
  }

  SessionService get sessionService => _session;

  /// Attempts silent restore on app start: MSAL cached account → silent
  /// token → session discovery → memberships.
  Future<void> initialize() async {
    if (!AppConfig.isConfigured) {
      state = state.copyWith(
        phase: AuthPhase.signedOut,
        errorMessage:
            'Missing Entra configuration. Build with --dart-define-from-file=env.json.',
      );
      return;
    }
    try {
      final account = await MsalService.instance.currentAccount();
      if (account == null) {
        state = state.copyWith(phase: AuthPhase.signedOut);
        return;
      }
      final result = await _refreshTokenSilently();
      if (result == null) {
        if (_accountMismatch && !_mismatchRecoveryTried) {
          // The cached account is inconsistent — a silent token is impossible
          // until MSAL's stale state is wiped. Recover with a fresh sign-in.
          _mismatchRecoveryTried = true;
          await reSignIn();
          return;
        }
        state = state.copyWith(
          phase: AuthPhase.signedOut,
          errorMessage: _accountMismatch
              ? 'The Microsoft account on this device has changed. Sign in again to continue.'
              : null,
          clearError: !_accountMismatch,
        );
        return;
      }
      await _resolveSession();
    } catch (_) {
      state = state.copyWith(phase: AuthPhase.signedOut);
    }
  }

  /// Interactive Microsoft sign-in.
  Future<void> signIn({Prompt prompt = Prompt.selectAccount}) async {
    state = state.copyWith(phase: AuthPhase.signedOut, busy: true, clearError: true);
    try {
      final result = await MsalService.instance.signIn(prompt: prompt);
      _accessToken = result.accessToken;
      _accountMismatch = false;
      _mismatchRecoveryTried = false;
      _logTokenClaims(result.accessToken, stage: 'interactive sign-in');
      await ref.read(secureStoreProvider).writeAccountId(result.account.id);
      await _resolveSession();
    } on MsalUserCancelException {
      // User cancellation is not an error state — return to welcome quietly.
      state = state.copyWith(phase: AuthPhase.signedOut, busy: false);
      return;
    } on MsalClientException catch (e) {
      _accountMismatch = e.errorCode == 'current_account_mismatch';
      state = state.copyWith(
        phase: AuthPhase.signedOut,
        busy: false,
        errorMessage: _accountMismatch
            ? 'The Microsoft account on this device has changed. Sign in again to continue.'
            : e.message,
      );
    } on MsalException catch (e) {
      state = state.copyWith(
        phase: AuthPhase.signedOut,
        busy: false,
        errorMessage: e.message,
      );
    } on StateError catch (e) {
      // Configuration problems (missing dart-defines, bad redirect URI)
      // should be visible, not masked as a generic failure.
      state = state.copyWith(
        phase: AuthPhase.signedOut,
        busy: false,
        errorMessage: e.message,
      );
    } catch (e) {
      // Surface the real error while we stabilise MSAL integration.
      // ignore: avoid_print
      print('[auth] signIn failed: ${e.runtimeType}: $e');
      final detail = e.toString();
      state = state.copyWith(
        phase: AuthPhase.signedOut,
        busy: false,
        errorMessage: detail.length > 140
            ? 'Sign-in failed: ${detail.substring(0, 140)}'
            : 'Sign-in failed: $detail',
      );
    }
  }

  /// Clears the stale session (MSAL token cache + locally stored role/account
  /// + in-memory token), then runs a fresh interactive sign-in that forces
  /// the identity provider to ask for credentials again.
  ///
  /// Exposed as a distinct action from [signIn] so a user stuck on
  /// "Your session has expired" (HTTP 401) can recover without manually
  /// reinstalling the app or clearing platform storage.
  Future<void> reSignIn() async {
    state = state.copyWith(busy: true, clearError: true);

    _accessToken = null;
    final store = ref.read(secureStoreProvider);
    await store.clearRole();
    await store.clearAccountId();
    state = state.copyWith(
      clearSession: true,
      clearMembership: true,
    );

    // Drop MSAL's cached account/tokens so the next acquireToken cannot
    // silently reuse the stale token that the backend rejected.
    await MsalService.instance.signOut();

    await signIn(prompt: Prompt.login);
  }

  /// Fetches memberships for the current token and moves to role selection
  /// or ready state.
  Future<void> _resolveSession() async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final session = await _session.fetchSession();
      // Keep the session on state even with zero memberships — the router
      // uses accessState 'none' to show self-service onboarding.
      state = state.copyWith(session: session, busy: false);
      if (session.memberships.isEmpty) {
        state = state.copyWith(
          phase: AuthPhase.signedOut,
          errorMessage: session.accessState == 'deactivated'
              ? 'Your WorkTrack account was deactivated. Ask an administrator to reactivate it.'
              : null,
          clearError: session.accessState != 'deactivated',
        );
        return;
      }

      // Restore a previously selected role when it is still valid.
      final storedRole = await ref.read(secureStoreProvider).readRole();
      MembershipInfo? restore;
      for (final m in session.memberships) {
        if (m.role == storedRole) restore = m;
      }
      if (restore != null) {
        await selectRole(restore);
        return;
      }

      if (session.memberships.length == 1) {
        await selectRole(session.memberships.first);
      } else {
        state = state.copyWith(phase: AuthPhase.selectingRole, clearMembership: true);
      }
    } on ApiException catch (e) {
      // A 401 whose silent renewal hit `current_account_mismatch` means the
      // MSAL account state is broken, not just an expired token.
      if (e.statusCode == 401 && _accountMismatch && !_mismatchRecoveryTried) {
        _mismatchRecoveryTried = true;
        await reSignIn();
        return;
      }
      state = state.copyWith(
        phase: AuthPhase.signedOut,
        busy: false,
        errorMessage: e.statusCode == 401
            ? 'Your session has expired. Please sign in again.'
            : e.message,
      );
    } catch (_) {
      state = state.copyWith(
        phase: AuthPhase.signedOut,
        busy: false,
        errorMessage: 'Could not reach the WorkTrack server.',
      );
    }
  }

  /// Re-resolves the session after self-service onboarding completes.
  Future<void> refreshSession() => _resolveSession();

  /// Selects a WorkTrack role and validates it against the backend by
  /// loading the member-scoped worklog state.
  Future<void> selectRole(MembershipInfo membership) async {
    state = state.copyWith(
      phase: AuthPhase.ready,
      selectedMembership: membership,
      busy: true,
      clearError: true,
    );
    try {
      // The backend re-validates the role header against real memberships;
      // a 401/403 here means the selection was rejected.
      await _session.fetchWorklogState();
      await ref.read(secureStoreProvider).writeRole(membership.role);
      state = state.copyWith(busy: false);
    } on ApiException catch (e) {
      state = state.copyWith(
        phase: AuthPhase.selectingRole,
        busy: false,
        clearMembership: true,
        errorMessage: e.statusCode == 403
            ? 'You do not have access to that role.'
            : e.message,
      );
    } catch (_) {
      state = state.copyWith(
        phase: AuthPhase.selectingRole,
        busy: false,
        clearMembership: true,
        errorMessage: 'Could not verify your selection. Try again.',
      );
    }
  }

  /// Silent renewal used by ApiClient on 401. Returns the fresh token or
  /// null when renewal is impossible (caller then surfaces signed-out).
  Future<String?> _refreshTokenSilently() async {
    try {
      final result = await MsalService.instance.acquireTokenSilent();
      _accessToken = result.accessToken;
      _accountMismatch = false;
      _logTokenClaims(result.accessToken, stage: 'silent renewal');
      return result.accessToken;
    } on MsalClientException catch (e) {
      if (e.errorCode == 'current_account_mismatch') {
        _accountMismatch = true;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Safe JWT diagnostics — prints non-secret claims only (aud, iss, tid,
  /// scp, exp, azp). Never logs the token itself.
  void _logTokenClaims(String token, {required String stage}) {
    try {
      final parts = token.split('.');
      if (parts.length < 2) return;
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final claims = jsonDecode(payload) as Map<String, dynamic>;
      final exp = claims['exp'];
      // ignore: avoid_print
      print('[auth] $stage token claims: '
          'aud=${claims['aud']} iss=${claims['iss']} tid=${claims['tid']} '
          'scp=${claims['scp']} roles=${claims['roles']} azp=${claims['azp']} '
          'appid=${claims['appid']} exp=${exp is int ? DateTime.fromMillisecondsSinceEpoch(exp * 1000).toIso8601String() : exp}');
    } catch (_) {
      // Malformed token — acquisition already succeeded, skip diagnostics.
    }
  }

  Future<void> switchRole() async {
    state = state.copyWith(
      phase: AuthPhase.selectingRole,
      clearMembership: true,
      clearError: true,
    );
    await ref.read(secureStoreProvider).clearRole();
  }

  Future<void> signOut() async {
    await MsalService.instance.signOut();
    final store = ref.read(secureStoreProvider);
    await store.clearRole();
    await store.clearAccountId();
    _accessToken = null;
    state = const AuthState(phase: AuthPhase.signedOut);
  }
}
