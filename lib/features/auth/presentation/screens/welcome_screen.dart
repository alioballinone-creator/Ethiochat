import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/design.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: Sp.screen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const EthioMark(size: 80),
              const SizedBox(height: Sp.x4),
              Center(
                child: Text(
                  'Your world, one app.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: pal.textSecondary,
                      ),
                ),
              ),
              const Spacer(),
              Text(
                'Language',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: Sp.x3),
              Wrap(
                spacing: Sp.x2,
                runSpacing: Sp.x2,
                children: [
                  _LanguageChip(label: 'English', selected: true),
                  _LanguageChip(label: 'አማርኛ'),
                  _LanguageChip(label: 'Afaan Oromoo'),
                  _LanguageChip(label: 'ትግርኛ'),
                  _LanguageChip(label: 'Soomaali'),
                ],
              ),
              const SizedBox(height: Sp.x8),
              EthioButton(
                label: 'Get started',
                onPressed: () => context.go('/auth/phone'),
              ),
              const SizedBox(height: Sp.x4),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageChip extends StatelessWidget {
  const _LanguageChip({required this.label, this.selected = false});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Sp.x4, vertical: Sp.x2 + 2),
      decoration: BoxDecoration(
        color: selected ? EthioColors.gold : pal.chip,
        borderRadius: BorderRadius.circular(12),
        border: selected
            ? null
            : Border.all(color: pal.line),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: selected ? EthioColors.black : Theme.of(context).colorScheme.onSurface,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
      ),
    );
  }
}
