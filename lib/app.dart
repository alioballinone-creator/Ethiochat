import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/design/design.dart';
import 'core/router/app_router.dart';

class EthioChatApp extends ConsumerWidget {
  const EthioChatApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = AppRouter.createRouter();
    final brightness = MediaQuery.platformBrightnessOf(context);
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
      theme: buildEthioTheme(Brightness.light),
      darkTheme: buildEthioTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
