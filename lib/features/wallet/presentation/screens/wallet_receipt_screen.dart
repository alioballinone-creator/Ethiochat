import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/design.dart';
import '../../../../core/utils/money_format.dart';
import '../../domain/entities/wallet_entry.dart';

class WalletReceiptScreen extends StatelessWidget {
  const WalletReceiptScreen({super.key, this.receipt});

  final WalletReceipt? receipt;

  Future<void> _share(BuildContext context) async {
    final value = receipt;
    if (value == null) return;
    await Clipboard.setData(
      ClipboardData(
        text: 'EthioChat receipt\n'
            '${value.title}\n'
            '${formatEtb(value.amountMinor)}\n'
            'Reference: ${value.reference}\n'
            '${value.counterparty ?? ''}',
      ),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Receipt copied.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);
    final text = Theme.of(context).textTheme;
    final value = receipt;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.go('/wallet'),
        ),
        title: Text('Receipt', style: text.headlineMedium),
        actions: [
          IconButton(
            tooltip: 'Share receipt',
            icon: const Icon(Icons.share_outlined),
            onPressed: value == null ? null : () => _share(context),
          ),
          const SizedBox(width: Sp.x1),
        ],
      ),
      body: SafeArea(
        top: false,
        child: value == null
            ? const EthioEmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'No receipt',
                message: 'Complete a payment to see its receipt here.',
              )
            : ListView(
                padding: Sp.screen.copyWith(top: Sp.x6, bottom: Sp.x8),
                children: [
                  Center(
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: const BoxDecoration(
                        color: EthioColors.success,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 46,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: Sp.x4),
                  Text(
                    'Payment successful',
                    textAlign: TextAlign.center,
                    style: text.titleLarge,
                  ),
                  const SizedBox(height: Sp.x2),
                  Text(
                    formatEtb(value.amountMinor),
                    textAlign: TextAlign.center,
                    style: text.headlineMedium?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: Sp.x1),
                  Text(
                    value.title,
                    textAlign: TextAlign.center,
                    style: text.bodyMedium?.copyWith(
                      color: pal.textSecondary,
                    ),
                  ),
                  const SizedBox(height: Sp.x6),
                  EthioSectionCard(
                    children: [
                      _ReceiptRow(
                        label: 'Reference',
                        value: value.reference,
                      ),
                      _ReceiptRow(
                        label: 'Type',
                        value: switch (value.type) {
                          WalletTxType.transfer => 'Transfer',
                          WalletTxType.bill => 'Bill payment',
                          WalletTxType.redPacket => 'Red packet',
                          WalletTxType.topUp => 'Top up',
                          WalletTxType.receive => 'Received',
                        },
                      ),
                      if (value.counterparty != null)
                        _ReceiptRow(
                          label: 'To',
                          value: value.counterparty!,
                        ),
                      if (value.note != null)
                        _ReceiptRow(label: 'Note', value: value.note!),
                      _ReceiptRow(
                        label: 'Date',
                        value: '${value.createdAt.day}/'
                            '${value.createdAt.month}/'
                            '${value.createdAt.year} '
                            '${value.createdAt.hour.toString().padLeft(2, '0')}:'
                            '${value.createdAt.minute.toString().padLeft(2, '0')}',
                        last: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: Sp.x6),
                  EthioButton(
                    label: 'Done',
                    onPressed: () => context.go('/wallet'),
                  ),
                  const SizedBox(height: Sp.x3),
                  EthioButton(
                    label: 'View all transactions',
                    kind: EthioButtonKind.secondary,
                    onPressed: () => context.go('/wallet/transactions'),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({
    required this.label,
    required this.value,
    this.last = false,
  });

  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Sp.x4,
            vertical: Sp.x4,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: pal.textSecondary),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
        if (!last) Divider(height: 1, color: pal.line),
      ],
    );
  }
}
