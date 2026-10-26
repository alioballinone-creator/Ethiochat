/// Compile-time feature flags.
///
/// Wallet, the double-entry ledger and red packets are fully implemented but
/// stay hidden in the first public release. Turn them on per build with:
///
///   flutter build apk --dart-define=ENABLE_WALLET=true
abstract final class FeatureFlags {
  /// Wallet tab, ledger history and red-packet entry points.
  static const bool wallet = bool.fromEnvironment('ENABLE_WALLET');

  /// Payments mini-program entry points (requires [wallet]).
  static bool get payments => wallet;
}
