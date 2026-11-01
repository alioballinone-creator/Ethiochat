import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../config/env.dart';
import '../design/design.dart';

/// Shown by release builds when the required authentication backend is not
/// compiled in. It deliberately offers no way to bypass authentication.
class BackendConfigurationScreen extends StatelessWidget {
  const BackendConfigurationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: Sp.screen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.settings_suggest_outlined,
                size: 56,
                color: EthioColors.goldDeep,
              ),
              const SizedBox(height: Sp.x4),
              Text(
                kDebugMode
                    ? 'EthioChat is not configured'
                    : 'EthioChat is temporarily unavailable',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: Sp.x3),
              Text(
                kDebugMode
                    ? 'This release was built without the Supabase '
                        'authentication backend. Sign-in is disabled so the '
                        'app cannot fall back to an insecure local account.'
                    : 'Please try again later.',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: pal.textSecondary),
              ),
              if (kDebugMode) ...[
                const SizedBox(height: Sp.x4),
                Text(
                  'Missing build configuration: ${Env.missingBackendConfig}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: pal.textTertiary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
