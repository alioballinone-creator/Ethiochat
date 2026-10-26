import 'package:flutter/material.dart';
import '../../../../core/design/design.dart';

class CallScreen extends StatefulWidget {
  final bool isVideo;
  final bool isIncoming;

  const CallScreen({super.key, required this.isVideo, required this.isIncoming});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EthioColors.black,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: EthioColors.gold,
                  width: 3,
                ),
              ),
              child: const EthioAvatar(name: 'Abebe Kebede', size: 120),
            ),
            const SizedBox(height: Sp.x6),
            Text(
              'Abebe Kebede',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: EthioColors.cream,
                  ),
            ),
            const SizedBox(height: Sp.x2),
            Text(
              widget.isIncoming ? 'Incoming call' : 'Calling...',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: EthioColors.cream.withOpacity(0.7),
                  ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(Sp.x8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _CallButton(
                    icon: Icons.call_end_rounded,
                    color: EthioColors.danger,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  if (widget.isIncoming)
                    _CallButton(
                      icon: Icons.call_rounded,
                      color: EthioColors.success,
                      onTap: () {},
                    ),
                ],
              ),
            ),
            const SizedBox(height: Sp.x4),
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
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 32),
      ),
    );
  }
}
