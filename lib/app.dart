import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/design/design.dart';
import 'core/router/app_router.dart';
import 'core/settings/app_settings.dart';

class EthioChatApp extends ConsumerStatefulWidget {
  const EthioChatApp({super.key});

  @override
  ConsumerState<EthioChatApp> createState() => _EthioChatAppState();
}

class _EthioChatAppState extends ConsumerState<EthioChatApp> {
  late final GoRouter _router = AppRouter.createRouter();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final platformBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final brightness = switch (settings.themeMode) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.system => platformBrightness,
    };
    SystemChrome.setSystemUIOverlayStyle(brightness == Brightness.dark
        ? SystemUiOverlayStyle.light.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarDividerColor: Colors.transparent,
          )
        : SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarDividerColor: Colors.transparent,
          ));
    return MaterialApp.router(
      title: 'EthioChat',
      debugShowCheckedModeBanner: false,
      theme: buildEthioTheme(Brightness.light),
      darkTheme: buildEthioTheme(Brightness.dark),
      themeMode: settings.themeMode,
      locale: settings.locale,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('am')],
      routerConfig: _router,
    );
  }
}
