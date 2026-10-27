import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/design.dart';
import '../../../chats/application/chat_providers.dart';

class ContactRequestsScreen extends ConsumerStatefulWidget {
  const ContactRequestsScreen({super.key});

  @override
  ConsumerState<ContactRequestsScreen> createState() =>
      _ContactRequestsScreenState();
}

class _ContactRequestsScreenState extends ConsumerState<ContactRequestsScreen> {
  final _requests = <_Request>[
    const _Request(
      name: 'Hanna Tesfaye',
      phone: '+251 91 445 2210',
      note: 'We met at the Addis Tech meetup.',
      mutual: 4,
    ),
    const _Request(
      name: 'Dawit Bekele',
      phone: '+251 92 118 6743',
      note: 'From the football group.',
      mutual: 7,
    ),
    const _Request(
      name: 'Meron Alemu',
      phone: '+251 93 220 1188',
      note: 'Works with your sister.',
      mutual: 2,
    ),
  ];
  var _busy = false;

  Future<void> _accept(_Request request) async {
    setState(() => _busy = true);
    final result = await ref.read(chatRepositoryProvider).addContact(
          displayName: request.name,
          phoneE164: request.phone,
        );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (result.isSuccess) _requests.remove(request);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.isSuccess
              ? '${request.name} added to contacts.'
              : result.failureOrNull?.message ?? 'Could not add contact.',
        ),
      ),
    );
  }

  Future<void> _decline(_Request request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Decline ${request.name}?'),
        content: const Text(
          'They will not be told that you declined the request.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Decline'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      setState(() => _requests.remove(request));
    }
  }

  Future<void> _acceptAll() async {
    for (final request in List<_Request>.of(_requests)) {
      final result = await ref.read(chatRepositoryProvider).addContact(
            displayName: request.name,
            phoneE164: request.phone,
          );
      if (!mounted) return;
      if (result.isSuccess) setState(() => _requests.remove(request));
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All requests accepted.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text('New friends', style: text.headlineMedium),
        actions: [
          if (_requests.length > 1)
            TextButton(
              onPressed: _busy ? null : _acceptAll,
              child: const Text('Accept all'),
            ),
          const SizedBox(width: Sp.x1),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _requests.isEmpty
            ? EthioEmptyState(
                icon: Icons.person_add_alt_1_outlined,
                title: 'No pending requests',
                message:
                    'Friend requests you receive will appear here. You can '
                    'accept or decline them without notifying the sender.',
                action: EthioButton(
                  label: 'Scan a friend',
                  expand: false,
                  icon: Icons.qr_code_scanner_rounded,
                  onPressed: () => context.push('/scan'),
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
                        const EthioIconTile(
                          icon: Icons.people_outline_rounded,
                          background: EthioColors.gold,
                        ),
                        const SizedBox(width: Sp.x3),
                        Expanded(
                          child: Text(
                            'Accept a request to start chatting. People you '
                            'decline cannot message you.',
                            style: text.bodySmall
                                ?.copyWith(color: pal.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Sp.x3),
                  for (final request in _requests)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Sp.x2),
                      child: Container(
                        padding: const EdgeInsets.all(Sp.x4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: Rad.r18,
                          border: Border.all(color: pal.line),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                EthioAvatar(name: request.name, size: 50),
                                const SizedBox(width: Sp.x3),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(request.name,
                                          style: text.titleMedium),
                                      Text(
                                        '${request.phone} · '
                                        '${request.mutual} mutual friends',
                                        style: text.labelSmall?.copyWith(
                                          color: pal.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (request.note.isNotEmpty) ...[
                              const SizedBox(height: Sp.x3),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(Sp.x3),
                                decoration: BoxDecoration(
                                  color: pal.chip,
                                  borderRadius: Rad.r10,
                                ),
                                child: Text(
                                  '“${request.note}”',
                                  style: text.bodySmall
                                      ?.copyWith(color: pal.textSecondary),
                                ),
                              ),
                            ],
                            const SizedBox(height: Sp.x3),
                            Row(
                              children: [
                                Expanded(
                                  child: EthioButton(
                                    label: 'Accept',
                                    size: EthioButtonSize.small,
                                    onPressed:
                                        _busy ? null : () => _accept(request),
                                  ),
                                ),
                                const SizedBox(width: Sp.x2),
                                Expanded(
                                  child: EthioButton(
                                    label: 'Decline',
                                    kind: EthioButtonKind.secondary,
                                    size: EthioButtonSize.small,
                                    onPressed:
                                        _busy ? null : () => _decline(request),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _Request {
  const _Request({
    required this.name,
    required this.phone,
    required this.note,
    required this.mutual,
  });

  final String name;
  final String phone;
  final String note;
  final int mutual;
}
