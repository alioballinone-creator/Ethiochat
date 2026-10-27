import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User-selectable app preferences.
@immutable
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.locale = const Locale('en'),
    this.messageNotifications = true,
    this.groupNotifications = true,
    this.readReceipts = true,
    this.showLastSeen = true,
    this.autoDownloadMedia = false,
    this.dataSaver = true,
    this.backupEnabled = true,
    this.backupVideos = false,
    this.twoStepVerification = false,
    this.lastSeenAudience = 'Contacts',
    this.profilePhotoAudience = 'Everyone',
    this.groupAddAudience = 'Contacts',
  });

  final ThemeMode themeMode;
  final Locale locale;
  final bool messageNotifications;
  final bool groupNotifications;
  final bool readReceipts;
  final bool showLastSeen;
  final bool autoDownloadMedia;
  final bool dataSaver;
  final bool backupEnabled;
  final bool backupVideos;
  final bool twoStepVerification;
  final String lastSeenAudience;
  final String profilePhotoAudience;
  final String groupAddAudience;

  AppSettings copyWith({
    ThemeMode? themeMode,
    Locale? locale,
    bool? messageNotifications,
    bool? groupNotifications,
    bool? readReceipts,
    bool? showLastSeen,
    bool? autoDownloadMedia,
    bool? dataSaver,
    bool? backupEnabled,
    bool? backupVideos,
    bool? twoStepVerification,
    String? lastSeenAudience,
    String? profilePhotoAudience,
    String? groupAddAudience,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      locale: locale ?? this.locale,
      messageNotifications: messageNotifications ?? this.messageNotifications,
      groupNotifications: groupNotifications ?? this.groupNotifications,
      readReceipts: readReceipts ?? this.readReceipts,
      showLastSeen: showLastSeen ?? this.showLastSeen,
      autoDownloadMedia: autoDownloadMedia ?? this.autoDownloadMedia,
      dataSaver: dataSaver ?? this.dataSaver,
      backupEnabled: backupEnabled ?? this.backupEnabled,
      backupVideos: backupVideos ?? this.backupVideos,
      twoStepVerification: twoStepVerification ?? this.twoStepVerification,
      lastSeenAudience: lastSeenAudience ?? this.lastSeenAudience,
      profilePhotoAudience: profilePhotoAudience ?? this.profilePhotoAudience,
      groupAddAudience: groupAddAudience ?? this.groupAddAudience,
    );
  }
}

class AppSettingsController extends StateNotifier<AppSettings> {
  AppSettingsController() : super(const AppSettings()) {
    _restore();
  }

  static const _themeKey = 'settings.themeMode';
  static const _localeKey = 'settings.locale';
  static const _messageNotificationsKey = 'settings.messageNotifications';
  static const _groupNotificationsKey = 'settings.groupNotifications';
  static const _readReceiptsKey = 'settings.readReceipts';
  static const _showLastSeenKey = 'settings.showLastSeen';
  static const _autoDownloadKey = 'settings.autoDownloadMedia';
  static const _dataSaverKey = 'settings.dataSaver';
  static const _backupEnabledKey = 'settings.backupEnabled';
  static const _backupVideosKey = 'settings.backupVideos';
  static const _twoStepKey = 'settings.twoStepVerification';
  static const _lastSeenAudienceKey = 'settings.lastSeenAudience';
  static const _photoAudienceKey = 'settings.profilePhotoAudience';
  static const _groupAddAudienceKey = 'settings.groupAddAudience';

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeName = prefs.getString(_themeKey);
      final localeCode = prefs.getString(_localeKey);
      state = AppSettings(
        themeMode: ThemeMode.values.firstWhere(
          (m) => m.name == themeName,
          orElse: () => state.themeMode,
        ),
        locale: localeCode == null ? state.locale : Locale(localeCode),
        messageNotifications: prefs.getBool(_messageNotificationsKey) ??
            state.messageNotifications,
        groupNotifications:
            prefs.getBool(_groupNotificationsKey) ?? state.groupNotifications,
        readReceipts: prefs.getBool(_readReceiptsKey) ?? state.readReceipts,
        showLastSeen: prefs.getBool(_showLastSeenKey) ?? state.showLastSeen,
        autoDownloadMedia:
            prefs.getBool(_autoDownloadKey) ?? state.autoDownloadMedia,
        dataSaver: prefs.getBool(_dataSaverKey) ?? state.dataSaver,
        backupEnabled: prefs.getBool(_backupEnabledKey) ?? state.backupEnabled,
        backupVideos: prefs.getBool(_backupVideosKey) ?? state.backupVideos,
        twoStepVerification:
            prefs.getBool(_twoStepKey) ?? state.twoStepVerification,
        lastSeenAudience:
            prefs.getString(_lastSeenAudienceKey) ?? state.lastSeenAudience,
        profilePhotoAudience:
            prefs.getString(_photoAudienceKey) ?? state.profilePhotoAudience,
        groupAddAudience:
            prefs.getString(_groupAddAudienceKey) ?? state.groupAddAudience,
      );
    } catch (_) {
      // Preferences are best-effort; defaults are already applied.
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _persist((prefs) => prefs.setString(_themeKey, mode.name));
  }

  Future<void> setLocale(Locale locale) async {
    state = state.copyWith(locale: locale);
    await _persist((prefs) => prefs.setString(_localeKey, locale.languageCode));
  }

  Future<void> reset() async {
    state = const AppSettings();
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in <String>[
        _themeKey,
        _localeKey,
        _messageNotificationsKey,
        _groupNotificationsKey,
        _readReceiptsKey,
        _showLastSeenKey,
        _autoDownloadKey,
        _dataSaverKey,
        _backupEnabledKey,
        _backupVideosKey,
        _twoStepKey,
        _lastSeenAudienceKey,
        _photoAudienceKey,
        _groupAddAudienceKey,
      ]) {
        await prefs.remove(key);
      }
    } catch (_) {
      // Defaults are already applied in memory.
    }
  }

  Future<void> update(AppSettings next) async {
    state = next;
    await _persist((prefs) async {
      await prefs.setString(_themeKey, next.themeMode.name);
      await prefs.setString(_localeKey, next.locale.languageCode);
      await prefs.setBool(_messageNotificationsKey, next.messageNotifications);
      await prefs.setBool(_groupNotificationsKey, next.groupNotifications);
      await prefs.setBool(_readReceiptsKey, next.readReceipts);
      await prefs.setBool(_showLastSeenKey, next.showLastSeen);
      await prefs.setBool(_autoDownloadKey, next.autoDownloadMedia);
      await prefs.setBool(_dataSaverKey, next.dataSaver);
      await prefs.setBool(_backupEnabledKey, next.backupEnabled);
      await prefs.setBool(_backupVideosKey, next.backupVideos);
      await prefs.setBool(_twoStepKey, next.twoStepVerification);
      await prefs.setString(_lastSeenAudienceKey, next.lastSeenAudience);
      await prefs.setString(_photoAudienceKey, next.profilePhotoAudience);
      await prefs.setString(_groupAddAudienceKey, next.groupAddAudience);
    });
  }

  Future<void> _persist(Future<void> Function(SharedPreferences) write) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await write(prefs);
    } catch (_) {
      // Ignore persistence failures (e.g. platform unavailable in tests).
    }
  }
}

final appSettingsProvider =
    StateNotifierProvider<AppSettingsController, AppSettings>(
  (ref) => AppSettingsController(),
);
