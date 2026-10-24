import 'package:flutter/material.dart';
import 'package:ethiochat/core/theme/ethio_colors.dart';

class CallScreen extends StatelessWidget {
  const CallScreen({super.key, required this.isVideo, required this.isIncoming});

  final bool isVideo;
  final bool isIncoming;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EthioColors.black,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            const CircleAvatar(radius: 48, child: Icon(Icons.person, size: 48)),
            const SizedBox(height: 16),
            Text(
              'Contact',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: EthioColors.cream),
            ),
            const SizedBox(height: 8),
            Text(
              isIncoming ? 'Incoming call' : 'Calling...',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: EthioColors.cream),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _CallButton(icon: Icons.call_end, color: EthioColors.danger, onTap: () {}),
                if (isIncoming)
                  _CallButton(icon: Icons.call, color: Colors.green, onTap: () {}),
                if (!isIncoming && isVideo)
                  _CallButton(icon: Icons.videocam, color: EthioColors.goldDeep, onTap: () {}),
                _CallButton(icon: Icons.mic_off, color: Colors.white24, onTap: () {}),
              ],
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}

class _CallButton extends StatelessWidget {
  const _CallButton({required this.icon, required this.color, required this.onTap});

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }
}
