import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/screens/phone_entry_screen.dart';
import '../../features/auth/presentation/screens/otp_screen.dart';
import '../../features/auth/presentation/screens/profile_setup_screen.dart';
import '../../features/shell/presentation/app_shell.dart';
import '../../features/chats/presentation/screens/chat_screen.dart';
import '../../features/contacts/presentation/screens/contacts_screen.dart';
import '../../features/search/presentation/screens/search_screen.dart';
import '../../features/wallet/presentation/screens/wallet_screen.dart';
import '../../features/moments/presentation/screens/moments_feed_screen.dart';
import '../../features/channels/presentation/screens/channels_player_screen.dart';
import '../../features/mini_programs/presentation/screens/mini_program_container.dart';
import '../../features/marketplace/presentation/screens/marketplace_screen.dart';
import '../../features/nearby/presentation/screens/nearby_screen.dart';
import '../../features/calls/presentation/screens/call_screen.dart';
import '../../features/me/presentation/screens/me_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/chats',
    debugLogDiagnostics: false,
    routes: [
      GoRoute(
        path: '/auth/phone',
        name: 'auth_phone',
        builder: (context, state) => const PhoneEntryScreen(),
      ),
      GoRoute(
        path: '/auth/otp',
        name: 'auth_otp',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final phone = extra?['phone'] as String? ?? '';
          return OtpScreen(phone: phone);
        },
      ),
      GoRoute(
        path: '/auth/profile',
        name: 'auth_profile',
        builder: (context, state) => const ProfileSetupScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/chats',
            name: 'chats',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: _ChatsTab(),
            ),
          ),
          GoRoute(
            path: '/contacts',
            name: 'contacts',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ContactsScreen(),
            ),
          ),
          GoRoute(
            path: '/discover',
            name: 'discover',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: _DiscoverTab(),
            ),
          ),
          GoRoute(
            path: '/me',
            name: 'me',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: MeScreen(),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/chat/:conversationId',
        name: 'chat',
        builder: (context, state) {
          final conversationId = state.pathParameters['conversationId']!;
          return ChatScreen(conversationId: conversationId);
        },
      ),
      GoRoute(
        path: '/search',
        name: 'search',
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: '/wallet',
        name: 'wallet',
        builder: (context, state) => const WalletScreen(),
      ),
      GoRoute(
        path: '/moments',
        name: 'moments',
        builder: (context, state) => const MomentsFeedScreen(),
      ),
      GoRoute(
        path: '/channels',
        name: 'channels',
        builder: (context, state) => const ChannelsPlayerScreen(),
      ),
      GoRoute(
        path: '/mini/:id',
        name: 'mini_program',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return MiniProgramContainer(miniProgramId: id);
        },
      ),
      GoRoute(
        path: '/marketplace',
        name: 'marketplace',
        builder: (context, state) => const MarketplaceScreen(),
      ),
      GoRoute(
        path: '/nearby',
        name: 'nearby',
        builder: (context, state) => const NearbyScreen(),
      ),
      GoRoute(
        path: '/call/:id',
        name: 'call',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return CallScreen(callId: id);
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64),
            const SizedBox(height: 16),
            Text('Page not found: ${state.uri}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/chats'),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
});

class _ChatsTab extends StatelessWidget {
  const _ChatsTab();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chats')),
      body: ListView.builder(
        itemCount: 0,
        itemBuilder: (context, index) => const SizedBox.shrink(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/contacts'),
        child: const Icon(Icons.chat),
      ),
    );
  }
}

class _DiscoverTab extends StatelessWidget {
  const _DiscoverTab();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Discover')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Moments'),
            onTap: () => context.push('/moments'),
          ),
          ListTile(
            leading: const Icon(Icons.video_library),
            title: const Text('Channels'),
            onTap: () => context.push('/channels'),
          ),
          ListTile(
            leading: const Icon(Icons.shopping_bag),
            title: const Text('Marketplace'),
            onTap: () => context.push('/marketplace'),
          ),
          ListTile(
            leading: const Icon(Icons.near_me),
            title: const Text('Nearby'),
            onTap: () => context.push('/nearby'),
          ),
          ListTile(
            leading: const Icon(Icons.apps),
            title: const Text('Mini Programs'),
            onTap: () => context.push('/mini/default'),
          ),
        ],
      ),
    );
  }
}
