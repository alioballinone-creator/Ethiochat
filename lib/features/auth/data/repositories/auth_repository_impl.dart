import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/env.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/utils/phone.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  SupabaseClient? get _effectiveClient =>
      _client ?? (Env.hasSupabase ? Supabase.instance.client : null);

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

    final client = _effectiveClient;
    if (client == null) {
      return const Result.failure(
        AuthFailure('Supabase authentication is unavailable.'),
      );
    }

    try {
      await client.auth.signInWithOtp(phone: normalized);
      return const Result.success(null);
    } on AuthException catch (error) {
      return Result.failure(_authFailure(error));
    } on SocketException catch (error) {
      return Result.failure(
        NetworkFailure(
            'Could not reach the authentication server.', null, error),
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

    final client = _effectiveClient;
    if (client == null) {
      return const Result.failure(
        AuthFailure('Supabase authentication is unavailable.'),
      );
    }

    try {
      final response = await client.auth.verifyOTP(
        type: OtpType.sms,
        phone: normalized,
        token: trimmedCode,
      );

      final session = response.session;
      final accessToken = session?.accessToken;
      if (session == null || accessToken == null || accessToken.isEmpty) {
        return const Result.failure(
          AuthFailure('Verification succeeded but no session was returned.'),
        );
      }

      return Result.success(accessToken);
    } on AuthException catch (error) {
      return Result.failure(_authFailure(error));
    } on SocketException catch (error) {
      return Result.failure(
        NetworkFailure(
            'Could not reach the authentication server.', null, error),
      );
    } catch (error) {
      return Result.failure(mapError(error));
    }
  }

  @override
  Future<Result<RemoteProfile?>> fetchProfile() async {
    if (!Env.hasSupabase) {
      return const Result.failure(
        AuthFailure('Supabase is not configured.'),
      );
    }

    final client = _effectiveClient;
    final user = client?.auth.currentUser;
    if (client == null || user == null || client.auth.currentSession == null) {
      return const Result.failure(
        AuthFailure('You must be signed in to load your profile.'),
      );
    }

    try {
      final row = await client
          .from('profiles')
          .select('display_name, bio, avatar_url, ethio_id')
          .eq('id', user.id)
          .maybeSingle();
      if (row == null) return const Result.success(null);
      return Result.success(
        RemoteProfile(
          displayName: (row['display_name'] as String?)?.trim() ?? '',
          bio: (row['bio'] as String?)?.trim() ?? '',
          avatarUrl: row['avatar_url'] as String?,
          ethioId: row['ethio_id'] as String?,
        ),
      );
    } on PostgrestException catch (error) {
      return Result.failure(ServerFailure(error.message, error.code, error));
    } on SocketException catch (error) {
      return Result.failure(
        NetworkFailure('Could not reach the profile server.', null, error),
      );
    } catch (error) {
      return Result.failure(mapError(error));
    }
  }

  @override
  Future<Result<void>> completeProfile({
    required String displayName,
    String? bio,
    String? phone,
    String? avatarPath,
  }) async {
    final cleaned = displayName.trim();
    if (cleaned.length < 2 || cleaned.length > 50) {
      return const Result.failure(
        ValidationFailure('Display name must be between 2 and 50 characters.'),
      );
    }
    final cleanedBio = bio?.trim() ?? '';
    if (cleanedBio.length > 160) {
      return const Result.failure(
        ValidationFailure('About must be 160 characters or fewer.'),
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
    final user = client?.auth.currentUser;
    if (client == null || user == null || client.auth.currentSession == null) {
      return const Result.failure(
        AuthFailure('You must be signed in to complete your profile.'),
      );
    }

    try {
      String? avatarUrl;
      if (avatarPath != null && avatarPath.isNotEmpty) {
        if (avatarPath.startsWith('http://') ||
            avatarPath.startsWith('https://')) {
          avatarUrl = avatarPath;
        } else {
          final upload = await _uploadAvatar(client, user.id, avatarPath);
          final failure = upload.failureOrNull;
          if (failure != null) return Result.failure(failure);
          avatarUrl = upload.valueOrNull;
        }
      }

      final payload = <String, dynamic>{
        'id': user.id,
        'display_name': cleaned,
        'bio': cleanedBio,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      if (avatarUrl != null) payload['avatar_url'] = avatarUrl;

      await client.from('profiles').upsert(payload);
      return const Result.success(null);
    } on AuthException catch (error) {
      return Result.failure(_authFailure(error));
    } on PostgrestException catch (error) {
      return Result.failure(ServerFailure(error.message, error.code, error));
    } on StorageException catch (error) {
      return Result.failure(
        StorageFailure(error.message, error.statusCode, error),
      );
    } on SocketException catch (error) {
      return Result.failure(
        NetworkFailure(
            'Profile update could not reach the server.', null, error),
      );
    } catch (error) {
      return Result.failure(mapError(error));
    }
  }

  @override
  Future<Result<void>> signOut({bool othersOnly = false}) async {
    if (!Env.hasSupabase) {
      // Debug-only builds have no remote session to clear.
      return const Result.success(null);
    }

    final client = _effectiveClient;
    if (client == null) {
      return const Result.failure(
        AuthFailure('Supabase authentication is unavailable.'),
      );
    }

    try {
      await client.auth.signOut(
        scope: othersOnly ? SignOutScope.others : SignOutScope.local,
      );
      return const Result.success(null);
    } on AuthException catch (error) {
      return Result.failure(_authFailure(error));
    } on SocketException catch (error) {
      return Result.failure(
        NetworkFailure(
            'Could not reach the authentication server.', null, error),
      );
    } catch (error) {
      return Result.failure(mapError(error));
    }
  }

  Future<Result<String>> _uploadAvatar(
    SupabaseClient client,
    String userId,
    String avatarPath,
  ) async {
    final file = File(avatarPath);
    if (!await file.exists()) {
      return const Result.failure(
        ValidationFailure('The selected photo is no longer available.'),
      );
    }

    final extension = p.extension(avatarPath).toLowerCase();
    final contentType = switch (extension) {
      '.jpg' || '.jpeg' => 'image/jpeg',
      '.png' => 'image/png',
      '.webp' => 'image/webp',
      _ => null,
    };
    if (contentType == null) {
      return const Result.failure(
        ValidationFailure('Choose a JPEG, PNG or WebP profile photo.'),
      );
    }

    final objectPath =
        '$userId/avatar-${DateTime.now().millisecondsSinceEpoch}$extension';
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      return const Result.failure(
        ValidationFailure('The selected photo is empty.'),
      );
    }
    if (bytes.length > 10 * 1024 * 1024) {
      return const Result.failure(
        ValidationFailure('Profile photos must be smaller than 10 MB.'),
      );
    }

    final bucket = client.storage.from('avatars');
    await bucket.uploadBinary(
      objectPath,
      bytes,
      fileOptions: FileOptions(contentType: contentType, upsert: false),
    );
    return Result.success(bucket.getPublicUrl(objectPath));
  }

  AuthFailure _authFailure(AuthException error) {
    final message = error.code == 'otp_expired'
        ? 'That code has expired. Request a new one.'
        : error.code == 'over_email_send_rate_limit' ||
                error.code == 'over_sms_send_rate_limit'
            ? 'Too many codes requested. Wait before trying again.'
            : error.message;
    return AuthFailure(
        message, error.code ?? error.statusCode?.toString(), error);
  }
}
