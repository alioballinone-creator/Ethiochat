import 'package:flutter/material.dart';
import '../../../../core/design/design.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Wallet',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: Sp.screen,
          children: [
            const WalletCard(balanceMinor: 125050, ethioId: 'EC-123456'),
            const SizedBox(height: Sp.x6),
            Text(
              'Quick actions',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: Sp.x3),
            LayoutBuilder(
              builder: (context, constraints) {
                const columns = 3;
                final tileWidth =
                    (constraints.maxWidth - Sp.x2 * (columns - 1)) / columns;
                return Wrap(
                  spacing: Sp.x2,
                  runSpacing: Sp.x4,
                  children: const [
                    _QuickAction(
                      icon: Icons.send_rounded,
                      label: 'Send',
                    ),
                    _QuickAction(
                      icon: Icons.call_received_rounded,
                      label: 'Receive',
                    ),
                    _QuickAction(
                      icon: Icons.qr_code_scanner_rounded,
                      label: 'Scan',
                    ),
                    _QuickAction(
                      icon: Icons.add_circle_outline_rounded,
                      label: 'Top up',
                    ),
                    _QuickAction(
                      icon: Icons.receipt_long_outlined,
                      label: 'Bills',
                    ),
                    _QuickAction(
                      icon: Icons.card_giftcard_outlined,
                      label: 'Red packet',
                    ),
                  ]
                      .map(
                          (action) => SizedBox(width: tileWidth, child: action))
                      .toList(),
                );
              },
            ),
            const SizedBox(height: Sp.x6),
            Text(
              'Recent activity',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: Sp.x3),
            Container(
              padding: const EdgeInsets.all(Sp.x4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: Rad.r18,
                border: Border.all(color: pal.line),
              ),
              child: Column(
                children: [
                  _ActivityItem(
                      title: 'Received from Abebe',
                      amount: '+ ETB 500.00',
                      isPositive: true),
                  Divider(color: pal.line),
                  _ActivityItem(
                      title: 'Sent to Tigist',
                      amount: '- ETB 200.00',
                      isPositive: false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: pal.line),
          ),
          child: Icon(icon),
        ),
        const SizedBox(height: Sp.x2),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _ActivityItem extends StatelessWidget {
  const _ActivityItem(
      {required this.title, required this.amount, required this.isPositive});

  final String title;
  final String amount;
  final bool isPositive;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Sp.x2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: Sp.x2),
          Flexible(
            child: Text(
              amount,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isPositive
                        ? EthioColors.success
                        : Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
