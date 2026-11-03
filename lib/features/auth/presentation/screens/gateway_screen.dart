import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/design.dart';
import '../../application/auth_providers.dart';

enum _GatewayMode { user, admin }

/// Hidden staff/user gateway reached by tapping the welcome logo five times.
///
/// Passwords are never stored by the app. Supabase Auth verifies credentials
/// and the admin role is checked by the server-side `is_admin()` RPC.
class GatewayScreen extends ConsumerStatefulWidget {
  const GatewayScreen({super.key});

  @override
  ConsumerState<GatewayScreen> createState() => _GatewayScreenState();
}

class _GatewayScreenState extends ConsumerState<GatewayScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  _GatewayMode _mode = _GatewayMode.user;
  bool _submitting = false;
  bool _resetting = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_submitting) return;
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _error = 'Enter your email and password.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final result = await ref.read(authRepositoryProvider).signInWithPassword(
          email: email,
          password: password,
          requireAdmin: _mode == _GatewayMode.admin,
        );

    if (!mounted) return;
    final failure = result.failureOrNull;
    if (failure != null) {
      setState(() {
        _submitting = false;
        _error = failure.messageFor(
          Localizations.localeOf(context).languageCode,
        );
      });
      return;
    }

    setState(() => _submitting = false);
    context.go('/chats');
  }

  Future<void> _changePassword() async {
    if (_resetting) return;
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        _error = 'Enter the email address for your account first.';
      });
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change password'),
        content: Text(
          'We will email a secure password reset link to $email. '
          'Open the link to set a new password.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Send link'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _resetting = true;
      _error = null;
    });
    final result =
        await ref.read(authRepositoryProvider).sendPasswordResetEmail(email);
    if (!mounted) return;
    setState(() => _resetting = false);

    final failure = result.failureOrNull;
    if (failure != null) {
      setState(() {
        _error = failure.messageFor(
          Localizations.localeOf(context).languageCode,
        );
      });
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Password reset link sent to $email. Check your inbox.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);
    final text = Theme.of(context).textTheme;
    final admin = _mode == _GatewayMode.admin;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text('Gateway', style: text.headlineMedium),
      ),
      body: SafeArea(
        child: ListView(
          padding: Sp.screen.copyWith(top: Sp.x2, bottom: Sp.x8),
          children: [
            const Center(child: EthioMark(size: 72)),
            const SizedBox(height: Sp.x3),
            Center(
              child: Text(
                admin ? 'Admin access' : 'Account access',
                style: text.titleLarge,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: Sp.x1),
            Center(
              child: Text(
                'Sign in with the account issued to you by EthioChat.',
                style: text.bodySmall?.copyWith(color: pal.textSecondary),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: Sp.x5),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _ModeCard(
                    label: 'User login',
                    icon: Icons.person_outline_rounded,
                    selected: !admin,
                    onTap: () => setState(() => _mode = _GatewayMode.user),
                  ),
                ),
                const SizedBox(width: Sp.x3),
                Expanded(
                  child: _ModeCard(
                    label: 'Admin login',
                    icon: Icons.admin_panel_settings_outlined,
                    selected: admin,
                    onTap: () => setState(() => _mode = _GatewayMode.admin),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Sp.x5),
            Text('Email or username', style: text.titleMedium),
            const SizedBox(height: Sp.x2),
            EthioTextField(
              controller: _email,
              hint: 'you@example.com',
              keyboardType: TextInputType.emailAddress,
            ),
            Padding(
              padding: const EdgeInsets.only(top: Sp.x1, left: Sp.x1),
              child: Text(
                'Use the email address on your account.',
                style: text.labelSmall?.copyWith(color: pal.textTertiary),
              ),
            ),
            const SizedBox(height: Sp.x4),
            Text('Password', style: text.titleMedium),
            const SizedBox(height: Sp.x2),
            EthioTextField(
              controller: _password,
              hint: 'Your password',
              obscureText: _obscurePassword,
              suffix: IconButton(
                tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                onPressed: () => setState(
                  () => _obscurePassword = !_obscurePassword,
                ),
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: Sp.x4),
              _ErrorBanner(message: _error!),
            ],
            const SizedBox(height: Sp.x5),
            EthioButton(
              label: admin ? 'Sign in as admin' : 'Sign in',
              loading: _submitting,
              onPressed: _submitting ? null : _signIn,
            ),
            Center(
              child: TextButton(
                onPressed: _resetting ? null : _changePassword,
                child: Text(
                  _resetting ? 'Sending reset link…' : 'Change password',
                ),
              ),
            ),
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
                      admin
                          ? 'Admin access is verified on the server. A normal '
                              'account cannot open the admin gateway.'
                          : 'Passwords are handled by Supabase Auth and are '
                              'never stored in the app.',
                      style: text.bodySmall?.copyWith(color: pal.textSecondary),
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

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);
    final text = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: Rad.r14,
        child: AnimatedContainer(
          duration: Dur.fast,
          padding: const EdgeInsets.symmetric(
            horizontal: Sp.x3,
            vertical: Sp.x3,
          ),
          decoration: BoxDecoration(
            color:
                selected ? EthioColors.gold.withValues(alpha: 0.14) : pal.chip,
            borderRadius: Rad.r14,
            border: Border.all(
              color: selected ? EthioColors.gold : pal.line,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 24,
                color: selected ? EthioColors.gold : pal.textSecondary,
              ),
              const SizedBox(height: Sp.x2),
              Text(
                label,
                textAlign: TextAlign.center,
                style: text.labelMedium?.copyWith(
                  color: selected
                      ? Theme.of(context).colorScheme.onSurface
                      : pal.textSecondary,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Sp.x3),
      decoration: BoxDecoration(
        color: EthioColors.danger.withValues(alpha: 0.08),
        borderRadius: Rad.r14,
        border: Border.all(
          color: EthioColors.danger.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 20,
            color: EthioColors.danger,
          ),
          const SizedBox(width: Sp.x2),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: EthioColors.danger,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
