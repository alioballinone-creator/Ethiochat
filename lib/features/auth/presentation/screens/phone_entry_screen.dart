import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/env.dart';
import '../../../../core/design/design.dart';

class PhoneEntryScreen extends StatefulWidget {
  const PhoneEntryScreen({super.key});

  @override
  State<PhoneEntryScreen> createState() => _PhoneEntryScreenState();
}

class _PhoneEntryScreenState extends State<PhoneEntryScreen> {
  final _controller = TextEditingController();
  bool _sending = false;
  bool get _isValid {
    final text = _controller.text.replaceAll(RegExp(r'[^0-9]'), '');
    return text.length == 9 && (text.startsWith('9') || text.startsWith('7'));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _e164 {
    final digits = _controller.text.replaceAll(RegExp(r'[^0-9]'), '');
    return '+251$digits';
  }

  Future<void> _sendCode() async {
    if (!_isValid || _sending) return;
    setState(() => _sending = true);
    try {
      if (Env.hasSupabase) {
        await Supabase.instance.client.auth.signInWithOtp(phone: _e164);
      }
      if (!mounted) return;
      final destination = Uri(
        path: '/auth/otp',
        queryParameters: {'phone': _e164},
      ).toString();
      context.go(destination);
    } on AuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not send the code. Check your connection.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Enter phone number'),
      ),
      body: SafeArea(
        child: Padding(
          padding: Sp.screen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: Sp.x6),
              Text(
                'We will send you a verification code',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: pal.textSecondary,
                    ),
              ),
              const SizedBox(height: Sp.x6),
              Row(
                children: [
                  Container(
                    height: 54,
                    padding: const EdgeInsets.symmetric(horizontal: Sp.x4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: Rad.r14,
                      border: Border.all(color: pal.line),
                    ),
                    child: Row(
                      children: [
                        const Text('🇪🇹', style: TextStyle(fontSize: 18)),
                        const SizedBox(width: Sp.x2),
                        Text(
                          '+251',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Sp.x3),
                  Expanded(
                    child: EthioTextField(
                      controller: _controller,
                      hint: '91 234 5678',
                      keyboardType: TextInputType.phone,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              EthioButton(
                label: _sending ? 'Sending…' : 'Send code',
                onPressed: _isValid && !_sending ? _sendCode : null,
              ),
              const SizedBox(height: Sp.x4),
            ],
          ),
        ),
      ),
    );
  }
}
