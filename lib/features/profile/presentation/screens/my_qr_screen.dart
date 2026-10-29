import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/design/design.dart';
import '../../../../core/errors/failure.dart';
import '../../application/profile_controller.dart';

/// My QR code — scan-to-add card.
class MyQrScreen extends ConsumerStatefulWidget {
  const MyQrScreen({super.key});

  @override
  ConsumerState<MyQrScreen> createState() => _MyQrScreenState();
}

class _MyQrScreenState extends ConsumerState<MyQrScreen> {
  final _qrKey = GlobalKey();

  String get _inviteText {
    final profile = ref.read(userProfileProvider);
    return 'Add ${profile.name} on EthioChat — code ${profile.ethioId}';
  }

  void _feedback(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _share() async {
    await Clipboard.setData(ClipboardData(text: _inviteText));
    _feedback('Invite copied. Paste it in any chat to share your code.');
  }

  Future<void> _save() async {
    try {
      final boundary =
          _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) {
        _feedback('Could not render the QR code.');
        return;
      }
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/ethiochat-qr.png');
      await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
      _feedback('QR code saved to ${file.path}');
    } catch (error) {
      _feedback(
        mapError(error).messageFor(
          Localizations.localeOf(context).languageCode,
        ),
      );
    }
  }

  void _scan() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Sp.x4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Scan a code',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: Sp.x2),
              const Text(
                'Camera scanning is available on a device. Open the camera, '
                'point it at an EthioChat QR code and the contact is added '
                'automatically.',
              ),
              const SizedBox(height: Sp.x4),
              EthioButton(
                label: 'Got it',
                onPressed: () => Navigator.pop(sheetContext),
              ),
            ],
          ),
        ),
      ),
    );
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
                  RepaintBoundary(
                    key: _qrKey,
                    child: Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(Sp.x2),
                      child: const _QrCode(size: 220),
                    ),
                  ),
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
                      style: text.bodySmall?.copyWith(color: pal.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Sp.x6),
            EthioButton(
              label: 'Share code',
              icon: Icons.share_outlined,
              onPressed: _share,
            ),
            const SizedBox(height: Sp.x3),
            EthioButton(
              label: 'Save to gallery',
              kind: EthioButtonKind.secondary,
              icon: Icons.download_outlined,
              onPressed: _save,
            ),
            const SizedBox(height: Sp.x4),
            Center(
              child: TextButton.icon(
                onPressed: _scan,
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
