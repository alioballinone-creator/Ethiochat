import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';
import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';

/// Server-side account lifecycle operations.
///
/// These functions require an authenticated session and never accept a user id
/// from the client: the Edge Function derives it from the bearer token.
class AccountService {
  const AccountService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  SupabaseClient? get _effectiveClient =>
      _client ?? (Env.hasSupabase ? Supabase.instance.client : null);

  Future<Result<Map<String, dynamic>>> exportAccount() async {
    if (!Env.hasSupabase) {
      return const Result.failure(
        AuthFailure('Account export requires the configured backend.'),
      );
    }
    final client = _effectiveClient;
    if (client == null || client.auth.currentSession == null) {
      return const Result.failure(
        AuthFailure('Sign in again to export your account.'),
      );
    }

    try {
      final response = await client.functions.invoke('export-account');
      final data = response.data;
      if (data is Map) {
        return Result.success(Map<String, dynamic>.from(data));
      }
      return const Result.failure(
        ServerFailure(
            'The export server returned an invalid response.', null, null),
      );
    } on FunctionException catch (error) {
      return Result.failure(
        ServerFailure(
          _functionMessage(error.details) ??
              'Account export failed (${error.status}).',
          error.status.toString(),
          error,
        ),
      );
    } catch (error) {
      return Result.failure(
        NetworkFailure('Could not export your account.', null, error),
      );
    }
  }

  Future<Result<void>> deleteAccount() async {
    if (!Env.hasSupabase) {
      return const Result.failure(
        AuthFailure('Account deletion requires the configured backend.'),
      );
    }
    final client = _effectiveClient;
    if (client == null || client.auth.currentSession == null) {
      return const Result.failure(
        AuthFailure('Sign in again to delete your account.'),
      );
    }

    try {
      final response = await client.functions.invoke(
        'delete-account',
        body: {'confirm': 'DELETE'},
      );
      final data = response.data;
      if (data is Map && data['ok'] == true) {
        return const Result.success(null);
      }
      return const Result.failure(
        ServerFailure(
          'The deletion server did not confirm the deletion.',
          null,
          null,
        ),
      );
    } on FunctionException catch (error) {
      return Result.failure(
        ServerFailure(
          _functionMessage(error.details) ??
              'Account deletion failed (${error.status}).',
          error.status.toString(),
          error,
        ),
      );
    } catch (error) {
      return Result.failure(
        NetworkFailure('Could not delete your account.', null, error),
      );
    }
  }

  String? _functionMessage(Object? details) {
    if (details is Map) {
      final error = details['error'];
      if (error is Map && error['message'] is String) {
        return error['message'] as String;
      }
      if (details['message'] is String) return details['message'] as String;
    }
    return null;
  }
}
