import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';

final announcementsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  if (!Env.hasSupabase || Supabase.instance.client.auth.currentUser == null) {
    return const [];
  }
  final rows = await Supabase.instance.client
      .from('announcements')
      .select('id,title,message,published_at')
      .eq('status', 'published')
      .order('published_at', ascending: false)
      .limit(3);
  return rows.map((row) => Map<String, dynamic>.from(row)).toList();
});
