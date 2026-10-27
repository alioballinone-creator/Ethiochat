import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/demo/demo_content.dart';
import '../../../../core/design/design.dart';
import '../../../../core/utils/money_format.dart';
import '../../application/wallet_providers.dart';
import '../../domain/entities/wallet_entry.dart';

class BillsScreen extends ConsumerStatefulWidget {
  const BillsScreen({super.key});

  @override
  ConsumerState<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends ConsumerState<BillsScreen> {
  final _account = TextEditingController();
  final _amount = TextEditingController();
  DemoBiller _biller = DemoContent.billers.first;
  String? _error;

  @override
  void dispose() {
    _account.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final amount = parseEtbToMinor(_amount.text);
    if (_account.text.trim().length < 3) {
      setState(
          () => _error = 'Enter your ${_biller.accountLabel.toLowerCase()}.');
      return;
    }
    if (amount <= 0) {
      setState(() => _error = 'Enter an amount greater than zero.');
      return;
    }
    final total = amount + _biller.fee;
    final balance = await ref.read(walletRepositoryProvider).currentBalance();
    if (total > balance) {
      setState(() => _error = 'Your wallet balance is too low.');
      return;
    }
    if (!mounted) return;
    setState(() => _error = null);
    await context.push(
      '/wallet/pin',
      extra: PinRequest(
        type: WalletTxType.bill,
        amountMinor: total,
        title: 'Pay ${_biller.name}',
        provider: _biller.name,
        accountRef: _account.text.trim(),
        note: 'Bill payment · ${_biller.accountLabel}',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);
    final text = Theme.of(context).textTheme;
    final balance = ref.watch(walletBalanceProvider).valueOrNull ?? 0;
    final amount = parseEtbToMinor(_amount.text);
    final total = amount > 0 ? amount + _biller.fee : 0;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text('Bills', style: text.headlineMedium),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: Sp.screen.copyWith(top: Sp.x4, bottom: Sp.x8),
          children: [
            Container(
              padding: const EdgeInsets.all(Sp.x4),
              decoration: BoxDecoration(
                color: pal.chip,
                borderRadius: Rad.r14,
                border: Border.all(color: pal.line),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet_outlined, size: 18),
                  const SizedBox(width: Sp.x2),
                  Text(
                    'Balance ${formatEtb(balance)}',
                    style: text.bodySmall?.copyWith(color: pal.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Sp.x5),
            Text('Biller', style: text.titleMedium),
            const SizedBox(height: Sp.x2),
            EthioSectionCard(
              children: [
                for (var i = 0; i < DemoContent.billers.length; i++)
                  RadioListTile<DemoBiller>(
                    value: DemoContent.billers[i],
                    groupValue: _biller,
                    onChanged: (value) => setState(() {
                      _biller = value ?? _biller;
                      _error = null;
                    }),
                    title: Text(DemoContent.billers[i].name),
                    subtitle: Text(
                      DemoContent.billers[i].fee == 0
                          ? 'No service fee'
                          : 'Service fee ${formatEtb(DemoContent.billers[i].fee)}',
                      style:
                          text.labelSmall?.copyWith(color: pal.textSecondary),
                    ),
                    activeColor: EthioColors.goldDeep,
                  ),
              ],
            ),
            const SizedBox(height: Sp.x5),
            Text(_biller.accountLabel, style: text.titleMedium),
            const SizedBox(height: Sp.x2),
            EthioTextField(
              controller: _account,
              hint: 'Enter ${_biller.accountLabel.toLowerCase()}',
              onChanged: (_) => setState(() => _error = null),
            ),
            const SizedBox(height: Sp.x5),
            Text('Amount', style: text.titleMedium),
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
            if (total > 0) ...[
              const SizedBox(height: Sp.x3),
              Row(
                children: [
                  Text('Total', style: text.bodyMedium),
                  const Spacer(),
                  Text(
                    formatEtb(total),
                    style: text.titleMedium,
                  ),
                ],
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: Sp.x3),
              Text(
                _error!,
                style: text.bodySmall?.copyWith(color: EthioColors.danger),
              ),
            ],
            const SizedBox(height: Sp.x6),
            EthioButton(
              label: total > 0 ? 'Pay ${formatEtb(total)}' : 'Continue',
              icon: Icons.lock_outline_rounded,
              onPressed: _continue,
            ),
            const SizedBox(height: Sp.x3),
            Center(
              child: Text(
                'Payments are protected by your wallet PIN.',
                style: text.labelSmall?.copyWith(color: pal.textTertiary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
