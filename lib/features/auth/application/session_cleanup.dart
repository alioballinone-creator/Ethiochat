import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/crypto/key_store.dart';
import '../../../core/errors/failure.dart';
import '../../../core/settings/app_settings.dart';
import '../../chats/application/chat_providers.dart';
import '../../profile/application/profile_controller.dart';

/// Removes account-scoped data from this device.
///
/// The next account must never inherit another user's cached chats, profile,
/// preferences, or encryption keys. Remote deletion is performed separately by
/// the server-side account deletion function.
Future<Failure?> clearLocalAccountState(WidgetRef ref) async {
  final deleteResult = await ref.read(chatRepositoryProvider).deleteAllData();
  final failure = deleteResult.failureOrNull;
  if (failure != null) return failure;

  await ref.read(userProfileProvider.notifier).clear();
  await ref.read(appSettingsProvider.notifier).reset();

  try {
    await KeyStore().clearAll();
  } catch (_) {
    // Secure storage may be unavailable on a locked device. The database and
    // Supabase session have already been cleared, so do not leave stale UI.
  }

  PaintingBinding.instance.imageCache.clear();
  PaintingBinding.instance.imageCache.clearLiveImages();
  return null;
}
