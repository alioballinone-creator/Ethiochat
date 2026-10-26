import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/ethio_app_theme.dart';
import 'core/router/app_router.dart';

class EthioChatApp extends ConsumerWidget {
  const EthioChatApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = AppRouter.createRouter();
    return MaterialApp.router(
      title: 'EthioChat',
      theme: EthioAppTheme.lightTheme,
      darkTheme: EthioAppTheme.darkTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
