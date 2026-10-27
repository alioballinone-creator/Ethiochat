import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/design.dart';
import '../../../../core/utils/money_format.dart';
import '../../application/wallet_providers.dart';
import '../../domain/entities/wallet_entry.dart';

class TopUpScreen extends ConsumerStatefulWidget {
  const TopUpScreen({super.key});

  @override
  ConsumerState<TopUpScreen> createState() => _TopUpScreenState();
}

class _TopUpScreenState extends ConsumerState<TopUpScreen> {
  final _amount = TextEditingController();
  String _provider = 'Telebirr';
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final amount = parseEtbToMinor(_amount.text);
    if (amount <= 0) {
      setState(() => _error = 'Enter an amount greater than zero.');
      return;
    }
    setState(() => _error = null);
    await context.push(
      '/wallet/pin',
      extra: PinRequest(
        type: WalletTxType.topUp,
        amountMinor: amount,
        title: 'Top up ${formatEtb(amount)}',
        provider: _provider,
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
        title: Text('Top up', style: text.headlineMedium),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: Sp.screen.copyWith(top: Sp.x4, bottom: Sp.x8),
          children: [
            _Card(
              children: [
                ListTile(
                  leading: const EthioIconTile(
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                  title: Text('Current balance', style: text.bodyMedium),
                  trailing: Text(
                    formatEtb(balance),
                    style: text.titleMedium?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
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
            const SizedBox(height: Sp.x3),
            Wrap(
              spacing: Sp.x2,
              runSpacing: Sp.x2,
              children: [
                for (final amount in const ['100', '250', '500', '1000'])
                  ActionChip(
                    label: Text('ETB $amount'),
                    onPressed: () => setState(() => _amount.text = amount),
                  ),
              ],
            ),
            const SizedBox(height: Sp.x5),
            Text('Pay with', style: text.titleMedium),
            const SizedBox(height: Sp.x2),
            _Card(
              children: [
                for (var i = 0; i < _providers.length; i++)
                  RadioListTile<String>(
                    value: _providers[i],
                    groupValue: _provider,
                    onChanged: (value) =>
                        setState(() => _provider = value ?? _provider),
                    title: Text(_providers[i]),
                    secondary: const EthioIconTile(
                      icon: Icons.payments_outlined,
                    ),
                    activeColor: EthioColors.goldDeep,
                  ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: Sp.x3),
              Text(
                _error!,
                style: text.bodySmall?.copyWith(color: EthioColors.danger),
              ),
            ],
            const SizedBox(height: Sp.x6),
            EthioButton(
              label: 'Continue',
              icon: Icons.arrow_forward_rounded,
              onPressed: _continue,
            ),
            const SizedBox(height: Sp.x3),
            Center(
              child: Text(
                'Funds are added after confirmation.',
                style: text.labelSmall?.copyWith(color: pal.textTertiary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const _providers = [
    'Telebirr',
    'CBE Birr',
    'Chapa',
    'Debit card',
  ];
}

class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return EthioSectionCard(children: children);
  }
}
