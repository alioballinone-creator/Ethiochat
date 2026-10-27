import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/feature_flags.dart';
import '../../../../core/design/design.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key, this.forPayment = false});

  final bool forPayment;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _manual = TextEditingController();
  var _flash = false;
  var _handling = false;

  @override
  void dispose() {
    _manual.dispose();
    super.dispose();
  }

  void _openCode(String raw) {
    final value = raw.trim();
    if (value.isEmpty) {
      _feedback('Enter or scan an EthioChat code.');
      return;
    }
    final uri = Uri.tryParse(value);
    final isPay = widget.forPayment ||
        value.startsWith('ethiochat://pay') ||
        value.toLowerCase().startsWith('pay:');
    if (!isPay) {
      _feedback('Code recognised. Opening a new chat.');
      context.push('/new-chat');
      return;
    }
    if (!FeatureFlags.wallet) {
      _feedback('Wallet payments are disabled in this release.');
      return;
    }
    var recipient = 'EthioChat merchant';
    if (uri != null && uri.pathSegments.isNotEmpty) {
      recipient = uri.pathSegments.first;
    }
    final amount = uri?.queryParameters['amount'];
    final suffix = amount == null ? '' : '&amount=$amount';
    context.push(
      '/wallet/send?to=${Uri.encodeComponent(recipient)}$suffix',
    );
  }

  Future<void> _fromGallery() async {
    setState(() => _handling = true);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() => _handling = false);
    _openCode('ethiochat://pay/EC-884210?amount=12550');
  }

  void _feedback(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: EthioColors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Sp.x4,
                vertical: Sp.x2,
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Close scanner',
                    icon: const Icon(
                      Icons.close_rounded,
                      color: EthioColors.cream,
                    ),
                    onPressed: () => context.pop(),
                  ),
                  Expanded(
                    child: Text(
                      widget.forPayment ? 'Scan to pay' : 'Scan code',
                      textAlign: TextAlign.center,
                      style: text.titleMedium?.copyWith(
                        color: EthioColors.cream,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: _flash ? 'Turn flash off' : 'Turn flash on',
                    icon: Icon(
                      _flash ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                      color: EthioColors.cream,
                    ),
                    onPressed: () => setState(() => _flash = !_flash),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF1B1B1B),
                          _flash
                              ? const Color(0xFF36332B)
                              : const Color(0xFF0B0B0B),
                        ],
                      ),
                    ),
                  ),
                  Center(
                    child: Container(
                      width: 240,
                      height: 240,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: EthioColors.cream.withValues(alpha: 0.25),
                          width: 2,
                        ),
                        borderRadius: Rad.r24,
                      ),
                      child: Stack(
                        children: [
                          for (final alignment in const [
                            Alignment.topLeft,
                            Alignment.topRight,
                            Alignment.bottomLeft,
                            Alignment.bottomRight,
                          ])
                            Align(
                              alignment: alignment,
                              child: Container(
                                width: 34,
                                height: 34,
                                margin: const EdgeInsets.all(Sp.x1),
                                decoration: BoxDecoration(
                                  border: Border(
                                    top: alignment.y < 0
                                        ? const BorderSide(
                                            color: EthioColors.gold,
                                            width: 3,
                                          )
                                        : BorderSide.none,
                                    bottom: alignment.y > 0
                                        ? const BorderSide(
                                            color: EthioColors.gold,
                                            width: 3,
                                          )
                                        : BorderSide.none,
                                    left: alignment.x < 0
                                        ? const BorderSide(
                                            color: EthioColors.gold,
                                            width: 3,
                                          )
                                        : BorderSide.none,
                                    right: alignment.x > 0
                                        ? const BorderSide(
                                            color: EthioColors.gold,
                                            width: 3,
                                          )
                                        : BorderSide.none,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: Sp.x6,
                    child: Column(
                      children: [
                        Icon(
                          Icons.qr_code_scanner_rounded,
                          size: 34,
                          color: EthioColors.cream.withValues(alpha: 0.8),
                        ),
                        const SizedBox(height: Sp.x2),
                        Text(
                          'Align the code inside the frame',
                          style: text.bodySmall?.copyWith(
                            color: EthioColors.cream.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                color: EthioColors.blackSoft,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              padding: Sp.screen.copyWith(top: Sp.x4, bottom: Sp.x4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Or enter a code',
                    style: text.labelSmall?.copyWith(
                      color: EthioColors.cream.withValues(alpha: 0.65),
                    ),
                  ),
                  const SizedBox(height: Sp.x2),
                  TextField(
                    controller: _manual,
                    style: const TextStyle(color: EthioColors.cream),
                    decoration: InputDecoration(
                      hintText: 'ethiochat://pay/...',
                      hintStyle: TextStyle(
                        color: EthioColors.cream.withValues(alpha: 0.35),
                      ),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.06),
                      border: OutlineInputBorder(
                        borderRadius: Rad.r14,
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: IconButton(
                        tooltip: 'Open code',
                        icon: const Icon(
                          Icons.arrow_forward_rounded,
                          color: EthioColors.gold,
                        ),
                        onPressed: () => _openCode(_manual.text),
                      ),
                    ),
                    onSubmitted: _openCode,
                  ),
                  const SizedBox(height: Sp.x3),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          onPressed: _handling ? null : _fromGallery,
                          icon: _handling
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.photo_library_outlined),
                          label: const Text('From photos'),
                          style: TextButton.styleFrom(
                            foregroundColor: EthioColors.cream,
                          ),
                        ),
                      ),
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () {
                            Clipboard.setData(
                              const ClipboardData(
                                text: 'ethiochat://pay/EC-884210',
                              ),
                            );
                            _feedback('Sample merchant code copied.');
                          },
                          icon: const Icon(Icons.copy_rounded),
                          label: const Text('Sample code'),
                          style: TextButton.styleFrom(
                            foregroundColor: EthioColors.cream,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Sp.x1),
                  Center(
                    child: TextButton.icon(
                      onPressed: () => context.push('/me/qr'),
                      icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                      label: const Text('Show my QR code'),
                      style: TextButton.styleFrom(
                        foregroundColor: EthioColors.gold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
