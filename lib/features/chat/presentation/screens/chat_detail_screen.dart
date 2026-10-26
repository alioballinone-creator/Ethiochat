import 'package:flutter/material.dart';

class ChatDetailScreen extends StatelessWidget {
  final String chatId;
  const ChatDetailScreen({super.key, required this.chatId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text('Chat $chatId')),
    );
  }
}
