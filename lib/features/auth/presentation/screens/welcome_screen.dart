import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/design.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../profile/application/profile_controller.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  Future<void> _setLanguage(
    BuildContext context,
    WidgetRef ref,
    String label,
    Locale? locale,
  ) async {
    if (locale == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label is coming soon.')),
      );
      return;
    }
    await ref.read(appSettingsProvider.notifier).setLocale(locale);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pal = EthioPalette.of(context);
    final settings = ref.watch(appSettingsProvider);
    final profile = ref.watch(userProfileProvider);

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
                  _LanguageChip(
                    label: 'English',
                    selected: settings.locale.languageCode == 'en',
                    onTap: () => _setLanguage(
                      context,
                      ref,
                      'English',
                      const Locale('en'),
                    ),
                  ),
                  _LanguageChip(
                    label: 'አማርኛ',
                    selected: settings.locale.languageCode == 'am',
                    onTap: () => _setLanguage(
                      context,
                      ref,
                      'አማርኛ',
                      const Locale('am'),
                    ),
                  ),
                  _LanguageChip(
                    label: 'Afaan Oromoo',
                    onTap: () =>
                        _setLanguage(context, ref, 'Afaan Oromoo', null),
                  ),
                  _LanguageChip(
                    label: 'ትግርኛ',
                    onTap: () => _setLanguage(context, ref, 'ትግርኛ', null),
                  ),
                  _LanguageChip(
                    label: 'Soomaali',
                    onTap: () => _setLanguage(context, ref, 'Soomaali', null),
                  ),
                ],
              ),
              const SizedBox(height: Sp.x8),
              EthioButton(
                label: profile.isComplete ? 'Continue' : 'Get started',
                onPressed: () => context.go(
                  profile.isComplete ? '/chats' : '/auth/phone',
                ),
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
  const _LanguageChip({
    required this.label,
    this.selected = false,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Sp.x4,
            vertical: Sp.x2 + 2,
          ),
          decoration: BoxDecoration(
            color: selected ? EthioColors.gold : pal.chip,
            borderRadius: BorderRadius.circular(12),
            border: selected ? null : Border.all(color: pal.line),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: selected
                      ? EthioColors.black
                      : Theme.of(context).colorScheme.onSurface,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
          ),
        ),
      ),
    );
  }
}
