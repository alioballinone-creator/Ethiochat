import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The signed-in user's profile. Stored locally; ready to sync with Supabase
/// once a backend is configured.
@immutable
class UserProfile {
  const UserProfile({
    this.name = 'EthioChat user',
    this.bio = '',
    this.phone = '',
    this.ethioId = 'EC-123456',
    this.avatarPath,
  });

  final String name;
  final String bio;
  final String phone;
  final String ethioId;
  final String? avatarPath;

  bool get isComplete => name.trim().length >= 2 && name != 'EthioChat user';

  UserProfile copyWith({
    String? name,
    String? bio,
    String? phone,
    String? ethioId,
    String? avatarPath,
  }) {
    return UserProfile(
      name: name ?? this.name,
      bio: bio ?? this.bio,
      phone: phone ?? this.phone,
      ethioId: ethioId ?? this.ethioId,
      avatarPath: avatarPath ?? this.avatarPath,
    );
  }
}

class ProfileController extends StateNotifier<UserProfile> {
  ProfileController() : super(const UserProfile()) {
    _restore();
  }

  static const _nameKey = 'profile.name';
  static const _bioKey = 'profile.bio';
  static const _phoneKey = 'profile.phone';
  static const _ethioIdKey = 'profile.ethioId';
  static const _avatarKey = 'profile.avatarPath';

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString(_nameKey);
      if (name == null) return;
      state = UserProfile(
        name: name,
        bio: prefs.getString(_bioKey) ?? '',
        phone: prefs.getString(_phoneKey) ?? '',
        ethioId: prefs.getString(_ethioIdKey) ?? 'EC-123456',
        avatarPath: prefs.getString(_avatarKey),
      );
    } catch (_) {
      // Defaults are fine when storage is unavailable.
    }
  }

  Future<void> save({
    required String name,
    String? bio,
    String? phone,
    String? avatarPath,
  }) async {
    state = state.copyWith(
      name: name.trim(),
      bio: bio?.trim(),
      phone: phone,
      avatarPath: avatarPath,
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_nameKey, state.name);
      await prefs.setString(_bioKey, state.bio);
      if (state.phone.isNotEmpty) {
        await prefs.setString(_phoneKey, state.phone);
      }
      await prefs.setString(_ethioIdKey, state.ethioId);
      if (state.avatarPath != null) {
        await prefs.setString(_avatarKey, state.avatarPath!);
      }
    } catch (_) {
      // Keep the in-memory value even when persistence fails.
    }
  }
}

final userProfileProvider =
    StateNotifierProvider<ProfileController, UserProfile>(
  (ref) => ProfileController(),
);
