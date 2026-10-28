import 'package:supabase_flutter/supabase_flutter.dart';

/// Server-backed wallet PIN using `public.wallet_set_pin` and
/// `public.wallet_verify_pin`. No PIN material is ever stored locally.
class WalletPinStore {
  SupabaseClient get _client => Supabase.instance.client;

  Future<bool> hasPin() async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    // The presence check is implicit: wallet_verify_pin returns false when no
    // secret exists, and wallet_set_pin creates one. We optimistically report
    // false until the user sets a PIN or verification reveals otherwise.
    try {
      final row = await _client
          .from('pin_secrets')
          .select('user_id')
          .eq('user_id', user.id)
          .maybeSingle();
      return row != null;
    } catch (_) {
      return false;
    }
  }

  Future<void> setPin(String pin) async {
    await _client.rpc<dynamic>('wallet_set_pin', params: {'p_pin': pin});
  }

  Future<bool> verify(String pin) async {
    final result =
        await _client.rpc<bool>('wallet_verify_pin', params: {'p_pin': pin});
    return result == true;
  }

  Future<void> clear() async {
    // PIN secrets remain on the server; sign-out removes local access.
  }
}
