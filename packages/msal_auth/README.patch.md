# Local patch: `msal_auth` 3.5.3

This is a verbatim copy of the published `msal_auth` 3.5.3 package with one
Android-side fix. It is wired in through `dependency_overrides` in the root
`pubspec.yaml`.

## Problem

`MsalAuthHandler.acquireTokenSilent()` used:

```kotlin
msal.iSingleAccountPca!!.currentAccount?.let { ... forAccount(currentAccount) ... }
```

`ISingleAccountPublicClientApplication.currentAccount` reads the persisted
"current account" preference, which can drift from the account actually held in
the token cache/broker (e.g. after a reinstall or a partially corrupt cache).
MSAL then throws `MsalClientException` with code `current_account_mismatch` and
message *"The signed in account does not match with the provided account."*

Because the app calls silent renewal on every HTTP 401, the error kept coming
back even after a fresh interactive sign-in.

## Fix

`acquireTokenSilent()` now calls `getCurrentAccountAsync(...)`, which reconciles
the account from the token cache. The callback
`MsalAuth.silentCurrentAccountCallback(...)` performs the silent request with
that reconciled account.

Changed files:

- `android/src/main/kotlin/com/example/msal_auth/MsalAuthHandler.kt`
- `android/src/main/kotlin/com/example/msal_auth/MsalAuth.kt`

## Upstream

If a later `msal_auth` release fixes this, remove the `dependency_overrides`
entry and bump the dependency in the root `pubspec.yaml`.
