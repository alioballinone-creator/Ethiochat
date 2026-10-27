import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/widgets/ethio_bottom_nav.dart';

/// Persistent four-tab shell. Each branch keeps its scroll position and state
/// while the user moves between Chats, Contacts, Discover and Me.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: EthioBottomNav(
        index: navigationShell.currentIndex,
        onTap: _onTap,
      ),
    );
  }
}
