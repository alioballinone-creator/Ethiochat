import 'package:supabase_flutter/supabase_flutter.dart';

class AdminRepository {
  AdminRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<Map<String, dynamic>> call(
    String action, {
    Map<String, dynamic> body = const {},
  }) async {
    final response = await _client.functions.invoke(
      'admin-control',
      body: {'action': action, ...body},
    );
    final data = response.data;
    if (data is! Map) throw const FormatException('Invalid admin response.');
    return Map<String, dynamic>.from(data);
  }

  Future<bool> hasStaffAccess() async {
    final result = await _client.rpc<bool>('is_staff');
    return result == true;
  }
}
