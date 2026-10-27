import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/design.dart';
import '../../../chats/application/chat_providers.dart';
import '../../../contacts/domain/entities/contact_entity.dart';

class CallScreen extends ConsumerStatefulWidget {
  const CallScreen({
    super.key,
    required this.isVideo,
    required this.isIncoming,
    this.chatId = '',
  });

  final bool isVideo;
  final bool isIncoming;
  final String chatId;

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  Timer? _timer;
  int _seconds = 0;
  bool _connected = false;
  bool _muted = false;
  bool _speaker = false;
  bool _videoOn = true;
  bool _frontCamera = true;

  @override
  void initState() {
    super.initState();
    if (!widget.isIncoming) {
      _connected = true;
      _startTimer();
    }
  }

  void _startTimer() {
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  void _accept() {
    setState(() => _connected = true);
    _startTimer();
  }

  void _end() {
    _timer?.cancel();
    if (mounted) context.pop();
  }

  void _flipCamera() {
    setState(() => _frontCamera = !_frontCamera);
    HapticFeedback.selectionClick();
  }

  Future<void> _addCallMember() async {
    final contacts =
        ref.read(contactsProvider).valueOrNull ?? const <ContactEntity>[];
    final selected = await showModalBottomSheet<ContactEntity>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Sp.x5, 0, Sp.x5, Sp.x2),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Add someone to this call',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
              ),
            ),
            if (contacts.isEmpty)
              const Padding(
                padding: EdgeInsets.all(Sp.x6),
                child: Text('No contacts available yet.'),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final contact in contacts)
                      ListTile(
                        leading: EthioAvatar(
                          name: contact.displayName,
                          imageUrl: contact.avatarUrl,
                          size: 40,
                        ),
                        title: Text(contact.displayName),
                        subtitle: Text(
                          contact.phoneE164 ?? 'EthioChat contact',
                        ),
                        onTap: () => Navigator.pop(sheetContext, contact),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('Invite sent to ${selected.displayName}')),
      );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _duration {
    final minutes = (_seconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final conversation = ref.watch(conversationProvider(widget.chatId));
    final title = conversation.valueOrNull?.title ?? 'Abebe Kebede';

    return Scaffold(
      backgroundColor: EthioColors.black,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              EthioColors.black,
              widget.isVideo && _videoOn && _connected
                  ? const Color(0xFF1B2A24)
                  : EthioColors.blackSoft,
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // The call content must remain reachable at 360x640 with 2x text.
              // Pin nothing to a fixed height; scroll when the scaled content
              // is taller than the viewport.
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Align(
                        alignment: Alignment.topLeft,
                        child: IconButton(
                          tooltip: 'Back',
                          icon: const Icon(Icons.keyboard_arrow_down_rounded),
                          color: EthioColors.cream,
                          onPressed: _end,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: Sp.x4),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: EthioColors.gold,
                                  width: 3,
                                ),
                              ),
                              child: EthioAvatar(name: title, size: 120),
                            ),
                            const SizedBox(height: Sp.x6),
                            Text(
                              title,
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(
                                    color: EthioColors.cream,
                                  ),
                            ),
                            const SizedBox(height: Sp.x2),
                            Text(
                              _connected
                                  ? (widget.isVideo
                                      ? 'Video call · $_duration'
                                      : _duration)
                                  : widget.isIncoming
                                      ? 'Incoming ${widget.isVideo ? 'video ' : ''}call'
                                      : 'Calling…',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                    color: EthioColors.cream
                                        .withValues(alpha: 0.7),
                                  ),
                            ),
                            if (!_connected && widget.isIncoming) ...[
                              const SizedBox(height: Sp.x6),
                              Text(
                                'Tap the green button to answer',
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: EthioColors.cream
                                          .withValues(alpha: 0.5),
                                    ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_connected)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: Sp.x4,
                              ),
                              child: Wrap(
                                alignment: WrapAlignment.center,
                                spacing: Sp.x5,
                                runSpacing: Sp.x3,
                                children: [
                                  _CallButton(
                                    icon: _muted
                                        ? Icons.mic_off_rounded
                                        : Icons.mic_none_rounded,
                                    label: _muted ? 'Unmute' : 'Mute',
                                    color: _muted
                                        ? EthioColors.cream
                                        : Colors.white.withValues(alpha: 0.16),
                                    iconColor: _muted
                                        ? EthioColors.black
                                        : EthioColors.cream,
                                    onTap: () =>
                                        setState(() => _muted = !_muted),
                                  ),
                                  _CallButton(
                                    icon: _speaker
                                        ? Icons.volume_up_rounded
                                        : Icons.volume_down_rounded,
                                    label: 'Speaker',
                                    color: _speaker
                                        ? EthioColors.cream
                                        : Colors.white.withValues(alpha: 0.16),
                                    iconColor: _speaker
                                        ? EthioColors.black
                                        : EthioColors.cream,
                                    onTap: () =>
                                        setState(() => _speaker = !_speaker),
                                  ),
                                  if (widget.isVideo) ...[
                                    _CallButton(
                                      icon: _videoOn
                                          ? Icons.videocam_rounded
                                          : Icons.videocam_off_rounded,
                                      label: 'Video',
                                      color: _videoOn
                                          ? EthioColors.cream
                                          : Colors.white
                                              .withValues(alpha: 0.16),
                                      iconColor: _videoOn
                                          ? EthioColors.black
                                          : EthioColors.cream,
                                      onTap: () =>
                                          setState(() => _videoOn = !_videoOn),
                                    ),
                                    if (_videoOn)
                                      _CallButton(
                                        icon: _frontCamera
                                            ? Icons.cameraswitch_rounded
                                            : Icons.camera_rear_rounded,
                                        label: 'Flip',
                                        color: Colors.white
                                            .withValues(alpha: 0.16),
                                        iconColor: EthioColors.cream,
                                        onTap: _flipCamera,
                                      ),
                                  ],
                                  _CallButton(
                                    icon: Icons.person_add_alt_1_rounded,
                                    label: 'Add',
                                    color: Colors.white.withValues(alpha: 0.16),
                                    iconColor: EthioColors.cream,
                                    onTap: _addCallMember,
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: Sp.x8),
                          Padding(
                            padding: const EdgeInsets.all(Sp.x8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _CallButton(
                                  icon: Icons.call_end_rounded,
                                  label: 'End',
                                  color: EthioColors.danger,
                                  iconColor: Colors.white,
                                  onTap: _end,
                                ),
                                if (widget.isIncoming && !_connected)
                                  _CallButton(
                                    icon: Icons.call_rounded,
                                    label: 'Answer',
                                    color: EthioColors.success,
                                    iconColor: Colors.white,
                                    onTap: _accept,
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: Sp.x4),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CallButton extends StatelessWidget {
  const _CallButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.iconColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(height: Sp.x2),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: EthioColors.cream.withValues(alpha: 0.8),
                ),
          ),
        ],
      ),
    );
  }
}
