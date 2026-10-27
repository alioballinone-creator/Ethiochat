import 'package:shared_preferences/shared_preferences.dart';

/// Local PIN gate for the demo wallet. The server uses bcrypt hashes through
/// `public.wallet_set_pin`; this store only protects the on-device demo until
/// the wallet flag is enabled for production.
class WalletPinStore {
  static const _key = 'wallet.pin';

  Future<bool> hasPin() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key);
    return value != null && value.length == 6;
  }

  Future<void> setPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, pin);
  }

  Future<bool> verify(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key) == pin;
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
