import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  Failure? failure;
  try {
    final deleteResult = await ref.read(chatRepositoryProvider).deleteAllData();
    failure = deleteResult.failureOrNull;
  } catch (error) {
    failure = mapError(error);
  }

  try {
    await ref.read(userProfileProvider.notifier).clear();
  } catch (error) {
    failure ??= mapError(error);
  }
  try {
    await ref.read(appSettingsProvider.notifier).reset();
  } catch (error) {
    failure ??= mapError(error);
  }
  try {
    final preferences = await SharedPreferences.getInstance();
    final accountScopedKeys = preferences
        .getKeys()
        .where(
          (key) =>
              key.startsWith('chat.draft.') ||
              key == 'chat.lastOpenedId' ||
              key == 'chatList.filter' ||
              key == 'chatList.scrollOffset' ||
              key == 'search.query' ||
              key == 'search.filter',
        )
        .toList(growable: false);
    for (final key in accountScopedKeys) {
      await preferences.remove(key);
    }
  } catch (error) {
    failure ??= mapError(error);
  }

  try {
    await KeyStore().clearAll();
  } catch (error) {
    failure ??= mapError(error);
  }

  PaintingBinding.instance.imageCache.clear();
  PaintingBinding.instance.imageCache.clearLiveImages();
  return failure;
}
