import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User-selectable app preferences.
@immutable
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.locale = const Locale('en'),
  });

  final ThemeMode themeMode;
  final Locale locale;

  AppSettings copyWith({ThemeMode? themeMode, Locale? locale}) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      locale: locale ?? this.locale,
    );
  }
}

class AppSettingsController extends StateNotifier<AppSettings> {
  AppSettingsController() : super(const AppSettings()) {
    _restore();
  }

  static const _themeKey = 'settings.themeMode';
  static const _localeKey = 'settings.locale';

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
