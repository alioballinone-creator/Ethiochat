import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        context.go('/welcome');
      }
    });
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
            EthioWordmark(
              size: 28,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
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
