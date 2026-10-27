/// Environment configuration.
///
/// Values come from --dart-define or secure configuration at runtime. Do not
/// commit secrets. When a required backend is not configured, the app should
/// fail safely rather than claiming a live connection exists.
abstract final class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const livekitUrl = String.fromEnvironment('LIVEKIT_URL');
  static const livekitApiKey = String.fromEnvironment('LIVEKIT_API_KEY');
  static const livekitApiSecret = String.fromEnvironment('LIVEKIT_API_SECRET');
  static const firebaseProjectId = String.fromEnvironment('FIREBASE_PROJECT_ID');

  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static bool get hasLiveKit =>
      livekitUrl.isNotEmpty &&
      livekitApiKey.isNotEmpty &&
      livekitApiSecret.isNotEmpty;

  static bool get hasFirebase => firebaseProjectId.isNotEmpty;

  static String get missingBackendConfig {
    final missing = <String>[];
    if (!hasSupabase) {
      missing.add('SUPABASE_URL and SUPABASE_ANON_KEY');
    }
    if (!hasLiveKit) {
      missing.add('LIVEKIT_URL, LIVEKIT_API_KEY and LIVEKIT_API_SECRET');
    }
    if (!hasFirebase) {
      missing.add('FIREBASE_PROJECT_ID');
    }
    return missing.isEmpty ? 'none' : missing.join(', ');
  }
}
