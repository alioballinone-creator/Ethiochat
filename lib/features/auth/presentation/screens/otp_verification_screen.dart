import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/design.dart';
import '../../../profile/application/profile_controller.dart';
import '../../application/auth_providers.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  const OtpVerificationScreen({super.key, required this.phone});

  final String phone;

  @override
  ConsumerState<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  static const _maxAttempts = 5;
  static const _cooldownSeconds = 60;
  static const _lockout = Duration(minutes: 2);

  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  int _seconds = _cooldownSeconds;
  DateTime? _lockedUntil;
  int _failedAttempts = 0;
  Timer? _timer;
  bool _verifying = false;
  bool _resending = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final wasLocked = _lockedUntil != null;
      if (wasLocked && !_isLocked) _lockedUntil = null;
      if (_seconds > 0) _seconds--;
      if (_seconds > 0 || wasLocked || _isLocked) setState(() {});
    });
  }

  bool get _isLocked {
    final until = _lockedUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  int get _lockRemaining {
    final until = _lockedUntil;
    if (until == null) return 0;
    return math.max(0, until.difference(DateTime.now()).inSeconds);
  }

  String get _code => _controllers.map((c) => c.text).join();

  bool get _complete => _code.length == 6;

  void _recordFailedAttempt(String message) {
    _failedAttempts++;
    if (_failedAttempts >= _maxAttempts) {
      _lockedUntil = DateTime.now().add(_lockout);
    }
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isLocked
              ? 'Too many incorrect attempts. Try again in '
                  '${_lockout.inMinutes} minutes.'
              : message,
        ),
      ),
    );
  }

  Future<void> _verify() async {
    if (!_complete || _verifying || _isLocked) return;
    setState(() => _verifying = true);
    final result =
        await ref.read(authRepositoryProvider).verifyOtp(widget.phone, _code);
    if (!mounted) return;
    setState(() => _verifying = false);

    final failure = result.failureOrNull;
    if (failure != null) {
      _recordFailedAttempt(failure.message);
      return;
    }

    final profileResult = await ref.read(authRepositoryProvider).fetchProfile();
    if (!mounted) return;
    final profile = ref.read(userProfileProvider);
    final remote = profileResult.valueOrNull;
    if (remote != null && remote.isComplete) {
      await ref.read(userProfileProvider.notifier).save(
            name: remote.displayName,
            bio: remote.bio,
            phone: widget.phone,
            avatarPath: remote.avatarUrl ?? profile.avatarPath,
          );
      if (!mounted) return;
      context.go('/chats');
      return;
    }

    await ref.read(userProfileProvider.notifier).save(
          name: profile.name,
          bio: profile.bio,
          phone: widget.phone,
          avatarPath: profile.avatarPath,
        );
    if (!mounted) return;
    if (profileResult.failureOrNull != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Signed in, but your profile could not be loaded: '
            '${profileResult.failureOrNull!.message}',
          ),
        ),
      );
    }
    context.go('/auth/profile');
  }

  Future<void> _resend() async {
    if (_resending || _seconds > 0 || _isLocked) return;
    setState(() => _resending = true);
    final result = await ref.read(authRepositoryProvider).sendOtp(widget.phone);
    if (!mounted) return;
    setState(() => _resending = false);
    final failure = result.failureOrNull;
    if (failure != null) {
      setState(() => _seconds = 5);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message)),
      );
      return;
    }
    setState(() {
      _seconds = _cooldownSeconds;
      _failedAttempts = 0;
      _lockedUntil = null;
    });
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
    final locked = _isLocked;

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
              const SizedBox(height: Sp.x2),
              Text(
                'Codes expire after a few minutes.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: pal.textSecondary,
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
                      enabled: !locked && !_verifying,
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
                          unawaited(_verify());
                        }
                      },
                    ),
                  );
                }),
              ),
              const SizedBox(height: Sp.x6),
              Center(
                child: locked
                    ? Text(
                        'Try again in '
                        '${_lockRemaining ~/ 60}:'
                        '${(_lockRemaining % 60).toString().padLeft(2, '0')}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: EthioColors.danger,
                            ),
                      )
                    : _seconds > 0
                        ? Text(
                            'Resend in '
                            '${_seconds ~/ 60}:'
                            '${(_seconds % 60).toString().padLeft(2, '0')}',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: pal.textSecondary,
                                ),
                          )
                        : TextButton(
                            onPressed: _resending ? null : _resend,
                            child: Text(
                              _resending ? 'Sending…' : 'Resend code',
                            ),
                          ),
              ),
              const Spacer(),
              EthioButton(
                label: _verifying ? 'Verifying…' : 'Verify',
                onPressed: _complete && !_verifying && !locked ? _verify : null,
              ),
              const SizedBox(height: Sp.x4),
            ],
          ),
        ),
      ),
    );
  }
}
