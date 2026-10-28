import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/feature_flags.dart';
import '../../../../core/design/design.dart';
import '../../../auth/application/auth_providers.dart';
import '../../../profile/application/profile_controller.dart';

class AccountSecurityScreen extends ConsumerWidget {
  const AccountSecurityScreen({super.key});

  Future<void> _endSessions(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out other devices?'),
        content: const Text(
          'Any other phones or tablets signed into this account will be signed '
          'out immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final result =
        await ref.read(authRepositoryProvider).signOut(othersOnly: true);
    if (!context.mounted) return;
    final failure = result.failureOrNull;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failure == null
              ? 'All other devices were signed out.'
              : 'Could not sign out other devices: ${failure.message}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pal = EthioPalette.of(context);
    final text = Theme.of(context).textTheme;
    final profile = ref.watch(userProfileProvider);
    final platform = defaultTargetPlatform == TargetPlatform.iOS
        ? 'iOS'
        : defaultTargetPlatform == TargetPlatform.android
            ? 'Android'
            : 'this platform';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text('Account and security', style: text.headlineMedium),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: Sp.screen.copyWith(top: Sp.x2, bottom: Sp.x8),
          children: [
            EthioSectionCard(
              children: [
                EthioNavRow(
                  icon: Icons.phone_iphone_rounded,
                  title: 'Phone number',
                  subtitle:
                      profile.phone.isEmpty ? 'Not linked yet' : profile.phone,
                ),
                EthioNavRow(
                  icon: Icons.badge_outlined,
                  title: 'Ethio ID',
                  subtitle: profile.ethioId,
                  onTap: () => context.push('/me/qr'),
                  last: true,
                ),
              ],
            ),
            const EthioSectionLabel('Sign in'),
            EthioSectionCard(
              children: [
                EthioSwitchRow(
                  icon: Icons.verified_user_outlined,
                  title: 'Phone verification',
                  subtitle: 'Required for every sign-in',
                  value: true,
                  onChanged: null,
                  last: true,
                ),
              ],
            ),
            const EthioSectionLabel('Devices'),
            EthioSectionCard(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: Sp.x4,
                    vertical: Sp.x1,
                  ),
                  leading: const EthioIconTile(
                    icon: Icons.smartphone_rounded,
                    foreground: EthioColors.success,
                  ),
                  title: Text('This device', style: text.titleMedium),
                  subtitle: Text(
                    'Active now · $platform',
                    style: text.labelSmall?.copyWith(color: pal.textSecondary),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Sp.x2,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: EthioColors.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Current',
                      style:
                          text.labelSmall?.copyWith(color: EthioColors.success),
                    ),
                  ),
                ),
                EthioNavRow(
                  icon: Icons.devices_other_rounded,
                  title: 'Sign out other devices',
                  subtitle: 'End every other active session',
                  onTap: () => _endSessions(context, ref),
                  last: true,
                ),
              ],
            ),
            const EthioSectionLabel('Safety'),
            EthioSectionCard(
              children: [
                EthioNavRow(
                  icon: Icons.password_rounded,
                  title: 'Change account PIN',
                  subtitle: FeatureFlags.wallet
                      ? 'Used for wallet payments'
                      : 'Wallet is disabled in this release',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          FeatureFlags.wallet
                              ? 'Open Wallet → Settings to change your PIN.'
                              : 'Wallet payments are disabled in this release.',
                        ),
                      ),
                    );
                  },
                ),
                EthioNavRow(
                  icon: Icons.security_rounded,
                  title: 'Security checkup',
                  subtitle: 'Review your account protection',
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('Security checkup'),
                      content: const Text(
                        'Your account signs in with a phone one-time code. '
                        'Review your privacy settings and sign out unused '
                        'devices regularly.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  ),
                ),
                EthioNavRow(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy settings',
                  onTap: () => context.push('/me/settings/privacy'),
                  last: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
