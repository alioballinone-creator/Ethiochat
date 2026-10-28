import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

import '../../../../core/design/design.dart';
import '../../../chats/application/chat_providers.dart';
import '../../data/livekit_call_service.dart';
import '../../domain/call_models.dart';

class CallScreen extends ConsumerStatefulWidget {
  const CallScreen({
    super.key,
    required this.isVideo,
    required this.isIncoming,
    this.chatId = '',
    this.callId = '',
  });

  final bool isVideo;
  final bool isIncoming;
  final String chatId;
  final String callId;

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  final _service = LiveKitCallService();
  final _lifecycle = CallLifecycle();
  Timer? _timer;
  lk.Room? _room;
  int _seconds = 0;
  bool _busy = false;
  bool _ending = false;
  bool _ended = false;
  bool _disposed = false;
  bool _muted = false;
  bool _speaker = false;
  bool _videoOn = true;
  bool _frontCamera = true;

  @override
  void initState() {
    super.initState();
    _videoOn = widget.isVideo;
    _speaker = widget.isVideo;
    if (widget.isIncoming) {
      _lifecycle.beginIncoming();
      if (widget.callId.isEmpty) {
        _lifecycle.markFailed(
          'This incoming call is missing its call identifier and cannot be '
          'answered.',
        );
      }
    } else {
      _lifecycle.beginOutgoing();
      unawaited(_startOutgoing());
    }
  }

  Future<void> _startOutgoing() async {
    if (widget.chatId.isEmpty) {
      _fail('This call is not linked to a conversation.');
      return;
    }
    try {
      final info = await _service.startOutgoing(
        conversationId: widget.chatId,
        video: widget.isVideo,
      );
      if (!mounted) return;
      _lifecycle.markRinging();
      _setState();

      _lifecycle.markConnecting();
      _setState();
      await _service.connect(info, video: widget.isVideo);
      if (!mounted) {
        await _service.disconnect();
        return;
      }
      _attachRoom();
      if (_service.hasRemoteParticipants) {
        _markConnected();
      } else {
        _lifecycle.markRinging();
        _setState();
      }
    } on CallException catch (error) {
      await _service.disconnect();
      _fail(error.message);
    } catch (error) {
      await _service.disconnect();
      _fail('The call could not be started: $error');
    }
  }

