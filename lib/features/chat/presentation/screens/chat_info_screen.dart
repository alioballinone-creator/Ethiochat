import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/design.dart';

/// Chat info / conversation settings.
class ChatInfoScreen extends StatefulWidget {
  const ChatInfoScreen({super.key, required this.chatId});

  final String chatId;

  @override
  State<ChatInfoScreen> createState() => _ChatInfoScreenState();
}

class _ChatInfoScreenState extends State<ChatInfoScreen> {
  bool _muted = false;
  bool _pinned = true;

  static const _media = <int>[0, 1, 2, 3, 4, 5];

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text('Chat info', style: text.headlineMedium),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: Sp.screen.copyWith(top: Sp.x2, bottom: Sp.x8),
          children: [
            Center(
              child: Column(
                children: [
                  const EthioAvatar(name: 'Abebe Kebede', size: 88),
                  const SizedBox(height: Sp.x3),
                  Text('Abebe Kebede', style: text.headlineSmall),
                  const SizedBox(height: Sp.x1),
                  Text(
                    '+251 91 234 5678',
                    style: text.bodyMedium?.copyWith(color: pal.textSecondary),
                  ),
                  const SizedBox(height: Sp.x3),
                  Wrap(
                    spacing: Sp.x2,
                    runSpacing: Sp.x2,
                    alignment: WrapAlignment.center,
                    children: [
                      _QuickPill(
                        icon: Icons.call_outlined,
                        label: 'Call',
                        onTap: () => context.push('/call/1'),
                      ),
                      _QuickPill(
                        icon: Icons.videocam_outlined,
                        label: 'Video',
                        onTap: () => context.push('/call/1?video=true'),
                      ),
                      _QuickPill(
                        icon: Icons.search_rounded,
                        label: 'Search',
                        onTap: () => context.push('/search'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: Sp.x6),
            _Card(
              children: [
                _SwitchRow(
                  icon: Icons.notifications_off_outlined,
                  title: 'Mute notifications',
                  value: _muted,
                  onChanged: (v) => setState(() => _muted = v),
                ),
                _SwitchRow(
                  icon: Icons.push_pin_outlined,
                  title: 'Pin chat',
                  value: _pinned,
                  onChanged: (v) => setState(() => _pinned = v),
                  last: true,
                ),
              ],
            ),
            const SizedBox(height: Sp.x4),
            Row(
              children: [
                Text('Media', style: text.titleMedium),
                const Spacer(),
                TextButton(onPressed: () {}, child: const Text('See all')),
              ],
            ),
            SizedBox(
              height: 84,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _media.length,
                separatorBuilder: (_, __) => const SizedBox(width: Sp.x2),
                itemBuilder: (context, i) => Container(
                  width: 84,
                  decoration: BoxDecoration(
                    borderRadius: Rad.r14,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        EthioColors.avatarTones[i % EthioColors.avatarTones.length],
                        EthioColors.avatarTones[(i + 3) % EthioColors.avatarTones.length],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: Sp.x4),
            _Card(
              children: [
                _NavRow(
                  icon: Icons.photo_library_outlined,
                  title: 'Photos and videos',
                  trailing: '128',
                  onTap: () {},
                ),
                _NavRow(
                  icon: Icons.insert_drive_file_outlined,
                  title: 'Documents',
                  trailing: '12',
                  onTap: () {},
                ),
                _NavRow(
                  icon: Icons.link_rounded,
                  title: 'Links',
                  trailing: '9',
                  onTap: () {},
                ),
                _NavRow(
                  icon: Icons.auto_delete_outlined,
                  title: 'Disappearing messages',
                  trailing: 'Off',
                  onTap: () {},
                  last: true,
                ),
              ],
            ),
            const SizedBox(height: Sp.x4),
            _Card(
              children: [
                _NavRow(
                  icon: Icons.block_outlined,
                  title: 'Block contact',
                  danger: true,
                  onTap: () {},
                ),
                _NavRow(
                  icon: Icons.flag_outlined,
                  title: 'Report',
                  danger: true,
                  onTap: () {},
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

class _QuickPill extends StatelessWidget {
  const _QuickPill({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);

    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: Rad.r14,
      child: InkWell(
        onTap: onTap,
        borderRadius: Rad.r14,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Sp.x4,
            vertical: Sp.x3,
          ),
          decoration: BoxDecoration(
            borderRadius: Rad.r14,
            border: Border.all(color: pal.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: Sp.x2),
              Text(label, style: Theme.of(context).textTheme.labelLarge),
            ],
          ),
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

class _IconTile extends StatelessWidget {
  const _IconTile({required this.icon, this.danger = false});

  final IconData icon;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: danger ? EthioColors.danger.withValues(alpha: 0.12) : pal.chip,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        icon,
        size: 22,
        color: danger ? EthioColors.danger : null,
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.trailing,
    this.danger = false,
    this.last = false,
  });

  final IconData icon;
  final String title;
  final String? trailing;
  final VoidCallback onTap;
  final bool danger;
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
          leading: _IconTile(icon: icon, danger: danger),
          title: Text(
            title,
            style: text.titleMedium?.copyWith(
              color: danger ? EthioColors.danger : null,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (trailing != null)
                Text(
                  trailing!,
                  style: text.labelSmall?.copyWith(color: pal.textSecondary),
                ),
              const SizedBox(width: Sp.x1),
              Icon(Icons.chevron_right_rounded, color: pal.textTertiary),
            ],
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
    this.last = false,
  });

  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);

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
          title: Text(title, style: Theme.of(context).textTheme.titleMedium),
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
