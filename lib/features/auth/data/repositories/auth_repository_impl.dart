import 'package:ethiochat/core/errors/failure.dart';
import 'package:ethiochat/core/errors/result.dart';
import 'package:ethiochat/core/utils/phone.dart';

abstract class AuthRepository {
  Future<Result<void>> sendOtp(String phone);
  Future<Result<String>> verifyOtp(String phone, String code);
  Future<Result<void>> completeProfile(String displayName);
}

class AuthRepositoryImpl implements AuthRepository {
  @override
  Future<Result<void>> sendOtp(String phone) async {
    final normalized = PhoneUtils.normalize(phone);
    if (normalized == null) {
      return const Result.failure(ValidationFailure('Invalid phone number'));
    }
    return const Result.success(null);
  }

  @override
  Future<Result<String>> verifyOtp(String phone, String code) async {
    return const Result.success('token');
  }

  @override
  Future<Result<void>> completeProfile(String displayName) async {
    if (displayName.trim().isEmpty) {
      return const Result.failure(ValidationFailure('Display name required'));
    }
    return const Result.success(null);
  }
}
