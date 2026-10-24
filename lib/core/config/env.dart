/// Environment configuration. Values come from --dart-define in release or
/// a secure store in dev. Never commit secrets.
abstract final class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const hasSupabase = supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
