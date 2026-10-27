import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/design.dart';
import '../../../../core/utils/money_format.dart';
import '../../application/wallet_providers.dart';
import '../../domain/entities/wallet_entry.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  int _filter = 0;

  static const _filters = ['All', 'Money in', 'Money out'];

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);
    final text = Theme.of(context).textTheme;
    final async = ref.watch(walletEntriesProvider);
    final all = async.valueOrNull ?? const <WalletEntry>[];
    final entries = switch (_filter) {
      1 => all.where((e) => e.incoming).toList(growable: false),
      2 => all.where((e) => !e.incoming).toList(growable: false),
      _ => all,
    };

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text('Transactions', style: text.headlineMedium),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            SizedBox(
              height: 48,
              child: ListView.separated(
                padding: Sp.screen.copyWith(top: Sp.x2),
                scrollDirection: Axis.horizontal,
                itemCount: _filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: Sp.x2),
                itemBuilder: (context, i) => ChoiceChip(
                  label: Text(_filters[i]),
                  selected: _filter == i,
                  showCheckmark: false,
                  selectedColor: EthioColors.gold,
                  onSelected: (_) => setState(() => _filter = i),
                ),
              ),
            ),
            Expanded(
              child: async.isLoading && all.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : entries.isEmpty
                      ? EthioEmptyState(
                          icon: Icons.receipt_long_outlined,
                          title: 'No transactions',
                          message: _filter == 0
                              ? 'Your wallet activity will appear here.'
                              : 'Nothing matches this filter.',
                        )
                      : ListView.separated(
                          padding:
                              Sp.screen.copyWith(top: Sp.x3, bottom: Sp.x8),
                          itemCount: entries.length,
                          separatorBuilder: (_, __) => Divider(color: pal.line),
                          itemBuilder: (context, index) {
                            final entry = entries[index];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundColor: pal.chip,
                                child: Icon(
                                  entry.incoming
                                      ? Icons.call_received_rounded
                                      : Icons.call_made_rounded,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                entry.counterparty ?? entry.type.name,
                                style: text.titleMedium,
                              ),
                              subtitle: Text(
                                '${_date(entry.createdAt)}'
                                '${entry.note == null ? '' : ' · ${entry.note}'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.labelSmall?.copyWith(
                                  color: pal.textSecondary,
                                ),
                              ),
                              trailing: Text(
                                formatEtb(
                                  entry.incoming
                                      ? entry.amountMinor
                                      : -entry.amountMinor,
                                  signed: true,
                                ),
                                style: text.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: entry.incoming
                                      ? EthioColors.success
                                      : Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  String _date(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return 'Today, ${date.hour.toString().padLeft(2, '0')}:'
          '${date.minute.toString().padLeft(2, '0')}';
    }
    return '${date.day}/${date.month}/${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }
}
