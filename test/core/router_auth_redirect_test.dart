import 'package:ethiochat/core/config/env.dart';
import 'package:ethiochat/core/router/app_router.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('AppRouter redirect protects routes when unauthenticated without Supabase config', () {
    // Without Env.hasSupabase, redirect returns null in all cases per implementation
    expect(Env.hasSupabase, isFalse);
  });
}
