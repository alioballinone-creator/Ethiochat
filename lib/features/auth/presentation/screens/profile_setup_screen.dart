import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/design.dart';

/// Profile setup — shown once after OTP verification.
///
/// Avatar, display name and an optional bio. Everything scrolls, the primary
/// action stays above the keyboard via [SafeArea] + [ListView].
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _name = TextEditingController();
  final _bio = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  bool get _valid => _name.text.trim().length >= 2;

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        automaticallyImplyLeading: false,
        title: Text('Your profile', style: text.headlineMedium),
      ),
      body: SafeArea(
        child: ListView(
          padding: Sp.screen.copyWith(top: Sp.x4, bottom: Sp.x6),
          children: [
            Center(
              child: Stack(
                children: [
                  const EthioAvatar(name: 'New user', size: 104),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: EthioColors.goldGradient,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          width: 3,
                        ),
                      ),
                      child: const Icon(
                        Icons.camera_alt_outlined,
                        size: 18,
                        color: EthioColors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Sp.x3),
            Center(
              child: TextButton(
                onPressed: () {},
                child: const Text('Add a photo'),
              ),
            ),
            const SizedBox(height: Sp.x4),
            Text('Display name', style: text.titleMedium),
            const SizedBox(height: Sp.x2),
            EthioTextField(
              controller: _name,
              hint: 'e.g. Abebe Kebede',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: Sp.x4),
            Text('About', style: text.titleMedium),
            const SizedBox(height: Sp.x2),
            EthioTextField(
              controller: _bio,
              hint: 'A short line about you',
              maxLength: 80,
            ),
            const SizedBox(height: Sp.x4),
            Container(
              padding: const EdgeInsets.all(Sp.x4),
              decoration: BoxDecoration(
                color: pal.chip,
                borderRadius: Rad.r14,
                border: Border.all(color: pal.line),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lock_outline_rounded, size: 18),
                  const SizedBox(width: Sp.x2),
                  Expanded(
                    child: Text(
                      'Your name and photo are visible to people you chat '
                      'with. You can change them later in Settings.',
                      style: text.bodySmall?.copyWith(color: pal.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Sp.x6),
            EthioButton(
              label: 'Continue',
              onPressed: _valid ? () => context.go('/chats') : null,
            ),
          ],
        ),
      ),
    );
  }
}
