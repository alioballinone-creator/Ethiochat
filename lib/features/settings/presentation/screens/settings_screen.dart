import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/feature_flags.dart';
import '../../../../core/design/design.dart';
import '../../../../core/settings/app_settings.dart';

/// Settings — grouped cards on the cream wallpaper.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _messageNotifications = true;
  bool _groupNotifications = true;
  bool _readReceipts = true;
  bool _showLastSeen = true;
  bool _mediaAutoDownload = false;

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
    final choice = await showModalBottomSheet<Locale>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('English'),
              trailing: settings.locale.languageCode == 'en'
                  ? const Icon(Icons.check_rounded, color: EthioColors.goldDeep)
                  : null,
              onTap: () => Navigator.pop(sheetContext, const Locale('en')),
            ),
            ListTile(
              title: const Text('አማርኛ — Amharic'),
              trailing: settings.locale.languageCode == 'am'
                  ? const Icon(Icons.check_rounded, color: EthioColors.goldDeep)
                  : null,
              onTap: () => Navigator.pop(sheetContext, const Locale('am')),
            ),
            for (final coming in const [
              'Afaan Oromoo',
              'Soomaali',
              'ትግርኛ — Tigrinya',
            ])
              ListTile(
                enabled: false,
                title: Text(coming),
                trailing: const Text('Soon'),
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
    context.go('/welcome');
  }

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'EthioChat',
      applicationVersion: '0.1.0',
      applicationLegalese: 'Made in Addis Ababa 🇪🇹\n'
          'Local-first messaging for Ethiopia and the Horn of Africa.',
      children: [
        const SizedBox(height: Sp.x2),
        const Text(
          'Chats are stored on your device with Drift and queued for delivery '
          'when you are back online.',
        ),
      ],
    );
  }

  void _feedback(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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
    final language = settings.locale.languageCode == 'am' ? 'አማርኛ' : 'English';

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
            _SectionLabel('Account'),
            _Card(
              children: [
                _NavRow(
                  icon: Icons.person_outline_rounded,
                  title: 'Profile',
                  subtitle: 'Name, photo, about',
                  onTap: () => context.push('/auth/profile'),
                ),
                _NavRow(
                  icon: Icons.qr_code_rounded,
                  title: 'My QR code',
                  subtitle: 'Let friends add you',
                  onTap: () => context.push('/me/qr'),
                ),
                _NavRow(
                  icon: Icons.verified_user_outlined,
                  title: 'Privacy and security',
                  subtitle: 'Blocked contacts, read receipts',
                  onTap: () => _feedback(
                    'Read receipts and last seen are below. Chat-level controls '
                    'live in Chat info.',
                  ),
                  last: !FeatureFlags.wallet,
                ),
                if (FeatureFlags.wallet)
                  _NavRow(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'Wallet and payments',
                    subtitle: 'PIN, linked accounts',
                    onTap: () => context.push('/wallet'),
                    last: true,
                  ),
              ],
            ),
            _SectionLabel('Notifications'),
            _Card(
              children: [
                _SwitchRow(
                  icon: Icons.notifications_none_rounded,
                  title: 'Message notifications',
                  value: _messageNotifications,
                  onChanged: (v) => setState(() => _messageNotifications = v),
                ),
                _SwitchRow(
                  icon: Icons.groups_outlined,
                  title: 'Group notifications',
                  value: _groupNotifications,
                  onChanged: (v) => setState(() => _groupNotifications = v),
                ),
                _SwitchRow(
                  icon: Icons.download_outlined,
                  title: 'Auto-download media',
                  subtitle: 'Wi-Fi only by default',
                  value: _mediaAutoDownload,
                  onChanged: (v) => setState(() => _mediaAutoDownload = v),
                  last: true,
                ),
              ],
            ),
            _SectionLabel('Privacy'),
            _Card(
              children: [
                _SwitchRow(
                  icon: Icons.done_all_rounded,
                  title: 'Read receipts',
                  value: _readReceipts,
                  onChanged: (v) => setState(() => _readReceipts = v),
                ),
                _SwitchRow(
                  icon: Icons.visibility_outlined,
                  title: 'Show last seen',
                  value: _showLastSeen,
                  onChanged: (v) => setState(() => _showLastSeen = v),
                  last: true,
                ),
              ],
            ),
            _SectionLabel('App'),
            _Card(
              children: [
                _NavRow(
                  icon: Icons.dark_mode_outlined,
                  title: 'Appearance',
                  subtitle: appearance,
                  onTap: _pickAppearance,
                ),
                _NavRow(
                  icon: Icons.language_rounded,
                  title: 'Language',
                  subtitle: language,
                  onTap: _pickLanguage,
                ),
                _NavRow(
                  icon: Icons.storage_outlined,
                  title: 'Storage and data',
                  subtitle: 'Chats stored on this device',
                  onTap: () => _feedback(
                    'Media is cached on device. Database size grows with your '
                    'chat history.',
                  ),
                ),
                _NavRow(
                  icon: Icons.info_outline_rounded,
                  title: 'About EthioChat',
                  subtitle: 'Version 0.1.0',
                  onTap: _showAbout,
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.x1, Sp.x4, Sp.x1, Sp.x2),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: EthioPalette.of(context).textTertiary,
              letterSpacing: 0.8,
            ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: Rad.r18,
        border: Border.all(color: pal.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.last = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);
    final text = Theme.of(context).textTheme;

    return Column(
      children: [
        ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: Sp.x4,
            vertical: Sp.x1,
          ),
          leading: _IconTile(icon: icon),
          title: Text(title, style: text.titleMedium),
          subtitle: subtitle == null
              ? null
              : Text(
                  subtitle!,
                  style: text.labelSmall?.copyWith(color: pal.textSecondary),
                ),
          trailing: Icon(
            Icons.chevron_right_rounded,
            color: pal.textTertiary,
          ),
        ),
        if (!last)
          Divider(
            height: 1,
            indent: Sp.x4 + 44 + Sp.x3,
            endIndent: Sp.x4,
            color: pal.line,
          ),
      ],
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.last = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);
    final text = Theme.of(context).textTheme;

    return Column(
      children: [
        SwitchListTile.adaptive(
          value: value,
          onChanged: onChanged,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: Sp.x4,
            vertical: Sp.x1,
          ),
          secondary: _IconTile(icon: icon),
          title: Text(title, style: text.titleMedium),
          subtitle: subtitle == null
              ? null
              : Text(
                  subtitle!,
                  style: text.labelSmall?.copyWith(color: pal.textSecondary),
                ),
          activeTrackColor: EthioColors.gold,
        ),
        if (!last)
          Divider(
            height: 1,
            indent: Sp.x4 + 44 + Sp.x3,
            endIndent: Sp.x4,
            color: pal.line,
          ),
      ],
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: pal.chip,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 22),
    );
  }
}
