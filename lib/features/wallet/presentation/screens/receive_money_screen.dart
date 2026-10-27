import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/design/design.dart';
import '../../../../core/utils/money_format.dart';
import '../../../profile/application/profile_controller.dart';

class ReceiveMoneyScreen extends ConsumerStatefulWidget {
  const ReceiveMoneyScreen({super.key});

  @override
  ConsumerState<ReceiveMoneyScreen> createState() => _ReceiveMoneyScreenState();
}

class _ReceiveMoneyScreenState extends ConsumerState<ReceiveMoneyScreen> {
  final _amount = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _feedback(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _copy() async {
    final profile = ref.read(userProfileProvider);
    final amount = parseEtbToMinor(_amount.text);
    final suffix = amount > 0 ? '?amount=$amount' : '';
    await Clipboard.setData(
      ClipboardData(
        text: 'Pay ${profile.name} on EthioChat: '
            'ethiochat://pay/${profile.ethioId}$suffix',
      ),
    );
    if (mounted) _feedback('Payment link copied.');
  }

  void _shareInChat() {
    final profile = ref.read(userProfileProvider);
    context.push('/new-chat?share=ethiochat://pay/${profile.ethioId}');
  }

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);
    final text = Theme.of(context).textTheme;
    final profile = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text('Receive', style: text.headlineMedium),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: Sp.screen.copyWith(top: Sp.x4, bottom: Sp.x8),
          children: [
            Container(
              padding: const EdgeInsets.all(Sp.x5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: Rad.r24,
                border: Border.all(color: pal.line),
              ),
              child: Column(
                children: [
                  QrImageView(
                    data: 'ethiochat://pay/${profile.ethioId}'
                        '${parseEtbToMinor(_amount.text) > 0 ? '?amount=${parseEtbToMinor(_amount.text)}' : ''}',
                    version: QrVersions.auto,
                    size: 220,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: EthioColors.black,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: EthioColors.black,
                    ),
                  ),
                  const SizedBox(height: Sp.x4),
                  Text(
                    profile.name,
                    textAlign: TextAlign.center,
                    style: text.titleLarge?.copyWith(color: EthioColors.black),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Ethio ID · ${profile.ethioId}',
                    style: text.labelSmall?.copyWith(
                      color: const Color(0xFF6E6550),
                    ),
                  ),
                  const SizedBox(height: Sp.x4),
                  Text(
                    parseEtbToMinor(_amount.text) > 0
                        ? formatEtb(parseEtbToMinor(_amount.text))
                        : 'Any amount',
                    style: text.titleMedium?.copyWith(
                      color: EthioColors.black,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Sp.x5),
            Text('Request a specific amount', style: text.titleMedium),
            const SizedBox(height: Sp.x2),
            EthioTextField(
              controller: _amount,
              hint: '0.00 (optional)',
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              prefix: Padding(
                padding: const EdgeInsets.only(left: Sp.x4, right: Sp.x2),
                child: Center(widthFactor: 1, child: Text('ETB')),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: Sp.x5),
            EthioButton(
              label: 'Share payment link',
              icon: Icons.share_outlined,
              onPressed: _copy,
            ),
            const SizedBox(height: Sp.x3),
            EthioButton(
              label: 'Send request in a chat',
              kind: EthioButtonKind.secondary,
              icon: Icons.chat_bubble_outline_rounded,
              onPressed: _shareInChat,
            ),
            const SizedBox(height: Sp.x4),
            Center(
              child: Text(
                'Only share this code with people you trust.',
                style: text.labelSmall?.copyWith(color: pal.textTertiary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
