import '../../../../core/errors/result.dart';

abstract class AuthRepository {
  Future<Result<void>> sendOtp(String phone);
  Future<Result<String>> verifyOtp(String phone, String code);
  Future<Result<void>> completeProfile(String displayName);
}
