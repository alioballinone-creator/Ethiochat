import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/feature_flags.dart';
import '../../../../core/design/design.dart';
import '../../../profile/application/profile_controller.dart';

class MeScreen extends ConsumerWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pal = EthioPalette.of(context);
    final profile = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text(
          'Me',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: Sp.screen.copyWith(top: Sp.x4, bottom: 80),
          children: [
            Material(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: Rad.r18,
              child: InkWell(
                onTap: () => context.push('/me/qr'),
                borderRadius: Rad.r18,
                child: Container(
                  padding: const EdgeInsets.all(Sp.x4),
                  decoration: BoxDecoration(
                    borderRadius: Rad.r18,
                    border: Border.all(color: pal.line),
                  ),
                  child: Row(
                    children: [
                      EthioAvatar(
                        name: profile.name,
                        imageUrl: profile.avatarPath,
                        size: 64,
                      ),
                      const SizedBox(width: Sp.x4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile.name,
                              style: Theme.of(context).textTheme.titleLarge,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: Sp.x1),
                            Text(
                              'Ethio ID: ${profile.ethioId}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: pal.textSecondary,
                                  ),
                            ),
                            if (profile.bio.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                profile.bio,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(color: pal.textSecondary),
                              ),
                            ],
                            const SizedBox(height: Sp.x2),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: Sp.x2,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: pal.chip,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.place_outlined,
                                    size: 12,
                                    color: pal.textSecondary,
                                  ),
                                  const SizedBox(width: 2),
                                  Flexible(
                                    child: Text(
                                      profile.phone.isEmpty
                                          ? 'Addis Ababa'
                                          : profile.phone,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: pal.textSecondary,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.qr_code_rounded),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: Sp.x4),
            if (FeatureFlags.wallet) ...[
              _MeItem(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Wallet',
                onTap: () => context.push('/wallet'),
              ),
              _MeItem(
                icon: Icons.card_giftcard_outlined,
                title: 'Red packets',
                onTap: () => context.push('/wallet'),
              ),
            ],
            _MeItem(
              icon: Icons.favorite_border_rounded,
              title: 'Favorites',
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content:
                      Text('No favorites yet — starred messages show here.'),
                ),
              ),
            ),
            _MeItem(
              icon: Icons.shield_outlined,
              title: 'Privacy and security',
              onTap: () => context.push('/me/settings'),
            ),
            _MeItem(
              icon: Icons.settings_outlined,
              title: 'Settings',
              onTap: () => context.push('/me/settings'),
            ),
          ],
        ),
      ),
      bottomNavigationBar: EthioBottomNav(
        index: 3,
        onTap: (i) {
          if (i == 0) context.go('/chats');
          if (i == 1) context.go('/contacts');
          if (i == 2) context.go('/discover');
        },
      ),
    );
  }
}

class _MeItem extends StatelessWidget {
  const _MeItem({required this.icon, required this.title, this.onTap});

  final IconData icon;
  final String title;
  final VoidCallback? onTap;

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
        trailing: const Icon(Icons.chevron_right_rounded, size: 22),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: Sp.x4, vertical: Sp.x1),
      ),
    );
  }
}
