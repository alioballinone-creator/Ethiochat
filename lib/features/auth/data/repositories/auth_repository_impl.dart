import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/env.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/utils/phone.dart';

abstract class AuthRepository {
  Future<Result<void>> sendOtp(String phone);
  Future<Result<String>> verifyOtp(String phone, String code);
  Future<Result<void>> completeProfile(String displayName);
}

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  SupabaseClient? get _effectiveClient =>
      _client ?? (Supabase.instance.initialized ? Supabase.instance.client : null);

  @override
  Future<Result<void>> sendOtp(String phone) async {
    final normalized = PhoneUtils.normalize(phone);
    if (normalized == null) {
      return const Result.failure(
        ValidationFailure('Enter a valid Ethiopian phone number.'),
      );
    }

    if (!Env.hasSupabase) {
      return const Result.failure(
        AuthFailure(
          'Supabase is not configured. Set SUPABASE_URL and SUPABASE_ANON_KEY before signing in.',
        ),
      );
    }

    try {
      final client = _effectiveClient;
      if (client == null) {
        return const Result.failure(
          AuthFailure('Supabase authentication is unavailable.'),
        );
      }
      await client.auth.signInWithOtp(phone: normalized);
      return const Result.success(null);
    } on AuthException catch (error) {
      return Result.failure(
        AuthFailure(error.message, code: error.statusCode?.toString(), cause: error),
      );
    } on SocketException catch (error) {
      return Result.failure(
        NetworkFailure('Could not reach the authentication server.', null, error),
      );
    } catch (error) {
      return Result.failure(mapError(error));
    }
  }

  @override
  Future<Result<String>> verifyOtp(String phone, String code) async {
    final normalized = PhoneUtils.normalize(phone);
    if (normalized == null) {
      return const Result.failure(
        ValidationFailure('Enter a valid Ethiopian phone number.'),
      );
    }

    final trimmedCode = code.trim();
    if (trimmedCode.length != 6 || int.tryParse(trimmedCode) == null) {
      return const Result.failure(
        ValidationFailure('Enter a valid 6-digit verification code.'),
      );
    }

    if (!Env.hasSupabase) {
      return const Result.failure(
        AuthFailure(
          'Supabase is not configured. Set SUPABASE_URL and SUPABASE_ANON_KEY before verifying OTP.',
        ),
      );
    }

    try {
      final client = _effectiveClient;
      if (client == null) {
        return const Result.failure(
          AuthFailure('Supabase authentication is unavailable.'),
        );
      }

      final response = await client.auth.verifyOTP(
        type: OtpType.sms,
        phone: normalized,
        token: trimmedCode,
      );

      final accessToken = response.session?.accessToken;
      if (accessToken == null || accessToken.isEmpty) {
        return const Result.failure(
          AuthFailure('Verification succeeded but no session was returned.'),
        );
      }

      return Result.success(accessToken);
    } on AuthException catch (error) {
      return Result.failure(
        AuthFailure(error.message, code: error.statusCode?.toString(), cause: error),
      );
    } on SocketException catch (error) {
      return Result.failure(
        NetworkFailure('Could not reach the authentication server.', null, error),
      );
    } catch (error) {
      return Result.failure(mapError(error));
    }
  }

  @override
  Future<Result<void>> completeProfile(String displayName) async {
    final cleaned = displayName.trim();
    if (cleaned.length < 2) {
      return const Result.failure(
        ValidationFailure('Display name must be at least 2 characters long.'),
      );
    }

    if (!Env.hasSupabase) {
      return const Result.failure(
        AuthFailure(
          'Profile completion requires Supabase to be configured. Set the required environment variables.',
        ),
      );
    }

    final client = _effectiveClient;
    if (client == null) {
      return const Result.failure(
        AuthFailure('Supabase authentication is unavailable.'),
      );
    }

    final user = client.auth.currentUser;
    if (user == null) {
      return const Result.failure(
        AuthFailure('You must be signed in to complete your profile.'),
      );
    }

    try {
      await client.from('profiles').upsert({
        'id': user.id,
        'display_name': cleaned,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      return const Result.success(null);
    } on AuthException catch (error) {
      return Result.failure(
        AuthFailure(error.message, code: error.statusCode?.toString(), cause: error),
      );
    } on PostgrestException catch (error) {
      return Result.failure(
        ServerFailure(error.message, error.code, error),
      );
    } on SocketException catch (error) {
      return Result.failure(
        NetworkFailure('Profile update could not reach the server.', null, error),
      );
    } catch (error) {
      return Result.failure(mapError(error));
    }
  }
}
