import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ethiochat/l10n/app_localizations.dart';

/// Bottom navigation with exactly 4 tabs: Chats · Contacts · Discover · Me.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  int _getCurrentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/chats')) return 0;
    if (location.startsWith('/contacts')) return 1;
    if (location.startsWith('/discover')) return 2;
    if (location.startsWith('/me')) return 3;
    return 0;
  }

  void _onDestinationSelected(BuildContext context, int index) {
    final path = switch (index) {
      1 => '/contacts',
      2 => '/discover',
      3 => '/me',
      _ => '/chats',
    };
    context.go(path);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currentIndex = _getCurrentIndex(context);
    
    final destinations = [
      NavigationDestination(
        icon: const Icon(Icons.chat_bubble_outline),
        selectedIcon: const Icon(Icons.chat_bubble),
        label: l10n.chats,
      ),
      NavigationDestination(
        icon: const Icon(Icons.people_outline),
        selectedIcon: const Icon(Icons.people),
        label: l10n.contacts,
      ),
      NavigationDestination(
        icon: const Icon(Icons.explore_outlined),
        selectedIcon: const Icon(Icons.explore),
        label: l10n.discover,
      ),
      NavigationDestination(
        icon: const Icon(Icons.person_outline),
        selectedIcon: const Icon(Icons.person),
        label: l10n.me,
      ),
    ];
    
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (i) => _onDestinationSelected(context, i),
        destinations: destinations,
      ),
    );
  }
}
