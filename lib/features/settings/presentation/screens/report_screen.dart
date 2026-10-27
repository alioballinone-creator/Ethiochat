import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/design.dart';
import '../../../chats/application/chat_providers.dart';

class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({
    super.key,
    required this.targetName,
    this.targetId = '',
    this.targetType = 'account',
  });

  final String targetName;
  final String targetId;
  final String targetType;

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  static const _reasons = [
    'Spam or scam',
    'Harassment or bullying',
    'Inappropriate content',
    'Impersonation',
    'False information',
    'Other',
  ];

  final _note = TextEditingController();
  String? _reason;
  var _block = false;
  var _busy = false;
  var _done = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reason;
    if (reason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a reason for the report.')),
      );
      return;
    }
    setState(() => _busy = true);
    final repo = ref.read(chatRepositoryProvider);
    final report = await repo.saveReport(
      targetId: widget.targetId.isEmpty ? widget.targetName : widget.targetId,
      targetName: widget.targetName,
      reason: reason,
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
    );
    if (!mounted) return;
    if (!report.isSuccess) {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(report.failureOrNull?.message ?? 'Could not report.'),
        ),
      );
      return;
    }
    if (_block) {
      await repo.setContactBlocked(widget.targetName, true);
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _done = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text(
          _done ? 'Report received' : 'Report ${widget.targetType}',
          style: text.headlineMedium,
        ),
      ),
      body: SafeArea(
        top: false,
        child: _done
            ? Center(
                child: Padding(
                  padding: Sp.screen,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          color: EthioColors.success.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 42,
                          color: EthioColors.success,
                        ),
                      ),
                      const SizedBox(height: Sp.x4),
                      Text('Thank you for keeping EthioChat safe',
                          textAlign: TextAlign.center, style: text.titleLarge),
                      const SizedBox(height: Sp.x2),
                      Text(
                        'Our safety team will review this report. '
                        'We never reveal who reported an account.',
                        textAlign: TextAlign.center,
                        style:
                            text.bodyMedium?.copyWith(color: pal.textSecondary),
                      ),
                      const SizedBox(height: Sp.x6),
                      EthioButton(
                        label: 'Done',
                        onPressed: () => context.pop(),
                      ),
                    ],
                  ),
                ),
              )
            : ListView(
                padding: Sp.screen.copyWith(top: Sp.x3, bottom: Sp.x8),
                children: [
                  Container(
                    padding: const EdgeInsets.all(Sp.x4),
                    decoration: BoxDecoration(
                      color: pal.chip,
                      borderRadius: Rad.r18,
                      border: Border.all(color: pal.line),
                    ),
                    child: Row(
                      children: [
                        EthioAvatar(name: widget.targetName, size: 46),
                        const SizedBox(width: Sp.x3),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.targetName, style: text.titleMedium),
                              Text(
                                'Reports are confidential.',
                                style: text.labelSmall
                                    ?.copyWith(color: pal.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Sp.x5),
                  Text('Why are you reporting this?', style: text.titleMedium),
                  const SizedBox(height: Sp.x2),
                  EthioSectionCard(
                    children: [
                      for (final reason in _reasons)
                        RadioListTile<String>(
                          value: reason,
                          groupValue: _reason,
                          onChanged: (value) => setState(() => _reason = value),
                          title: Text(reason),
                          activeColor: EthioColors.goldDeep,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: Sp.x3),
                        ),
                    ],
                  ),
                  const SizedBox(height: Sp.x4),
                  Text('Details (optional)', style: text.titleMedium),
                  const SizedBox(height: Sp.x2),
                  TextField(
                    controller: _note,
                    minLines: 3,
                    maxLines: 6,
                    decoration: InputDecoration(
                      hintText: 'Tell us what happened.',
                      fillColor: pal.chip,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: Rad.r14,
                        borderSide: BorderSide(color: pal.line),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: Rad.r14,
                        borderSide: BorderSide(color: pal.line),
                      ),
                    ),
                  ),
                  const SizedBox(height: Sp.x2),
                  CheckboxListTile(
                    value: _block,
                    onChanged: (value) =>
                        setState(() => _block = value ?? false),
                    title: Text(
                      'Block ${widget.targetName}',
                      style: text.titleMedium,
                    ),
                    subtitle: const Text(
                      'They will not be able to message or call you.',
                    ),
                    activeColor: EthioColors.goldDeep,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  const SizedBox(height: Sp.x4),
                  EthioButton(
                    label: _busy ? 'Sending report…' : 'Submit report',
                    icon: Icons.flag_outlined,
                    onPressed: _busy ? null : _submit,
                  ),
                  const SizedBox(height: Sp.x3),
                  Text(
                    'False reports may lead to account restrictions. '
                    'Emergency situations should be reported to the police.',
                    textAlign: TextAlign.center,
                    style: text.labelSmall?.copyWith(color: pal.textTertiary),
                  ),
                ],
              ),
      ),
    );
  }
}
