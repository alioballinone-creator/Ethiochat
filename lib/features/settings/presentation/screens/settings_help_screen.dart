import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/design.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const _faqs = [
    (
      'How do I restore my chats on a new phone?',
      'Sign in with the same phone number, then choose Restore from your '
          'backup when prompted. Backups are end-to-end encrypted.',
    ),
    (
      'Why are my messages showing one tick?',
      'One tick means the message is queued on your phone. It will be '
          'delivered automatically when you have a connection.',
    ),
    (
      'How do I stop someone from contacting me?',
      'Open their profile or chat info and choose Block. You can review and '
          'unblock people from Settings, Privacy and security.',
    ),
    (
      'Can I use EthioChat without mobile data?',
      'Yes. Messages you send while offline are stored on your device and sent '
          'when you reconnect. Some media may wait for Wi-Fi.',
    ),
    (
      'How do I report a scam?',
      'Open the account or chat, choose Report, and select Spam or scam. Never '
          'share your wallet PIN or verification codes.',
    ),
  ];

  Future<void> _contactSupport(BuildContext context) async {
    await Clipboard.setData(
      const ClipboardData(text: 'support@ethiochat.et'),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Support email support@ethiochat.et copied.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final pal = EthioPalette.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text('Help and support', style: text.headlineMedium),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: Sp.screen.copyWith(top: Sp.x2, bottom: Sp.x8),
          children: [
            Container(
              padding: const EdgeInsets.all(Sp.x4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    EthioColors.gold.withValues(alpha: 0.28),
                    EthioColors.gold.withValues(alpha: 0.06),
                  ],
                ),
                borderRadius: Rad.r18,
                border: Border.all(
                  color: EthioColors.goldDeep.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  const EthioIconTile(
                    icon: Icons.support_agent_rounded,
                    background: EthioColors.gold,
                  ),
                  const SizedBox(width: Sp.x3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Need a hand?', style: text.titleMedium),
                        const SizedBox(height: 2),
                        Text(
                          'We usually reply within one working day.',
                          style: text.bodySmall
                              ?.copyWith(color: pal.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Sp.x4),
            EthioSectionCard(
              children: [
                EthioNavRow(
                  icon: Icons.mail_outline_rounded,
                  title: 'Contact support',
                  subtitle: 'Copy the support email address',
                  onTap: () => _contactSupport(context),
                ),
                EthioNavRow(
                  icon: Icons.flag_outlined,
                  title: 'Report a problem',
                  subtitle: 'Tell us what went wrong',
                  onTap: () => context.push(
                    '/report?target=EthioChat%20Support&type=problem',
                  ),
                  last: true,
                ),
              ],
            ),
            const EthioSectionLabel('Frequently asked questions'),
            for (final faq in _faqs)
              Container(
                margin: const EdgeInsets.only(bottom: Sp.x2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: Rad.r14,
                  border: Border.all(color: pal.line),
                ),
                child: ExpansionTile(
                  shape: const Border(),
                  collapsedShape: const Border(),
                  title: Text(faq.$1, style: text.titleMedium),
                  childrenPadding: const EdgeInsets.fromLTRB(
                    Sp.x4,
                    0,
                    Sp.x4,
                    Sp.x4,
                  ),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      faq.$2,
                      style: text.bodySmall?.copyWith(color: pal.textSecondary),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: Sp.x4),
            Text(
              'EthioChat · Version 0.1.0',
              textAlign: TextAlign.center,
              style: text.labelSmall?.copyWith(color: pal.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final pal = EthioPalette.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text('About EthioChat', style: text.headlineMedium),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: Sp.screen.copyWith(top: Sp.x4, bottom: Sp.x8),
          children: [
            Center(
              child: Column(
                children: [
                  Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      color: EthioColors.gold,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'ኢ',
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w700,
                        color: EthioColors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height: Sp.x3),
                  Text('EthioChat', style: text.headlineMedium),
                  Text(
                    'Version 0.1.0 (build 1)',
                    style: text.labelSmall?.copyWith(color: pal.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Sp.x6),
            EthioSectionCard(
              children: [
                EthioNavRow(
                  icon: Icons.description_outlined,
                  title: 'Terms of service',
                  subtitle: 'Rules for using EthioChat',
                  onTap: () => _showDocument(
                    context,
                    'Terms of service',
                    'EthioChat is provided as a communication service. You are '
                        'responsible for the content you share and for keeping '
                        'your account secure. Illegal content, fraud and '
                        'harassment are not permitted. Wallet services require '
                        'identity verification and compliance with National Bank '
                        'of Ethiopia directives before launch.',
                  ),
                ),
                EthioNavRow(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy policy',
                  subtitle: 'How we handle your data',
                  onTap: () => _showDocument(
                    context,
                    'Privacy policy',
                    'Your messages are stored on your device and encrypted in '
                        'transit. Profile details are used to connect you with '
                        'contacts and are never sold. You can clear cached media '
                        'or sign out at any time.',
                  ),
                ),
                EthioNavRow(
                  icon: Icons.verified_outlined,
                  title: 'Open source licences',
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: 'EthioChat',
                    applicationVersion: '0.1.0',
                  ),
                  last: true,
                ),
              ],
            ),
            const SizedBox(height: Sp.x4),
            Text(
              'Made in Addis Ababa 🇪🇹\n'
              'Local-first messaging for Ethiopia and the Horn of Africa.',
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(color: pal.textSecondary),
            ),
            const SizedBox(height: Sp.x4),
            Text(
              'Flutter · Drift · Supabase',
              textAlign: TextAlign.center,
              style: text.labelSmall?.copyWith(color: pal.textTertiary),
            ),
          ],
        ),
      ),
    );
  }

  void _showDocument(BuildContext context, String title, String body) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(body)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
