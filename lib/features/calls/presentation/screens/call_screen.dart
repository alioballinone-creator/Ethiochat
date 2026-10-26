import 'package:flutter/material.dart';

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
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircleAvatar(
              radius: 60,
              child: Icon(Icons.person, size: 60),
            ),
            const SizedBox(height: 24),
            const Text(
              'Contact Name',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.isIncoming ? 'Incoming call' : 'Calling...',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  FloatingActionButton(
                    onPressed: () => Navigator.of(context).pop(),
                    backgroundColor: Colors.red,
                    child: const Icon(Icons.call_end),
                  ),
                  if (widget.isIncoming)
                    FloatingActionButton(
                      onPressed: () {},
                      backgroundColor: Colors.green,
                      child: const Icon(Icons.call),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
