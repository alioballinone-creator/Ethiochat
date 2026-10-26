import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import '../../../../core/design/design.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String phone;
  const OtpVerificationScreen({super.key, required this.phone});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  int _seconds = 42;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_seconds > 0) {
        setState(() => _seconds--);
      } else {
        timer.cancel();
      }
    });
  }

  String get _code => _controllers.map((c) => c.text).join();

  bool get _complete => _code.length == 6;

  void _verify() {
    if (!_complete) return;
    context.go('/auth/profile');
  }

  void _resend() {
    setState(() => _seconds = 42);
    _startTimer();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'A new code was sent to '
          '${widget.phone.isEmpty ? 'your phone' : widget.phone}.',
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    _timer?.cancel();
    super.dispose();
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
        title: const Text('Verification'),
      ),
      body: SafeArea(
        child: Padding(
          padding: Sp.screen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: Sp.x6),
              Text(
                'Enter the code sent to',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: pal.textSecondary,
                    ),
              ),
              const SizedBox(height: Sp.x2),
              Text(
                widget.phone,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: Sp.x8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) {
                  return SizedBox(
                    width: 48,
                    height: 56,
                    child: TextField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      style: Theme.of(context).textTheme.titleLarge,
                      decoration: InputDecoration(
                        counterText: '',
                        contentPadding: EdgeInsets.zero,
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: Rad.r14,
                          borderSide: BorderSide(color: pal.line),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: Rad.r14,
                          borderSide: BorderSide(color: pal.line),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: Rad.r14,
                          borderSide: const BorderSide(
                              color: EthioColors.gold, width: 1.5),
                        ),
                      ),
                      onChanged: (value) {
                        if (value.isNotEmpty && index < 5) {
                          _focusNodes[index + 1].requestFocus();
                        }
                        setState(() {});
                        if (_complete) {
                          _verify();
                        }
                      },
                    ),
                  );
                }),
              ),
              const SizedBox(height: Sp.x6),
              Center(
                child: _seconds > 0
                    ? Text(
                        'Resend in 0:${_seconds.toString().padLeft(2, '0')}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: pal.textSecondary,
                            ),
                      )
                    : TextButton(
                        onPressed: _resend,
                        child: const Text('Resend code'),
                      ),
              ),
              const Spacer(),
              EthioButton(
                label: 'Verify',
                onPressed: _complete ? _verify : null,
              ),
              const SizedBox(height: Sp.x4),
            ],
          ),
        ),
      ),
    );
  }
}
