import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/presentation/screens/phone_entry_screen.dart';
import 'features/shell/presentation/app_shell.dart';
import 'l10n/app_localizations.dart';

class EthioChatApp extends ConsumerWidget {
  const EthioChatApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = GoRouter(
      initialLocation: '/chats',
      routes: [
        GoRoute(
          path: '/auth/phone',
          builder: (context, state) => const PhoneEntryScreen(),
        ),
        GoRoute(
          path: '/chats',
          builder: (context, state) => const AppShell(),
        ),
      ],
    );

    return MaterialApp.router(
      title: 'EthioChat',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
