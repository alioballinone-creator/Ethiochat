import '../../../../core/errors/result.dart';

/// A profile row returned by the authenticated Supabase backend.
class RemoteProfile {
  const RemoteProfile({
    required this.displayName,
    required this.bio,
    this.avatarUrl,
    this.ethioId,
  });

  final String displayName;
  final String bio;
  final String? avatarUrl;
  final String? ethioId;

  bool get isComplete =>
      displayName.trim().length >= 2 && displayName != 'EthioChat user';
}

abstract class AuthRepository {
  Future<Result<void>> sendOtp(String phone);
  Future<Result<String>> verifyOtp(String phone, String code);
  Future<Result<RemoteProfile?>> fetchProfile();
  Future<Result<void>> completeProfile({
    required String displayName,
    String? bio,
    String? phone,
    String? avatarPath,
  });
  Future<Result<void>> signOut({bool othersOnly = false});
}
