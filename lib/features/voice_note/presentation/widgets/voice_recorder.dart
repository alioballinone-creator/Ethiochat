import 'package:flutter/material.dart';
import 'package:ethiochat/core/theme/ethio_colors.dart';

class VoiceRecorder extends StatefulWidget {
  const VoiceRecorder({super.key, required this.onSend});

  final void Function(String path, Duration duration) onSend;

  @override
  State<VoiceRecorder> createState() => _VoiceRecorderState();
}

class _VoiceRecorderState extends State<VoiceRecorder> {
  bool _recording = false;
  bool _locked = false;
  double _slideOffset = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) => setState(() => _recording = true),
      onLongPressEnd: (_) {
        if (!_locked && _slideOffset < 100) {
          // send
        }
        setState(() {
          _recording = false;
          _slideOffset = 0;
          _locked = false;
        });
      },
      onPanUpdate: (d) {
        if (_recording && !_locked) {
          setState(() => _slideOffset += d.delta.dx);
        }
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: _recording ? EthioColors.danger : Theme.of(context).colorScheme.primary,
          shape: BoxShape.circle,
        ),
        child: Icon(
          _recording ? Icons.mic : Icons.mic_none,
          color: _recording ? Colors.white : Theme.of(context).colorScheme.onPrimary,
        ),
      ),
    );
  }
}
