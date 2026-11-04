import 'package:supabase_flutter/supabase_flutter.dart';

/// Compile-time feature flags.
///
/// Wallet, the double-entry ledger and red packets are fully implemented but
/// stay hidden in the first public release. Turn them on per build with:
///
///   flutter build apk --dart-define=ENABLE_WALLET=true
abstract final class FeatureFlags {
  static final Map<String, bool> _remoteFlags = {};

  static Future<void> loadRemote(SupabaseClient client) async {
    try {
      final rows = await client
          .from('feature_flags')
          .select('key,enabled,rollout_percent');
      _remoteFlags
        ..clear()
        ..addEntries(rows.map((row) {
          final rollout = (row['rollout_percent'] as num?)?.toInt() ?? 0;
          return MapEntry(
            row['key'] as String,
            row['enabled'] == true && rollout >= 100,
          );
        }));
    } catch (_) {
      _remoteFlags.clear();
    }
  }

  static bool enabled(String key, {bool fallback = false}) =>
      _remoteFlags[key] ?? fallback;

  static bool get maintenanceMode => enabled('maintenance_mode');

  static bool get calls => enabled('calls', fallback: true);

  static bool get moments => enabled('moments', fallback: true);

  static bool get channels => enabled('channels', fallback: true);

  static bool get miniPrograms => enabled('mini_programs', fallback: true);

  /// Wallet tab, ledger history and red-packet entry points.
  static bool get wallet =>
      enabled('wallet', fallback: bool.fromEnvironment('ENABLE_WALLET'));

  /// Payments mini-program entry points (requires [wallet]).
  static bool get payments => wallet;
}
