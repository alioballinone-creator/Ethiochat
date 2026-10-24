import 'package:flutter/material.dart';
import 'package:ethiochat/l10n/app_localizations.dart';

/// Bottom navigation with exactly 4 tabs: Chats · Contacts · Discover · Me.
/// Wallet sits in Me and Discover as specified.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final destinations = [
      NavigationDestination(icon: const Icon(Icons.chat_bubble_outline), selectedIcon: const Icon(Icons.chat_bubble), label: l10n.chats),
      NavigationDestination(icon: const Icon(Icons.people_outline), selectedIcon: const Icon(Icons.people), label: l10n.contacts),
      NavigationDestination(icon: const Icon(Icons.explore_outlined), selectedIcon: const Icon(Icons.explore), label: l10n.discover),
      NavigationDestination(icon: const Icon(Icons.person_outline), selectedIcon: const Icon(Icons.person), label: l10n.me),
    ];
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          _PlaceholderTab(title: 'Chats'),
          _PlaceholderTab(title: 'Contacts'),
          _PlaceholderTab(title: 'Discover'),
          _PlaceholderTab(title: 'Me'),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: destinations,
      ),
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) {
    return Center(child: Text(title, style: Theme.of(context).textTheme.titleLarge));
  }
}
