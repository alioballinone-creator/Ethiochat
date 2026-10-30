import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/design.dart';
import '../../../../core/platform/secure_screen.dart';
import '../../../../core/utils/money_format.dart';
import '../../../profile/application/profile_controller.dart';
import '../../application/wallet_providers.dart';
import '../../domain/entities/wallet_entry.dart';

/// 08 — Wallet. Balance is derived from the local double-entry ledger.
class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pal = EthioPalette.of(context);
    final profile = ref.watch(userProfileProvider);
    final balance = ref.watch(walletBalanceProvider).valueOrNull ?? 0;
    final seed = ref.watch(walletSeedProvider);
    final entries =
        ref.watch(walletEntriesProvider).valueOrNull ?? const <WalletEntry>[];

    return SecureScreenScope(
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          leading: IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
          title: Text(
            'Wallet',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          actions: [
            IconButton(
              tooltip: 'Wallet PIN',
              icon: const Icon(Icons.lock_outline_rounded),
              onPressed: () => context.push('/wallet/pin'),
            ),
            IconButton(
              tooltip: 'All transactions',
              icon: const Icon(Icons.receipt_long_outlined),
              onPressed: () => context.push('/wallet/transactions'),
            ),
            const SizedBox(width: Sp.x1),
          ],
        ),
        body: SafeArea(
          child: RefreshIndicator(
            color: EthioColors.gold,
            onRefresh: () async {
              ref.invalidate(walletSeedProvider);
              await ref.read(walletSeedProvider.future);
            },
            child: ListView(
              padding: Sp.screen.copyWith(top: Sp.x2, bottom: Sp.x8),
              children: [
                WalletCard(balanceMinor: balance, ethioId: profile.ethioId),
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
                        (constraints.maxWidth - Sp.x2 * (columns - 1)) /
                            columns;
                    final actions = <_WalletAction>[
                      _WalletAction(
                        icon: Icons.send_rounded,
                        label: 'Send',
                        onTap: () => context.push('/wallet/send'),
                      ),
                      _WalletAction(
                        icon: Icons.call_received_rounded,
                        label: 'Receive',
                        onTap: () => context.push('/wallet/receive'),
                      ),
                      _WalletAction(
                        icon: Icons.qr_code_scanner_rounded,
                        label: 'Scan',
                        onTap: () => context.push('/scan?pay=true'),
                      ),
                      _WalletAction(
                        icon: Icons.add_circle_outline_rounded,
                        label: 'Top up',
                        onTap: () => context.push('/wallet/top-up'),
                      ),
                      _WalletAction(
                        icon: Icons.receipt_long_outlined,
                        label: 'Bills',
                        onTap: () => context.push('/wallet/bills'),
                      ),
                      _WalletAction(
                        icon: Icons.card_giftcard_outlined,
                        label: 'Red packet',
                        onTap: () => context.push('/wallet/red-packet'),
                      ),
                    ];
                    return Wrap(
                      spacing: Sp.x2,
                      runSpacing: Sp.x4,
                      children: [
                        for (final action in actions)
                          SizedBox(width: tileWidth, child: action),
                      ],
                    );
                  },
                ),
                const SizedBox(height: Sp.x6),
                Row(
                  children: [
                    Text(
                      'Recent activity',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => context.push('/wallet/transactions'),
                      child: const Text('See all'),
                    ),
                  ],
                ),
                const SizedBox(height: Sp.x1),
                if (seed.isLoading && entries.isEmpty)
                  const SizedBox(
                    height: 172,
                    child: TransactionListSkeleton(count: 3),
                  )
                else if (entries.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(Sp.x5),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: Rad.r18,
                      border: Border.all(color: pal.line),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.account_balance_wallet_outlined,
                          size: 36,
                          color: pal.textTertiary,
                        ),
                        const SizedBox(height: Sp.x2),
                        Text(
                          'No wallet activity yet',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: Sp.x1),
                        Text(
                          'Top up or receive money to get started.',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: pal.textSecondary),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: Rad.r18,
                      border: Border.all(color: pal.line),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        for (var i = 0; i < entries.length; i++) ...[
                          _ActivityItem(entry: entries[i]),
                          if (i != entries.length - 1)
                            Divider(height: 1, color: pal.line),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WalletAction extends StatelessWidget {
  const _WalletAction({
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
    return InkWell(
      onTap: onTap,
      borderRadius: Rad.r14,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Sp.x1),
        child: Column(
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
        ),
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  const _ActivityItem({required this.entry});

  final WalletEntry entry;

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);
    final amount = formatEtb(
      entry.incoming ? entry.amountMinor : -entry.amountMinor,
      signed: true,
    );
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Sp.x4,
        vertical: Sp.x1,
      ),
      leading: CircleAvatar(
        backgroundColor: pal.chip,
        child: Icon(
          entry.incoming
              ? Icons.call_received_rounded
              : switch (entry.type) {
                  WalletTxType.bill => Icons.receipt_long_outlined,
                  WalletTxType.redPacket => Icons.card_giftcard_outlined,
                  _ => Icons.call_made_rounded,
                },
          size: 20,
        ),
      ),
      title: Text(
        entry.counterparty ?? entry.type.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      subtitle: Text(
        entry.note ?? _shortDate(entry.createdAt),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: pal.textSecondary),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            amount,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: entry.incoming
                      ? EthioColors.success
                      : Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
          ),
          if (entry.pending)
            Text(
              'Pending',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: pal.textTertiary),
            ),
        ],
      ),
    );
  }

  String _shortDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${date.day}/${date.month}/${date.year}';
  }
}