  Future<void> _accept() async {
    if (_busy || _ending || widget.callId.isEmpty) return;
    setState(() => _busy = true);
    _lifecycle.markConnecting();
    _setState();
    try {
      final info = await _service.joinCall(widget.callId);
      if (!mounted) return;
      await _service.connect(info, video: widget.isVideo);
      if (!mounted) {
        await _service.disconnect();
        return;
      }
      _attachRoom();
      _markConnected();
    } on CallException catch (error) {
      await _service.disconnect();
      _fail(error.message);
    } catch (error) {
      await _service.disconnect();
      _fail('The call could not be answered: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _attachRoom() {
    final room = _service.room;
    if (room == null) return;
    _room?.removeListener(_onRoomChanged);
    _room = room;
    room.addListener(_onRoomChanged);
    _onRoomChanged();
  }

  void _onRoomChanged() {
    if (_disposed || !mounted) return;
    final room = _room;
    if (room == null) return;

    if (room.connectionState == lk.ConnectionState.reconnecting &&
        _lifecycle.isConnected) {
      _lifecycle.markReconnecting();
      _stopTimer();
      _setState();
      return;
    }
    if (room.connectionState == lk.ConnectionState.disconnected &&
        _lifecycle.isActive) {
      _fail('The media connection was lost.');
      return;
    }
    if (_service.hasRemoteParticipants &&
        _lifecycle.phase != CallPhase.connected) {
      _markConnected();
      return;
    }
    _setState();
  }

  void _markConnected() {
    if (_lifecycle.phase == CallPhase.connected) return;
    _lifecycle.markConnected();
    _startTimer();
    _setState();
  }

  void _startTimer() {
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _lifecycle.isConnected) {
        setState(() => _seconds++);
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _fail(String message) {
    _stopTimer();
    _lifecycle.markFailed(message);
    _setState();
  }

  void _setState() {
    if (!_disposed && mounted) setState(() {});
  }

  Future<void> _end({bool rejected = false}) async {
    if (_ending) return;
    _ending = true;
    _ended = true;
    _stopTimer();
    String? failure;
    try {
      await _service.endCall(
        callId: widget.callId.isEmpty ? null : widget.callId,
        rejected: rejected || (widget.isIncoming && !_lifecycle.isConnected),
      );
    } on CallException catch (error) {
      failure = error.message;
    } catch (error) {
      failure = 'The call server could not be updated: $error';
    }
    if (!mounted) return;
    if (failure != null) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Call ended with an error'),
          content: Text(failure!),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
    if (!mounted) return;
    context.pop();
  }

  Future<void> _toggleMute() async {
    if (_busy) return;
    final next = !_muted;
    try {
      await _service.setMicrophoneEnabled(!next);
      if (mounted) setState(() => _muted = next);
    } on CallException catch (error) {
      _feedback(error.message);
    } catch (error) {
      _feedback('Could not change the microphone: $error');
    }
  }

  Future<void> _toggleSpeaker() async {
    final next = !_speaker;
    try {
      await _service.setSpeakerEnabled(next);
      if (mounted) setState(() => _speaker = next);
    } on CallException catch (error) {
      _feedback(error.message);
    } catch (error) {
      _feedback('Could not change the audio output: $error');
    }
  }

  Future<void> _toggleVideo() async {
    final next = !_videoOn;
    try {
      await _service.setCameraEnabled(next);
      if (mounted) setState(() => _videoOn = next);
    } on CallException catch (error) {
      _feedback(error.message);
    } catch (error) {
      _feedback('Could not change the camera: $error');
    }
  }

  Future<void> _flipCamera() async {
    try {
      final switched = await _service.switchCamera();
      if (!mounted) return;
      if (!switched) {
        _feedback('This device does not expose a second camera.');
        return;
      }
      setState(() => _frontCamera = !_frontCamera);
      HapticFeedback.selectionClick();
    } catch (error) {
      _feedback('Could not switch the camera: $error');
    }
  }

  void _feedback(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _disposed = true;
    _stopTimer();
    _room?.removeListener(_onRoomChanged);
    _room = null;
    if (!_ended && _lifecycle.isActive) {
      final callId = widget.callId.isEmpty ? null : widget.callId;
      unawaited(
        _service
            .endCall(
          callId: callId,
          rejected: widget.isIncoming && !_lifecycle.isConnected,
        )
            .catchError((Object error) {
          debugPrint('Call cleanup failed: $error');
        }),
      );
    }
    unawaited(_service.disconnect());
    super.dispose();
  }

  String get _duration {
    final minutes = (_seconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String get _status {
    final mode = widget.isVideo ? 'Video call' : 'Voice call';
    return switch (_lifecycle.phase) {
      CallPhase.idle => 'Preparing call…',
      CallPhase.requesting => 'Starting secure call…',
      CallPhase.ringing when widget.isIncoming =>
        'Incoming ${widget.isVideo ? 'video ' : ''}call',
      CallPhase.ringing => 'Ringing…',
      CallPhase.connecting => 'Connecting media…',
      CallPhase.connected => '$mode · $_duration',
      CallPhase.reconnecting => 'Reconnecting…',
      CallPhase.failed => _lifecycle.error ?? 'Call failed',
      CallPhase.ended => 'Call ended',
    };
  }

  @override
  Widget build(BuildContext context) {
    final conversation = widget.chatId.isEmpty
        ? null
        : ref.watch(conversationProvider(widget.chatId)).valueOrNull;
    final title = conversation?.title ?? 'EthioChat call';
    final connected = _lifecycle.isConnected;
    final failed = _lifecycle.phase == CallPhase.failed;
    final List<lk.VideoTrack> remoteVideos =
        widget.isVideo ? _service.remoteVideoTracks : const [];
    final localVideo =
        widget.isVideo && _videoOn ? _service.localVideoTrack : null;
    final remoteCount = _service.remoteParticipantCount;

    return Scaffold(
      backgroundColor: EthioColors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (remoteVideos.isNotEmpty)
            lk.VideoTrackRenderer(
              remoteVideos.first,
              fit: lk.VideoViewFit.cover,
            )
          else
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [EthioColors.black, EthioColors.blackSoft],
                ),
              ),
            ),
          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    tooltip: 'Back',
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    color: EthioColors.cream,
                    onPressed: _ending ? null : () => _end(),
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints:
                            BoxConstraints(minHeight: constraints.maxHeight),
                        child: Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: Sp.x5),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (remoteVideos.isEmpty)
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: EthioColors.gold,
                                      width: 3,
                                    ),
                                  ),
                                  child: EthioAvatar(name: title, size: 112),
                                ),
                              const SizedBox(height: Sp.x5),
                              Text(
                                title,
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(color: EthioColors.cream),
                              ),
                              const SizedBox(height: Sp.x2),
                              Text(
                                _status,
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.copyWith(
                                      color: failed
                                          ? const Color(0xFFFFB4AB)
                                          : EthioColors.cream
                                              .withValues(alpha: 0.8),
                                    ),
                              ),
                              if (connected && remoteCount > 1) ...[
                                const SizedBox(height: Sp.x1),
                                Text(
                                  '$remoteCount people on this call',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: EthioColors.cream
                                            .withValues(alpha: 0.65),
                                      ),
                                ),
                              ],
                              if (widget.isIncoming &&
                                  _lifecycle.phase == CallPhase.ringing) ...[
                                const SizedBox(height: Sp.x6),
                                Text(
                                  'Tap the green button to answer',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: EthioColors.cream
                                            .withValues(alpha: 0.6),
                                      ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (localVideo != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: Sp.x4),
                      child: ClipRRect(
                        borderRadius: Rad.r14,
                        child: SizedBox(
                          width: 104,
                          height: 144,
                          child: lk.VideoTrackRenderer(
                            localVideo,
                            fit: lk.VideoViewFit.cover,
                            mirrorMode: _frontCamera
                                ? lk.VideoViewMirrorMode.mirror
                                : lk.VideoViewMirrorMode.off,
                          ),
                        ),
                      ),
                    ),
                  ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Sp.x4,
                      Sp.x4,
                      Sp.x4,
                      Sp.x4,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (connected)
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: Sp.x4,
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
                                onTap: _toggleMute,
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
                                onTap: _toggleSpeaker,
                              ),
                              if (widget.isVideo)
                                _CallButton(
                                  icon: _videoOn
                                      ? Icons.videocam_rounded
                                      : Icons.videocam_off_rounded,
                                  label: 'Video',
                                  color: _videoOn
                                      ? EthioColors.cream
                                      : Colors.white.withValues(alpha: 0.16),
                                  iconColor: _videoOn
                                      ? EthioColors.black
                                      : EthioColors.cream,
                                  onTap: _toggleVideo,
                                ),
                              if (widget.isVideo && _videoOn)
                                _CallButton(
                                  icon: _frontCamera
                                      ? Icons.cameraswitch_rounded
                                      : Icons.camera_rear_rounded,
                                  label: 'Flip',
                                  color: Colors.white.withValues(alpha: 0.16),
                                  iconColor: EthioColors.cream,
                                  onTap: _flipCamera,
                                ),
                            ],
                          ),
                        const SizedBox(height: Sp.x4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _CallButton(
                              icon: Icons.call_end_rounded,
                              label: widget.isIncoming && !connected
                                  ? 'Decline'
                                  : 'End',
                              color: EthioColors.danger,
                              iconColor: Colors.white,
                              onTap: _ending
                                  ? null
                                  : () => _end(
                                        rejected:
                                            widget.isIncoming && !connected,
                                      ),
                            ),
                            if (widget.isIncoming && !connected && !failed)
                              _CallButton(
                                icon: Icons.call_rounded,
                                label: _busy ? 'Answering…' : 'Answer',
                                color: EthioColors.success,
                                iconColor: Colors.white,
                                onTap: _busy ? null : _accept,
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
        ],
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
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? 0.5 : 1,
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
        ),
      ),
    );
  }
}
