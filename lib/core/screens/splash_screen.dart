import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../design/design.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(_openInitialDestination());
  }

  Future<void> _openInitialDestination() async {
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastChatId = prefs.getString('chat.lastOpenedId');
      if (mounted && lastChatId != null && lastChatId.isNotEmpty) {
        context.go('/chats/$lastChatId');
        return;
      }
    } catch (_) {
      // Continue to the welcome screen if saved navigation is unavailable.
    }
    if (mounted) context.go('/welcome');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const EthioMark(size: 100),
            const SizedBox(height: Sp.x4),
            EthioWordmark(size: 28),
            const SizedBox(height: Sp.x2),
            Text(
              'Your world, one app.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: EthioPalette.of(context).textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
