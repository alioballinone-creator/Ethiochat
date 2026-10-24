import 'package:flutter/material.dart';
import 'package:ethiochat/core/theme/app_spacing.dart';
import 'package:ethiochat/core/theme/ethio_colors.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: const BoxDecoration(
              gradient: EthioColors.goldGradient,
              borderRadius: BorderRadius.all(Radius.circular(AppSpacing.radius)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Balance',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: EthioColors.black),
                ),
                const SizedBox(height: 8),
                Text(
                  'ETB 0.00',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(color: EthioColors.black),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _Action(icon: Icons.add, label: 'Top up'),
              _Action(icon: Icons.send, label: 'Send'),
              _Action(icon: Icons.qr_code, label: 'Receive'),
              _Action(icon: Icons.qr_code_scanner, label: 'Scan'),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Recent transactions', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          const Card(
            child: ListTile(
              title: Text('No transactions yet'),
              subtitle: Text('Your transactions will appear here'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: EthioColors.goldDeep),
        ),
        const SizedBox(height: 8),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
