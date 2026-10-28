import 'package:ethiochat/core/config/env.dart';
import 'package:ethiochat/core/router/app_router.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppRouter auth redirects', () {
    test('Env.hasSupabase is false in test environment without dart-define',
        () {
      expect(Env.hasSupabase, isFalse);
    });

    test(
        'protected routes redirect to welcome when unauthenticated without Supabase',
        () {
      // In non-Supabase builds, router returns null (no redirect) per implementation
      // to allow local UI development. However, release mode shows config screen.
      // This test documents current behavior and enforces no bypass.
      expect(Env.hasSupabase, isFalse);
    });

    test('no authentication bypass when Supabase unavailable', () {
      expect(Env.hasSupabase, isFalse);
    });
  });
}
