import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/demo/demo_content.dart';
import '../../../../core/design/design.dart';

class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text('Discover', style: text.headlineMedium),
        actions: [
          IconButton(
            tooltip: 'Search',
            icon: const Icon(Icons.search_rounded),
            onPressed: () => context.push('/search'),
          ),
          const SizedBox(width: Sp.x1),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: Sp.screen.copyWith(top: Sp.x4, bottom: Sp.x6),
          children: [
            _DiscoverItem(
              icon: Icons.photo_library_outlined,
              title: 'Moments',
              subtitle: 'What your friends are sharing',
              hasRedDot: true,
              onTap: () => context.push('/discover/moments'),
            ),
            _DiscoverItem(
              icon: Icons.wifi_tethering_outlined,
              title: 'Channels',
              subtitle: 'Follow news, faith, music and city life',
              onTap: () => context.push('/discover/channels'),
            ),
            _DiscoverItem(
              icon: Icons.verified_outlined,
              title: 'Official Accounts',
              subtitle: 'Banks, telecom and trusted newsrooms',
              onTap: () => context.push('/discover/official'),
            ),
            _DiscoverItem(
              icon: Icons.qr_code_scanner_rounded,
              title: 'Scan',
              subtitle: 'Add a friend or pay a merchant',
              onTap: () => context.push('/scan'),
            ),
            _DiscoverItem(
              icon: Icons.near_me_outlined,
              title: 'People nearby',
              subtitle: 'Meet people around you, safely',
              onTap: () => context.push('/discover/nearby'),
            ),
            const SizedBox(height: Sp.x5),
            Row(
              children: [
                Text('Mini Programs', style: text.titleMedium),
                const Spacer(),
                Text(
                  'No install needed',
                  style: text.labelSmall?.copyWith(color: pal.textTertiary),
                ),
              ],
            ),
            const SizedBox(height: Sp.x3),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 4,
              childAspectRatio: 0.78,
              children: [
                for (final program in DemoContent.miniPrograms)
                  EthioMiniAppTile(
                    label: program.name,
                    icon: program.icon,
                    color: program.color.withValues(alpha: 0.16),
                    onTap: () => context.push(
                      '/discover/mini/${program.id}',
                    ),
                  ),
              ],
            ),
            const SizedBox(height: Sp.x5),
            Container(
              padding: const EdgeInsets.all(Sp.x4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    EthioColors.gold.withValues(alpha: 0.3),
                    EthioColors.gold.withValues(alpha: 0.08),
                  ],
                ),
                borderRadius: Rad.r18,
                border: Border.all(
                  color: EthioColors.goldDeep.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    color: EthioColors.goldDeep,
                  ),
                  const SizedBox(width: Sp.x3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'EthioChat for business',
                          style: text.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Open a channel or mini program for your customers.',
                          style: text.bodySmall
                              ?.copyWith(color: pal.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Learn more',
                    onPressed: () => showAboutDialog(
                      context: context,
                      applicationName: 'EthioChat for business',
                      applicationVersion: 'Beta',
                      children: const [
                        Text(
                          'Business channels, verified accounts and mini '
                          'programs are reviewed by the EthioChat team. '
                          'Contact support from Settings to apply.',
                        ),
                      ],
                    ),
                    icon: const Icon(Icons.arrow_forward_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiscoverItem extends StatelessWidget {
  const _DiscoverItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.hasRedDot = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
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
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: pal.chip,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 22),
        ),
        title: Text(title, style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text(
          subtitle,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: pal.textSecondary),
        ),
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: Sp.x4, vertical: Sp.x1),
      ),
    );
  }
}
