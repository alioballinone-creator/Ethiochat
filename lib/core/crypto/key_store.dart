import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure storage for identity keys and session keys.
/// Never logs keys.
class KeyStore {
  KeyStore([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                  accessibility:
                      KeychainAccessibility.first_unlock_this_device),
            );

  final FlutterSecureStorage _storage;

  static const _identityKey = 'e2ee_identity_key';
  static const _signedPrekey = 'e2ee_signed_prekey';
  static const _registrationId = 'e2ee_registration_id';

  Future<void> saveIdentityKey(String key) =>
      _storage.write(key: _identityKey, value: key);
  Future<String?> getIdentityKey() => _storage.read(key: _identityKey);
  Future<void> saveSignedPrekey(String key) =>
      _storage.write(key: _signedPrekey, value: key);
  Future<String?> getSignedPrekey() => _storage.read(key: _signedPrekey);
  Future<void> saveRegistrationId(int id) =>
      _storage.write(key: _registrationId, value: id.toString());
  Future<int?> getRegistrationId() async {
    final v = await _storage.read(key: _registrationId);
    return v == null ? null : int.tryParse(v);
  }

  Future<void> clearAll() => _storage.deleteAll();
}
