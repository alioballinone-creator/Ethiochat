import 'package:flutter/material.dart';
import 'package:ethiochat/core/theme/app_spacing.dart';
import 'package:ethiochat/core/utils/phone.dart';
import 'package:ethiochat/l10n/app_localizations.dart';

class PhoneEntryScreen extends StatefulWidget {
  const PhoneEntryScreen({super.key});

  @override
  State<PhoneEntryScreen> createState() => _PhoneEntryScreenState();
}

class _PhoneEntryScreenState extends State<PhoneEntryScreen> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final normalized = PhoneUtils.normalize(_controller.text);
    if (normalized == null) {
      setState(() => _error = 'Enter a valid Ethiopian number (+251 9XX XXX XXX)');
      return;
    }
    setState(() => _error = null);
    // Navigate to OTP - wired when routing is added
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appName)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.xl),
              Text(l10n.phoneNumber, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _controller,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  prefixText: '+251 ',
                  hintText: '9XX XXX XXX',
                  errorText: _error,
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _submit,
                child: Text(l10n.continueLabel),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}
