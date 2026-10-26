import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/feature_flags.dart';
import '../../../../core/design/design.dart';

/// Settings — grouped cards on the cream wallpaper.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _messageNotifications = true;
  bool _groupNotifications = true;
  bool _readReceipts = true;
  bool _showLastSeen = true;
  bool _mediaAutoDownload = false;

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);
    final text = Theme.of(context).textTheme;

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
                  onTap: () {},
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
                  subtitle: 'Follows your system',
                  onTap: () {},
                ),
                _NavRow(
                  icon: Icons.language_rounded,
                  title: 'Language',
                  subtitle: 'English · አማርኛ',
                  onTap: () {},
                ),
                _NavRow(
                  icon: Icons.storage_outlined,
                  title: 'Storage and data',
                  subtitle: '1.2 GB used',
                  onTap: () {},
                ),
                _NavRow(
                  icon: Icons.info_outline_rounded,
                  title: 'About EthioChat',
                  subtitle: 'Version 0.1.0',
                  onTap: () {},
                  last: true,
                ),
              ],
            ),
            const SizedBox(height: Sp.x4),
            EthioButton(
              label: 'Sign out',
              kind: EthioButtonKind.danger,
              icon: Icons.logout_rounded,
              onPressed: () {},
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
