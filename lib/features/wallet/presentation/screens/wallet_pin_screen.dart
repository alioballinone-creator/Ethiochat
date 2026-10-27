import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/design.dart';
import '../../../../core/platform/secure_screen.dart';
import '../../application/wallet_providers.dart';
import '../../domain/entities/wallet_entry.dart';

/// Full-screen PIN pad. With a [request] it confirms a payment; without one it
/// creates or replaces the local wallet PIN.
class WalletPinScreen extends ConsumerStatefulWidget {
  const WalletPinScreen({super.key, this.request});

  final PinRequest? request;

  @override
  ConsumerState<WalletPinScreen> createState() => _WalletPinScreenState();
}

class _WalletPinScreenState extends ConsumerState<WalletPinScreen> {
  String _pin = '';
  String? _firstPin;
  bool _busy = false;
  bool _checkingPin = true;
  bool _hasPin = false;
  String? _error;

  bool get _settingPin => widget.request == null || !_hasPin;

  String get _title {
    if (widget.request == null) return 'Wallet PIN';
    if (!_hasPin) return 'Create your wallet PIN';
    return widget.request!.title;
  }

  String get _hint {
    if (widget.request == null) {
      return _firstPin == null ? 'Choose a 6-digit PIN' : 'Enter it again';
    }
    if (!_hasPin) {
      return _firstPin == null
          ? 'Choose a 6-digit PIN to secure payments'
          : 'Enter the same PIN again';
    }
    return 'Enter your 6-digit PIN to confirm';
  }

  @override
  void initState() {
    super.initState();
    _loadPinState();
  }

  Future<void> _loadPinState() async {
    var hasPin = false;
    try {
      hasPin = await ref.read(walletPinStoreProvider).hasPin();
    } catch (_) {
      // Secure preferences are unavailable in widget tests and some OEM builds.
    }
    if (!mounted) return;
    setState(() {
      _hasPin = hasPin;
      _checkingPin = false;
    });
  }

  void _feedback(String message) {
    setState(() => _error = message);
    HapticFeedback.heavyImpact();
  }

  Future<void> _onDigit(String digit) async {
    if (_busy || _pin.length >= 6) return;
    await HapticFeedback.selectionClick();
    setState(() {
      _pin += digit;
      _error = null;
    });
    if (_pin.length == 6) {
      await Future<void>.delayed(const Duration(milliseconds: 90));
      if (mounted) await _submit();
    }
  }

  void _backspace() {
    if (_pin.isEmpty || _busy) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _submit() async {
    if (_busy) return;
    final entered = _pin;
    if (_settingPin) {
      if (_firstPin == null) {
        setState(() {
          _firstPin = entered;
          _pin = '';
        });
        return;
      }
      if (_firstPin != entered) {
        setState(() {
          _pin = '';
          _firstPin = null;
        });
        _feedback('The PINs did not match. Try again.');
        return;
      }
      setState(() => _busy = true);
      await ref.read(walletPinStoreProvider).setPin(entered);
      if (!mounted) return;
      ref.invalidate(walletHasPinProvider);
      if (widget.request == null) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Wallet PIN updated.')),
        );
        context.pop();
        return;
      }
      setState(() {
        _hasPin = true;
        _busy = false;
        _pin = '';
        _firstPin = null;
      });
      await _execute();
      return;
    }

    setState(() => _busy = true);
    final ok = await ref.read(walletPinStoreProvider).verify(entered);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _busy = false;
        _pin = '';
      });
      _feedback('That PIN is not correct.');
      return;
    }
    await _execute();
  }

  Future<void> _execute() async {
    final request = widget.request;
    if (request == null) return;
    final repo = ref.read(walletRepositoryProvider);
    final result = switch (request.type) {
      WalletTxType.transfer => await repo.sendMoney(
          recipient: request.recipient ?? 'EthioChat user',
          amountMinor: request.amountMinor,
          note: request.note,
        ),
      WalletTxType.bill => await repo.payBill(
          provider: request.provider ?? 'Biller',
          accountRef: request.accountRef ?? '',
          amountMinor: request.amountMinor,
        ),
      WalletTxType.redPacket => await repo.sendRedPacket(
          totalMinor: request.amountMinor,
          count: request.redPacketCount,
          note: request.note ?? 'Best wishes',
        ),
      WalletTxType.topUp => await repo.topUp(
          amountMinor: request.amountMinor,
          provider: request.provider ?? 'Telebirr',
        ),
      WalletTxType.receive => await repo.receive(
          sender: request.recipient ?? 'EthioChat user',
          amountMinor: request.amountMinor,
          note: request.note,
        ),
    };
    if (!mounted) return;
    if (result.failureOrNull case final failure?) {
      setState(() {
        _busy = false;
        _pin = '';
      });
      _feedback(failure.message);
      return;
    }
    final txn = result.valueOrNull!;
    final receipt = WalletReceipt(
      title: request.title,
      amountMinor: request.amountMinor,
      type: request.type,
      reference: txn.id.replaceAll('-', '').substring(0, 10).toUpperCase(),
      createdAt: txn.createdAt,
      counterparty: request.recipient ?? request.provider,
      note: request.note,
    );
    context.pushReplacement('/wallet/receipt', extra: receipt);
  }

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);
    final text = Theme.of(context).textTheme;

    return SecureScreenScope(
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          leading: IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close_rounded),
            onPressed: () => context.pop(),
          ),
        ),
        body: SafeArea(
          child: _checkingPin
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: Sp.x4),
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: pal.chip,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.lock_outline_rounded, size: 30),
                      ),
                      const SizedBox(height: Sp.x4),
                      Text(_title,
                          style: text.titleLarge, textAlign: TextAlign.center),
                      const SizedBox(height: Sp.x1),
                      Padding(
                        padding: Sp.screen,
                        child: Text(
                          _hint,
                          style: text.bodySmall?.copyWith(
                            color: pal.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: Sp.x5),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < 6; i++)
                            AnimatedContainer(
                              duration: Dur.fast,
                              margin:
                                  const EdgeInsets.symmetric(horizontal: Sp.x1),
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: i < _pin.length
                                    ? EthioColors.goldDeep
                                    : pal.chip,
                                border: Border.all(color: pal.line),
                              ),
                            ),
                        ],
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: Sp.x3),
                        Text(
                          _error!,
                          style: text.bodySmall
                              ?.copyWith(color: EthioColors.danger),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: Sp.x4),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 340),
                        child: GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 3,
                          childAspectRatio: 1.4,
                          padding: Sp.screen,
                          children: [
                            for (var n = 1; n <= 9; n++)
                              _PinKey(
                                label: '$n',
                                onTap: () => _onDigit('$n'),
                              ),
                            const SizedBox.shrink(),
                            _PinKey(label: '0', onTap: () => _onDigit('0')),
                            _PinKey(
                              icon: Icons.backspace_outlined,
                              onTap: _backspace,
                              semanticLabel: 'Delete',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: Sp.x6),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _PinKey extends StatelessWidget {
  const _PinKey({
    required this.onTap,
    this.label,
    this.icon,
    this.semanticLabel,
  });

  final String? label;
  final IconData? icon;
  final String? semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);
    return Semantics(
      button: true,
      label: semanticLabel ?? label,
      child: Padding(
        padding: const EdgeInsets.all(Sp.x2),
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: Rad.r18,
          child: InkWell(
            onTap: onTap,
            borderRadius: Rad.r18,
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: Rad.r18,
                border: Border.all(color: pal.line),
              ),
              child: icon != null
                  ? Icon(icon, size: 22)
                  : Text(
                      label!,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
