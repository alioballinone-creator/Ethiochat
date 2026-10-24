import 'package:flutter/material.dart';

class MiniProgramContainer extends StatelessWidget {
  const MiniProgramContainer({super.key, required this.appId});

  final String appId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(appId),
        actions: [
          PopupMenuButton(
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'close', child: Text('Close')),
              PopupMenuItem(value: 'share', child: Text('Share')),
              PopupMenuItem(value: 'refresh', child: Text('Refresh')),
            ],
          ),
        ],
      ),
      body: const Center(child: Text('Mini Program WebView (sandboxed)')),
    );
  }
}
