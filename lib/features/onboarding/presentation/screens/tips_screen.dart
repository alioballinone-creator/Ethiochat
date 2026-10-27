import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/design/design.dart';

class TipsScreen extends StatefulWidget {
  const TipsScreen({super.key});

  @override
  State<TipsScreen> createState() => _TipsScreenState();
}

class _TipsScreenState extends State<TipsScreen> {
  final _controller = PageController();
  var _index = 0;

  static const _tips = [
    (
      Icons.bolt_rounded,
      'Works when the network does not',
      'Messages are saved on your phone first and sent automatically when you '
          'reconnect. One tick means it is waiting.',
    ),
    (
      Icons.lock_outline_rounded,
      'Your private conversations stay private',
      'Chats and calls are encrypted in transit. Turn on two-step verification '
          'from Settings for extra protection.',
    ),
    (
      Icons.wifi_tethering_rounded,
      'Channels and businesses you trust',
      'Look for the gold verified badge before you trust an official account. '
          'Follow channels without sharing your phone number.',
    ),
    (
      Icons.account_balance_wallet_outlined,
      'Payments with a receipt in chat',
      'Wallet payments keep a receipt with the conversation. Never share your '
          'PIN — EthioChat will never ask for it.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding.tipsSeen', true);
    } catch (_) {
      // The tips can still be dismissed if preferences are unavailable.
    }
    if (!mounted) return;
    context.go('/chats');
  }

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);
    final text = Theme.of(context).textTheme;
    final tip = _tips[_index];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: Sp.screen,
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _finish,
                  child: const Text('Skip'),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _tips.length,
                  onPageChanged: (index) => setState(() => _index = index),
                  itemBuilder: (context, index) {
                    final item = _tips[index];
                    return Center(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 148,
                              height: 148,
                              decoration: BoxDecoration(
                                color: EthioColors.gold.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                item.$1,
                                size: 68,
                                color: EthioColors.goldDeep,
                              ),
                            ),
                            const SizedBox(height: Sp.x8),
                            Text(
                              item.$2,
                              textAlign: TextAlign.center,
                              style: text.headlineMedium,
                            ),
                            const SizedBox(height: Sp.x3),
                            Text(
                              item.$3,
                              textAlign: TextAlign.center,
                              style: text.bodyLarge?.copyWith(
                                color: pal.textSecondary,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _tips.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: i == _index ? 22 : 7,
                      height: 7,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: i == _index ? EthioColors.goldDeep : pal.line,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: Sp.x6),
              EthioButton(
                label: _index == _tips.length - 1 ? 'Start chatting' : 'Next',
                icon: Icons.arrow_forward_rounded,
                onPressed: () {
                  if (_index == _tips.length - 1) {
                    _finish();
                  } else {
                    _controller.nextPage(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                    );
                  }
                },
              ),
              const SizedBox(height: Sp.x2),
              Text(
                tip.$2,
                style: text.labelSmall?.copyWith(color: pal.textTertiary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
