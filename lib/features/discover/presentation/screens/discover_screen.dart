import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/design.dart';

class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text(
          'Discover',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: Sp.screen.copyWith(top: Sp.x4, bottom: 80),
          children: [
            _DiscoverItem(
              icon: Icons.photo_library_outlined,
              title: 'Moments',
              hasRedDot: true,
              onTap: () => context.push('/discover/moments'),
            ),
            _DiscoverItem(
              icon: Icons.wifi_tethering_outlined,
              title: 'Channels',
              onTap: () {},
            ),
            _DiscoverItem(
              icon: Icons.verified_outlined,
              title: 'Official Accounts',
              onTap: () {},
            ),
            _DiscoverItem(
              icon: Icons.qr_code_scanner_rounded,
              title: 'Scan',
              onTap: () {},
            ),
            _DiscoverItem(
              icon: Icons.near_me_outlined,
              title: 'People nearby',
              onTap: () {},
            ),
            const SizedBox(height: Sp.x4),
            Text(
              'Mini Programs',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: Sp.x3),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 4,
              children: const [
                _MiniProgramItem(label: 'Shop'),
                _MiniProgramItem(label: 'Ride'),
                _MiniProgramItem(label: 'Food'),
                _MiniProgramItem(label: 'Bills'),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: EthioBottomNav(
        index: 2,
        onTap: (i) {
          if (i == 0) Navigator.pushNamed(context, '/chats');
          if (i == 1) Navigator.pushNamed(context, '/contacts');
          if (i == 3) Navigator.pushNamed(context, '/me');
        },
      ),
    );
  }
}

class _DiscoverItem extends StatelessWidget {
  const _DiscoverItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.hasRedDot = false,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool hasRedDot;

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);
    
    return Container(
      margin: const EdgeInsets.only(bottom: Sp.x2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: Rad.r14,
        border: Border.all(color: pal.line),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: pal.chip,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 22),
        ),
        title: Text(title, style: Theme.of(context).textTheme.titleMedium),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasRedDot)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: EthioColors.danger,
                  shape: BoxShape.circle,
                ),
              ),
            const SizedBox(width: Sp.x2),
            const Icon(Icons.chevron_right_rounded, size: 22),
          ],
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: Sp.x4, vertical: Sp.x1),
      ),
    );
  }
}

class _MiniProgramItem extends StatelessWidget {
  const _MiniProgramItem({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: pal.line),
          ),
          child: const Icon(Icons.apps_rounded),
        ),
        const SizedBox(height: Sp.x2),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
