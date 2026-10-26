import 'package:flutter/material.dart';

import '../design.dart';

/// Reference sheet for the EthioChat design system.
///
/// Used by the golden test so visual regressions in the shared widgets are
/// caught on Linux CI before they reach a device.
class DesignGallery extends StatelessWidget {
  const DesignGallery({super.key});

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: const EthioWordmark(size: 26),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: Sp.x5),
            child: Center(
              child: Text(
                'Design system',
                style: text.labelSmall?.copyWith(color: pal.textSecondary),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: Sp.screen.copyWith(top: Sp.x4, bottom: Sp.x8),
        children: [
          _Section(title: 'Colour'),
          Wrap(
            spacing: Sp.x2,
            runSpacing: Sp.x2,
            children: const [
              _Swatch(color: EthioColors.goldDeep, label: 'Gold deep'),
              _Swatch(color: EthioColors.gold, label: 'Gold'),
              _Swatch(color: EthioColors.goldLight, label: 'Gold light'),
              _Swatch(color: EthioColors.cream, label: 'Cream'),
              _Swatch(color: EthioColors.black, label: 'Ink'),
            ],
          ),
          _Section(title: 'Buttons'),
          EthioButton(label: 'Primary action', onPressed: () {}),
          const SizedBox(height: Sp.x2),
          EthioButton(
            label: 'Secondary action',
            kind: EthioButtonKind.secondary,
            onPressed: () {},
          ),
          const SizedBox(height: Sp.x2),
          Row(
            children: [
              Expanded(
                child: EthioButton(
                  label: 'Tonal',
                  kind: EthioButtonKind.tonal,
                  onPressed: () {},
                ),
              ),
              const SizedBox(width: Sp.x2),
              Expanded(
                child: EthioButton(
                  label: 'Danger',
                  kind: EthioButtonKind.danger,
                  onPressed: () {},
                ),
              ),
            ],
          ),
          const SizedBox(height: Sp.x2),
          EthioButton(
            label: 'Disabled',
            onPressed: null,
          ),
          _Section(title: 'Inputs'),
          const EthioTextField(hint: 'Phone number'),
          const SizedBox(height: Sp.x3),
          const EthioTextField(
            hint: 'Invalid value',
            errorText: 'Enter a valid Ethiopian number',
          ),
          _Section(title: 'Chat list tile'),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: Rad.r18,
              border: Border.all(color: pal.line),
            ),
            clipBehavior: Clip.antiAlias,
            child: const Column(
              children: [
                ChatListTile(
                  title: 'Abebe Kebede',
                  preview: 'See you tomorrow',
                  time: '14:32',
                  unread: 2,
                  online: true,
                ),
                ChatListTile(
                  title: 'Tigist Alemayehu',
                  preview: 'Thanks! 🙏',
                  time: '12:15',
                  pinned: true,
                ),
              ],
            ),
          ),
          _Section(title: 'Messages'),
          const MessageBubble(
            text: 'Hello! How are you?',
            isMine: false,
            time: '14:30',
          ),
          const SizedBox(height: Sp.x2),
          const MessageBubble(
            text: 'I am fine, thanks!',
            isMine: true,
            time: '14:32',
            status: MessageStatus.read,
          ),
          _Section(title: 'Avatars & badges'),
          Row(
            children: [
              const EthioAvatar(name: 'Abebe Kebede', size: 44),
              const SizedBox(width: Sp.x2),
              const EthioAvatar(
                  name: 'Tigist Alemayehu', size: 44, online: true),
              const SizedBox(width: Sp.x2),
              const EthioAvatar(name: 'Dawit Bekele', size: 44),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Sp.x2,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: EthioColors.gold,
                  borderRadius: BorderRadius.circular(Rad.pill),
                ),
                child: Text(
                  '2',
                  style: text.labelSmall?.copyWith(color: EthioColors.black),
                ),
              ),
            ],
          ),
          _Section(title: 'Wallet card'),
          const WalletCard(balanceMinor: 125050, ethioId: 'EC-123456'),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Sp.x5, bottom: Sp.x3),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            color: color,
            borderRadius: Rad.r10,
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        const SizedBox(height: Sp.x1),
        SizedBox(
          width: 62,
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: dark ? Colors.white70 : Colors.black54,
                ),
          ),
        ),
      ],
    );
  }
}
