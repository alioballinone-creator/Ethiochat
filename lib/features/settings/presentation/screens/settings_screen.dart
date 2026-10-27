import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/feature_flags.dart';
import '../../../../core/design/design.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../profile/application/profile_controller.dart';

/// Settings — grouped cards on the cream wallpaper.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  Future<void> _pickAppearance() async {
    final settings = ref.read(appSettingsProvider);
    final choice = await showModalBottomSheet<ThemeMode>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in const [
              (ThemeMode.system, 'System', 'Follow your device'),
              (ThemeMode.light, 'Light', 'Cream and gold'),
              (ThemeMode.dark, 'Dark', 'Low-light friendly'),
            ])
              ListTile(
                title: Text(entry.$2),
                subtitle: Text(entry.$3),
                trailing: settings.themeMode == entry.$1
                    ? const Icon(
                        Icons.check_rounded,
                        color: EthioColors.goldDeep,
                      )
                    : null,
                onTap: () => Navigator.pop(sheetContext, entry.$1),
              ),
            const SizedBox(height: Sp.x2),
          ],
        ),
      ),
    );
    if (choice != null) {
      await ref.read(appSettingsProvider.notifier).setThemeMode(choice);
    }
  }

  Future<void> _pickLanguage() async {
    final settings = ref.read(appSettingsProvider);
    const languages = [
      (Locale('en'), 'English'),
      (Locale('am'), 'አማርኛ — Amharic'),
      (Locale('om'), 'Afaan Oromoo'),
      (Locale('so'), 'Soomaali'),
      (Locale('ti'), 'ትግርኛ — Tigrinya'),
    ];
    final choice = await showModalBottomSheet<Locale>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(Sp.x4),
              child: Text(
                'Choose language',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            for (final language in languages)
              ListTile(
                title: Text(language.$2),
                trailing:
                    settings.locale.languageCode == language.$1.languageCode
                        ? const Icon(
                            Icons.check_rounded,
                            color: EthioColors.goldDeep,
                          )
                        : null,
                onTap: () => Navigator.pop(sheetContext, language.$1),
              ),
            Padding(
              padding: Sp.screen.copyWith(top: Sp.x2),
              child: Text(
                'Some content is not translated yet. Menus and system dialogs '
                'use the selected language.',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: EthioPalette.of(context).textSecondary),
              ),
            ),
            const SizedBox(height: Sp.x2),
          ],
        ),
      ),
    );
    if (choice != null) {
      await ref.read(appSettingsProvider.notifier).setLocale(choice);
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'Your chats stay on this device. You can sign back in with your '
          'phone number.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Sign out',
              style: TextStyle(color: EthioColors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(userProfileProvider.notifier).clear();
    if (!mounted) return;
    context.go('/welcome');
  }

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);
    final text = Theme.of(context).textTheme;
    final settings = ref.watch(appSettingsProvider);
    final appearance = switch (settings.themeMode) {
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
      ThemeMode.system => 'Follows your system',
    };
    final language = switch (settings.locale.languageCode) {
      'am' => 'አማርኛ',
      'om' => 'Afaan Oromoo',
      'so' => 'Soomaali',
      'ti' => 'ትግርኛ',
      _ => 'English',
    };

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text('Settings', style: text.headlineMedium),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: Sp.screen.copyWith(top: Sp.x2, bottom: Sp.x8),
          children: [
            const EthioSectionLabel('App'),
            EthioSectionCard(
              children: [
                EthioNavRow(
                  icon: Icons.dark_mode_outlined,
                  title: 'Appearance',
                  subtitle: appearance,
                  onTap: _pickAppearance,
                ),
                EthioNavRow(
                  icon: Icons.language_rounded,
                  title: 'Language',
                  subtitle: language,
                  onTap: _pickLanguage,
                ),
                EthioNavRow(
                  icon: Icons.tips_and_updates_outlined,
                  title: 'Tips and tricks',
                  subtitle: 'Get the most out of EthioChat',
                  onTap: () => context.push('/onboarding/tips'),
                  last: true,
                ),
              ],
            ),
            const EthioSectionLabel('Account'),
            EthioSectionCard(
              children: [
                EthioNavRow(
                  icon: Icons.person_outline_rounded,
                  title: 'Profile',
                  subtitle: 'Name, photo, about',
                  onTap: () => context.push('/me/profile'),
                ),
                EthioNavRow(
                  icon: Icons.qr_code_rounded,
                  title: 'My QR code',
                  subtitle: 'Let friends add you',
                  onTap: () => context.push('/me/qr'),
                ),
                EthioNavRow(
                  icon: Icons.verified_user_outlined,
                  title: 'Account and security',
                  subtitle: 'Two-step verification and devices',
                  onTap: () => context.push('/me/settings/account'),
                ),
                EthioNavRow(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy and security',
                  subtitle: 'Blocked contacts, read receipts',
                  onTap: () => context.push('/me/settings/privacy'),
                ),
                if (FeatureFlags.wallet)
                  EthioNavRow(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'Wallet and payments',
                    subtitle: 'PIN, linked accounts',
                    onTap: () => context.push('/wallet'),
                  ),
                EthioNavRow(
                  icon: Icons.block_outlined,
                  title: 'Blocked users',
                  subtitle: 'Review people you blocked',
                  onTap: () => context.push('/me/settings/privacy/blocked'),
                  last: true,
                ),
              ],
            ),
            const EthioSectionLabel('Notifications and storage'),
            EthioSectionCard(
              children: [
                EthioNavRow(
                  icon: Icons.notifications_none_rounded,
                  title: 'Notifications',
                  subtitle:
                      settings.messageNotifications ? 'On for messages' : 'Off',
                  onTap: () => context.push('/me/settings/notifications'),
                ),
                EthioNavRow(
                  icon: Icons.cloud_upload_outlined,
                  title: 'Chat backup',
                  subtitle: settings.backupEnabled
                      ? 'Daily automatic backup'
                      : 'Backup is off',
                  onTap: () => context.push('/me/settings/backup'),
                ),
                EthioNavRow(
                  icon: Icons.storage_outlined,
                  title: 'Storage manager',
                  subtitle: 'Media, cache and local data',
                  onTap: () => context.push('/me/settings/storage'),
                ),
                EthioNavRow(
                  icon: Icons.data_saver_on_rounded,
                  title: 'Data saver',
                  subtitle: settings.dataSaver ? 'On' : 'Off',
                  onTap: () => context.push('/me/settings/data-saver'),
                  last: true,
                ),
              ],
            ),
            const EthioSectionLabel('Support'),
            EthioSectionCard(
              children: [
                EthioNavRow(
                  icon: Icons.help_outline_rounded,
                  title: 'Help and support',
                  subtitle: 'FAQs and contact',
                  onTap: () => context.push('/me/settings/help'),
                ),
                EthioNavRow(
                  icon: Icons.info_outline_rounded,
                  title: 'About EthioChat',
                  subtitle: 'Version 0.1.0',
                  onTap: () => context.push('/me/settings/about'),
                  last: true,
                ),
              ],
            ),
            const SizedBox(height: Sp.x4),
            EthioButton(
              label: 'Sign out',
              kind: EthioButtonKind.danger,
              icon: Icons.logout_rounded,
              onPressed: _signOut,
            ),
            const SizedBox(height: Sp.x4),
            Center(
              child: Text(
                'Made in Addis Ababa 🇪🇹',
                style: text.labelSmall?.copyWith(color: pal.textTertiary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
