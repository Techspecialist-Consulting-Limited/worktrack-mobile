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
  }) =>
      AuthState(
        phase: phase ?? this.phase,
        session: session ?? this.session,
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
        state = state.copyWith(phase: AuthPhase.signedOut);
        return;
      }
      await _resolveSession();
    } catch (_) {
      state = state.copyWith(phase: AuthPhase.signedOut);
    }
  }

  /// Interactive Microsoft sign-in.
  Future<void> signIn() async {
    state = state.copyWith(phase: AuthPhase.signedOut, busy: true, clearError: true);
    try {
      final result = await MsalService.instance.signIn();
      _accessToken = result.accessToken;
      await ref.read(secureStoreProvider).writeAccountId(result.account.id);
      await _resolveSession();
    } on MsalUserCancelException {
      // User cancellation is not an error state — return to welcome quietly.
      state = state.copyWith(phase: AuthPhase.signedOut, busy: false);
      return;
    } on MsalException catch (e) {
      state = state.copyWith(
        phase: AuthPhase.signedOut,
        busy: false,
        errorMessage: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        phase: AuthPhase.signedOut,
        busy: false,
        errorMessage: 'Sign-in failed. Check your connection and try again.',
      );
    }
  }

  /// Fetches memberships for the current token and moves to role selection
  /// or ready state.
  Future<void> _resolveSession() async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final session = await _session.fetchSession();
      if (session.memberships.isEmpty) {
        state = state.copyWith(
          phase: AuthPhase.signedOut,
          busy: false,
          errorMessage: session.accessState == 'deactivated'
              ? 'Your WorkTrack account was deactivated. Ask an administrator to reactivate it.'
              : 'Registration required — complete staff onboarding to continue.',
        );
        return;
      }
      state = state.copyWith(session: session, busy: false);

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
      return result.accessToken;
    } catch (_) {
      return null;
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
