import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thin secure-storage wrapper. MSAL keeps tokens in the platform keystore/
/// keychain natively; we only persist non-secret UI state (selected role,
/// last account id) here.
class SecureStore {
  SecureStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _kRole = 'wt_selected_role';
  static const _kAccountId = 'wt_account_id';

  Future<String?> readRole() => _storage.read(key: _kRole);
  Future<void> writeRole(String role) => _storage.write(key: _kRole, value: role);
  Future<void> clearRole() => _storage.delete(key: _kRole);

  Future<String?> readAccountId() => _storage.read(key: _kAccountId);
  Future<void> writeAccountId(String id) => _storage.write(key: _kAccountId, value: id);
  Future<void> clearAccountId() => _storage.delete(key: _kAccountId);
}
