import 'package:flutter/material.dart';

import '../../../../core/design/design.dart';

/// My QR code — scan-to-add card.
class MyQrScreen extends StatelessWidget {
  const MyQrScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text('My QR code', style: text.headlineMedium),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: Sp.screen.copyWith(top: Sp.x6, bottom: Sp.x8),
          children: [
            Container(
              padding: const EdgeInsets.all(Sp.x5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: Rad.r24,
                border: Border.all(color: pal.line),
                boxShadow: [
                  BoxShadow(
                    color: EthioColors.goldDeep.withValues(alpha: 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                    spreadRadius: -12,
                  ),
                ],
              ),
              child: Column(
                children: [
                  const _QrCode(size: 220),
                  const SizedBox(height: Sp.x4),
                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(
                          text: 'Ethio',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w500,
                            color: EthioColors.black,
                          ),
                        ),
                        TextSpan(
                          text: 'Chat',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w600,
                            color: EthioColors.goldDeep,
                          ),
                        ),
                      ],
                    ),
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(height: Sp.x1),
                  Text(
                    'Abebe Kebede',
                    style: text.titleLarge?.copyWith(color: EthioColors.black),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Ethio ID · EC-123456',
                    style: text.labelSmall?.copyWith(
                      color: const Color(0xFF6E6550),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Sp.x5),
            Container(
              padding: const EdgeInsets.all(Sp.x4),
              decoration: BoxDecoration(
                color: pal.chip,
                borderRadius: Rad.r14,
                border: Border.all(color: pal.line),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline_rounded, size: 18),
                  const SizedBox(width: Sp.x2),
                  Expanded(
                    child: Text(
                      'Keep the code inside the frame. Increase your screen '
                      'brightness so friends can scan it easily.',
                      style: text.bodySmall
                          ?.copyWith(color: pal.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Sp.x6),
            EthioButton(
              label: 'Share code',
              icon: Icons.share_outlined,
              onPressed: () {},
            ),
            const SizedBox(height: Sp.x3),
            EthioButton(
              label: 'Save to gallery',
              kind: EthioButtonKind.secondary,
              icon: Icons.download_outlined,
              onPressed: () {},
            ),
            const SizedBox(height: Sp.x4),
            Center(
              child: TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                label: const Text('Scan a code instead'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Stylised, deterministic QR-style graphic. It is intentionally decorative
/// until the real payload encoder is wired to the backend.
class _QrCode extends StatelessWidget {
  const _QrCode({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _QrPainter()),
    );
  }
}

class _QrPainter extends CustomPainter {
  static const _modules = 25;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / _modules;
    final dark = Paint()..color = EthioColors.black;
    final light = Paint()..color = Colors.white;

    canvas.drawRect(Offset.zero & size, light);

    bool isFinder(int x, int y) {
      bool inBox(int ox, int oy) =>
          x >= ox && x < ox + 7 && y >= oy && y < oy + 7;
      return inBox(0, 0) || inBox(_modules - 7, 0) || inBox(0, _modules - 7);
    }

    for (var y = 0; y < _modules; y++) {
      for (var x = 0; x < _modules; x++) {
        if (isFinder(x, y)) continue;
        // Deterministic pseudo-random fill so the pattern is stable.
        final on = ((x * 7 + y * 13 + x * y * 3) % 5) < 2;
        if (on) {
          canvas.drawRect(
            Rect.fromLTWH(x * cell, y * cell, cell, cell),
            dark,
          );
        }
      }
    }

    void finder(int ox, int oy) {
      canvas.drawRect(
        Rect.fromLTWH(ox * cell, oy * cell, 7 * cell, 7 * cell),
        dark,
      );
      canvas.drawRect(
        Rect.fromLTWH(
          (ox + 1) * cell,
          (oy + 1) * cell,
          5 * cell,
          5 * cell,
        ),
        light,
      );
      canvas.drawRect(
        Rect.fromLTWH(
          (ox + 2) * cell,
          (oy + 2) * cell,
          3 * cell,
          3 * cell,
        ),
        dark,
      );
    }

    finder(0, 0);
    finder(_modules - 7, 0);
    finder(0, _modules - 7);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
