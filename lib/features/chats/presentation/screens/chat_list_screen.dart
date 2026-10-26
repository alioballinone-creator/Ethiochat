import 'package:flutter/material.dart';
import 'package:ethiochat/l10n/app_localizations.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.chats),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: ListView.builder(
        itemCount: 0,
        itemBuilder: (context, index) => const SizedBox.shrink(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: Icon(Icons.chat, color: Theme.of(context).colorScheme.onPrimary),
      ),
    );
  }
}
