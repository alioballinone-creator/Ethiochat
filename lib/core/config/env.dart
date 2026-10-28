/// Environment configuration.
///
/// Values come from --dart-define or secure configuration at runtime. Do not
/// commit secrets. When a required backend is not configured, the app should
/// fail safely rather than claiming a live connection exists.
abstract final class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Public WebSocket URL for the LiveKit deployment. API keys and secrets are
  /// server-only and must never be compiled into the Flutter application.
  static const livekitUrl = String.fromEnvironment('LIVEKIT_URL');
  static const livekitTokenFunction = String.fromEnvironment(
    'LIVEKIT_TOKEN_FUNCTION',
    defaultValue: 'livekit-token',
  );
  static const firebaseProjectId =
      String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const firebaseAppId = String.fromEnvironment('FIREBASE_APP_ID');
  static const firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const firebaseMessagingSenderId =
      String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const firebaseStorageBucket =
      String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
  static const firebaseIosBundleId =
      String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID');

  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static bool get hasLiveKit => livekitUrl.isNotEmpty;

  /// Firebase client configuration is public (not a server secret). All fields
  /// are required before push registration is attempted.
  static bool get hasFirebase =>
      firebaseProjectId.isNotEmpty &&
      firebaseAppId.isNotEmpty &&
      firebaseApiKey.isNotEmpty &&
      firebaseMessagingSenderId.isNotEmpty;

  /// Only Supabase is required to run the app. Calls and push are optional
  /// capabilities that fail honestly when their public configuration is absent.
  static String get missingBackendConfig {
    final missing = <String>[];
    if (!hasSupabase) {
      missing.add('SUPABASE_URL and SUPABASE_ANON_KEY');
    }
    return missing.isEmpty ? 'none' : missing.join(', ');
  }

  static List<String> get optionalMissingConfig {
    final missing = <String>[];
    if (!hasLiveKit) {
      missing.add('LIVEKIT_URL');
    }
    if (!hasFirebase) {
      missing.add('FIREBASE_*');
    }
    return missing;
  }
}
