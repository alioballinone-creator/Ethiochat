import 'package:flutter/material.dart';

import '../design/design.dart';

class MaintenanceScreen extends StatelessWidget {
  const MaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final pal = EthioPalette.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: Sp.screen,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const EthioIconTile(
                  icon: Icons.construction_outlined,
                  background: EthioColors.gold,
                  size: 60,
                ),
                const SizedBox(height: Sp.x4),
                Text('We will be back shortly', style: text.headlineMedium),
                const SizedBox(height: Sp.x2),
                Text(
                  'EthioChat is temporarily unavailable while we make updates.',
                  textAlign: TextAlign.center,
                  style: text.bodyMedium?.copyWith(color: pal.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
