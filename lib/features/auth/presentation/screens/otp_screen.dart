import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key, required this.phone});

  final String phone;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _controller = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _verify() async {
    setState(() => _loading = true);
    await Future<void>.delayed(const Duration(seconds: 1));
    if (mounted) {
      setState(() => _loading = false);
      context.go('/auth/profile');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify OTP')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 32),
            Text(
              'Enter the code sent to ${widget.phone}',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'OTP Code',
                hintText: '123456',
              ),
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : _verify,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Verify'),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {},
              child: const Text('Resend code'),
            ),
          ],
        ),
      ),
    );
  }
}
