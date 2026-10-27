import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/design.dart';
import '../../../../core/utils/money_format.dart';
import '../../../chats/application/chat_providers.dart';
import '../../../contacts/domain/entities/contact_entity.dart';
import '../../application/wallet_providers.dart';
import '../../domain/entities/wallet_entry.dart';

class SendMoneyScreen extends ConsumerStatefulWidget {
  const SendMoneyScreen({super.key});

  @override
  ConsumerState<SendMoneyScreen> createState() => _SendMoneyScreenState();
}

class _SendMoneyScreenState extends ConsumerState<SendMoneyScreen> {
  final _recipient = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String? _error;
  bool _seeded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    final recipient = GoRouter.maybeOf(context) == null
        ? null
        : GoRouterState.of(context).uri.queryParameters['to'];
    if (recipient != null && recipient.isNotEmpty) {
      _recipient.text = recipient;
    }
    _seeded = true;
  }

  @override
  void dispose() {
    _recipient.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final name = _recipient.text.trim();
    final amount = parseEtbToMinor(_amount.text);
    if (name.isEmpty) {
      setState(() => _error = 'Enter a recipient.');
      return;
    }
    if (amount <= 0) {
      setState(() => _error = 'Enter an amount greater than zero.');
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
        type: WalletTxType.transfer,
        amountMinor: amount,
        title: 'Send ${formatEtb(amount)}',
        recipient: name,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);
    final text = Theme.of(context).textTheme;
    final balance = ref.watch(walletBalanceProvider).valueOrNull ?? 0;
    final contacts =
        ref.watch(contactsProvider).valueOrNull ?? const <ContactEntity>[];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text('Send money', style: text.headlineMedium),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: Sp.screen.copyWith(top: Sp.x3, bottom: Sp.x8),
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
                  Icon(Icons.account_balance_wallet_outlined,
                      size: 18, color: pal.textSecondary),
                  const SizedBox(width: Sp.x2),
                  Text(
                    'Available ${formatEtb(balance)}',
                    style: text.bodySmall?.copyWith(color: pal.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Sp.x5),
            Text('To', style: text.titleMedium),
            const SizedBox(height: Sp.x2),
            EthioTextField(
              controller: _recipient,
              hint: 'Name, phone or Ethio ID',
              prefix: const Icon(Icons.person_search_outlined, size: 20),
              onChanged: (_) => setState(() => _error = null),
            ),
            if (contacts.isNotEmpty) ...[
              const SizedBox(height: Sp.x3),
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: contacts.take(8).length,
                  separatorBuilder: (_, __) => const SizedBox(width: Sp.x2),
                  itemBuilder: (context, i) {
                    final contact = contacts[i];
                    return ActionChip(
                      avatar: CircleAvatar(
                        child: Text(contact.initial),
                      ),
                      label: Text(contact.displayName.split(' ').first),
                      onPressed: () {
                        setState(() => _recipient.text = contact.displayName);
                      },
                    );
                  },
                ),
              ),
            ],
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
                child: Center(
                  widthFactor: 1,
                  child: Text('ETB', style: text.labelLarge),
                ),
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
                    onPressed: () {
                      setState(() {
                        _amount.text = amount;
                        _error = null;
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: Sp.x5),
            Text('Note', style: text.titleMedium),
            const SizedBox(height: Sp.x2),
            EthioTextField(
              controller: _note,
              hint: 'What is this for? (optional)',
              maxLength: 80,
            ),
            if (_error != null) ...[
              const SizedBox(height: Sp.x3),
              Text(
                _error!,
                style: text.bodySmall?.copyWith(color: EthioColors.danger),
              ),
            ],
            const SizedBox(height: Sp.x8),
            EthioButton(
              label: 'Continue',
              icon: Icons.arrow_forward_rounded,
              onPressed: _continue,
            ),
            const SizedBox(height: Sp.x3),
            Center(
              child: Text(
                'Transfers to EthioChat contacts are instant.',
                style: text.labelSmall?.copyWith(color: pal.textTertiary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
