# WorkTrack Mobile

Native Flutter client for WorkTrack. Talks to the existing Next.js backend
(`work-track` repo) over its secure JSON APIs — all business rules, membership
resolution, permissions and audit stay server-side.

## Stack

- Flutter 3.50 / Dart 3.14, Material 3 (`material_ui`)
- Riverpod — state management (`AuthController` owns session + role state)
- GoRouter — navigation with auth-phase redirects
- Dio — HTTP (`ApiClient` attaches `Authorization: Bearer` + `x-worktrack-role`)
- flutter_secure_storage — non-secret UI prefs (MSAL owns the token cache)
- msal_auth 3.5 — native MSAL (Android/iOS), single-account mode

## Setup

```sh
flutter pub get
cp env.example.json env.json   # fill in values (gitignored)
flutter run --dart-define-from-file=env.json
```

In VS Code, select **WorkTrack (env.json)** from Run and Debug to pass the same
configuration when launching the app.

Android emulator: `WT_API_BASE_URL` defaults to `http://10.0.2.2:3000`
(emulator loopback → host machine). Physical device: use your machine's LAN IP.

## Entra configuration required

1. **Mobile public-client app registration** (separate from the web app):
   - Supported account types: *this organizational directory only* (single tenant)
   - Authentication → Mobile and desktop → add platform:
     - Android: `com.techspecialist.worktrack` + signature hash(es)
       (debug: `keytool -exportcert -alias androiddebugkey -keystore
       ~/.android/debug.keystore -storepass android -keypass android | openssl
       sha1 -binary | openssl base64`)
     - iOS: bundle id `com.techspecialist.worktrack`
   - API permissions → WorkTrack API → delegated `WorkTrack.Access`
     (+ `User.Read` for Graph email fallback during invitation redemption)
   - Grant **admin consent**.
2. **WorkTrack API app registration** (backend): expose scope
   `WorkTrack.Access` with identifier URI = backend `ENTRA_API_AUDIENCE`.

## Environment variables (`env.json`)

| Key | Purpose |
|---|---|
| `WT_API_BASE_URL` | Backend base URL |
| `WT_ENTRA_TENANT_ID` | Directory (tenant) id |
| `WT_ENTRA_CLIENT_ID` | Mobile app client id |
| `WT_API_AUDIENCE` | Must equal backend `ENTRA_API_AUDIENCE` |
| `WT_API_SCOPE` | `WorkTrack.Access` |
| `WT_GRAPH_SCOPE` | `User.Read` (optional) |
| `WT_ANDROID_REDIRECT_URI` | `msauth://com.techspecialist.worktrack/<sig-hash>` — must match manifest + Entra |
| `WT_IOS_REDIRECT_URI` | optional override |

## Architecture

```
lib/
  main.dart, app.dart            # ProviderScope + GoRouter + auth redirects
  core/
    config/app_config.dart       # --dart-define env config
    network/api_client.dart      # Dio + bearer/role headers + 401 silent retry
    storage/secure_store.dart    # flutter_secure_storage (non-secret only)
    theme/app_theme.dart         # design tokens
  features/auth/
    msal_service.dart            # MSAL interactive/silent/sign-out
    auth_controller.dart         # Riverpod Notifier: restore → session → role
    session_service.dart         # /api/mobile/session, /api/worklog/state,
                                 #   /api/mobile/invitations/redeem (prepared)
    models.dart                  # SessionInfo, MembershipInfo, WorklogStateSummary
    screens/                     # splash, welcome, membership, home, diagnostics
```

Auth flow: splash → silent restore (MSAL cache) → `GET /api/mobile/session`
→ single membership auto-selects, multiple → role picker → `selectRole`
validates via `GET /api/worklog/state?scope=me` → home. Role is sent as
`x-worktrack-role` and re-validated server-side on every call.

If the cached account is rejected (HTTP 401 → "Your session has expired"),
the welcome screen shows **Clear session & sign in again**. That action wipes
the MSAL token cache, stored role/account id and in-memory token, then forces
a fresh interactive Microsoft sign-in (`Prompt.login`).

MSAL Android can also drift into `current_account_mismatch` ("The signed in
account does not match with the provided account.") when its persisted
current account no longer matches the cached/broker account. The app detects
that error and performs the same clean re-authentication automatically
(once per app session), then falls back to the button if it happens again.

The root cause was in `msal_auth` 3.5.3: its silent-token path passed a stale
synchronous `currentAccount` into `forAccount(...)`. A local patched copy in
`packages/msal_auth` (wired via `dependency_overrides`) now reconciles the
account with `getCurrentAccountAsync` before silent acquisition. See
`packages/msal_auth/README.patch.md`.

## Status

Phase 2 foundation: sign-in, membership resolution, role selection,
authenticated home, API diagnostics. Work-logging UI intentionally not
implemented yet.
