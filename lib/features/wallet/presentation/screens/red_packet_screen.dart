import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/design.dart';
import '../../../../core/utils/money_format.dart';
import '../../application/wallet_providers.dart';
import '../../domain/entities/wallet_entry.dart';

class RedPacketScreen extends ConsumerStatefulWidget {
  const RedPacketScreen({super.key});

  @override
  ConsumerState<RedPacketScreen> createState() => _RedPacketScreenState();
}

class _RedPacketScreenState extends ConsumerState<RedPacketScreen> {
  final _amount = TextEditingController();
  final _count = TextEditingController(text: '1');
  final _note = TextEditingController(text: 'Best wishes');
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _count.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final amount = parseEtbToMinor(_amount.text);
    final count = int.tryParse(_count.text) ?? 0;
    if (amount <= 0) {
      setState(() => _error = 'Enter an amount greater than zero.');
      return;
    }
    if (count < 1 || count > 100) {
      setState(() => _error = 'Choose between 1 and 100 people.');
      return;
    }
    if (amount < count) {
      setState(() => _error = 'Each person needs at least ETB 0.01.');
      return;
    }
    final balance = await ref.read(walletRepositoryProvider).currentBalance();
    if (amount > balance) {
      setState(() => _error = 'Your wallet balance is too low.');
      return;
    }
    if (!mounted) return;
    setState(() => _error = null);
    await context.push(
      '/wallet/pin',
      extra: PinRequest(
        type: WalletTxType.redPacket,
        amountMinor: amount,
        title: 'Send red packet',
        recipient: '$count ${count == 1 ? 'person' : 'people'}',
        note: _note.text.trim().isEmpty ? 'Best wishes' : _note.text.trim(),
        redPacketCount: count,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);
    final text = Theme.of(context).textTheme;
    final balance = ref.watch(walletBalanceProvider).valueOrNull ?? 0;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text('Red packet', style: text.headlineMedium),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: Sp.screen.copyWith(top: Sp.x4, bottom: Sp.x8),
          children: [
            Container(
              padding: const EdgeInsets.all(Sp.x5),
              decoration: BoxDecoration(
                gradient: EthioColors.goldGradient,
                borderRadius: Rad.r24,
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.card_giftcard_rounded,
                    size: 38,
                    color: EthioColors.black,
                  ),
                  const SizedBox(height: Sp.x2),
                  Text(
                    'Share a little luck',
                    style: text.titleLarge?.copyWith(color: EthioColors.black),
                  ),
                  const SizedBox(height: Sp.x1),
                  Text(
                    'Everyone in the packet gets a share.',
                    style: text.bodySmall?.copyWith(
                      color: EthioColors.black.withValues(alpha: 0.68),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Sp.x5),
            Text('Total amount', style: text.titleMedium),
            const SizedBox(height: Sp.x2),
            EthioTextField(
              controller: _amount,
              hint: '0.00',
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              prefix: Padding(
                padding: const EdgeInsets.only(left: Sp.x4, right: Sp.x2),
                child: Center(widthFactor: 1, child: Text('ETB')),
              ),
              onChanged: (_) => setState(() => _error = null),
            ),
            const SizedBox(height: Sp.x4),
            Text('Number of people', style: text.titleMedium),
            const SizedBox(height: Sp.x2),
            EthioTextField(
              controller: _count,
              hint: '1',
              keyboardType: TextInputType.number,
              prefix: const Icon(Icons.groups_outlined, size: 20),
              onChanged: (_) => setState(() => _error = null),
            ),
            const SizedBox(height: Sp.x4),
            Text('Message', style: text.titleMedium),
            const SizedBox(height: Sp.x2),
            EthioTextField(
              controller: _note,
              hint: 'Best wishes',
              maxLength: 60,
            ),
            if (_error != null) ...[
              const SizedBox(height: Sp.x3),
              Text(
                _error!,
                style: text.bodySmall?.copyWith(color: EthioColors.danger),
              ),
            ],
            const SizedBox(height: Sp.x5),
            Row(
              children: [
                Icon(Icons.account_balance_wallet_outlined,
                    size: 16, color: pal.textSecondary),
                const SizedBox(width: Sp.x1),
                Text(
                  'Balance ${formatEtb(balance)}',
                  style: text.labelSmall?.copyWith(color: pal.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: Sp.x5),
            EthioButton(
              label: 'Pack and send',
              icon: Icons.redeem_rounded,
              onPressed: _continue,
            ),
          ],
        ),
      ),
    );
  }
}
