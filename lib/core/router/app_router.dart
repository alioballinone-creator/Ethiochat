import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/splash_screen.dart';
import '../../features/auth/presentation/screens/phone_entry_screen.dart';
import '../../features/auth/presentation/screens/otp_verification_screen.dart';
import '../../features/auth/presentation/screens/profile_setup_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/chat/presentation/screens/chat_list_screen.dart';
import '../../features/chat/presentation/screens/chat_detail_screen.dart';
import '../../features/contacts/presentation/screens/contacts_screen.dart';
import '../../features/payments/presentation/screens/payments_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/mini_programs/presentation/screens/mini_programs_screen.dart';
import '../../features/mini_programs/presentation/screens/mini_program_container.dart';
import '../../features/calls/presentation/screens/call_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';

class AppRouter {
  static const String splash = '/';
  static const String phoneEntry = '/auth/phone';
  static const String otpVerification = '/auth/otp';
  static const String profileSetup = '/auth/profile';
  static const String home = '/home';
  static const String chats = '/chats';
  static const String chatDetail = '/chats/:chatId';
  static const String contacts = '/contacts';
  static const String payments = '/payments';
  static const String profile = '/profile';
  static const String miniPrograms = '/mini-programs';
  static const String miniProgramDetail = '/mini-programs/:appId';
  static const String call = '/call';
  static const String settings = '/settings';

  static GoRouter createRouter() {
    return GoRouter(
      initialLocation: splash,
      routes: [
        GoRoute(
          path: splash,
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: phoneEntry,
          builder: (context, state) => const PhoneEntryScreen(),
        ),
        GoRoute(
          path: otpVerification,
          builder: (context, state) {
            final phone = state.uri.queryParameters['phone'] ?? '';
            return OtpVerificationScreen(phone: phone);
          },
        ),
        GoRoute(
          path: profileSetup,
          builder: (context, state) => const ProfileSetupScreen(),
        ),
        GoRoute(
          path: home,
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: chats,
          builder: (context, state) => const ChatListScreen(),
        ),
        GoRoute(
          path: chatDetail,
          builder: (context, state) {
            final chatId = state.pathParameters['chatId'] ?? '';
            return ChatDetailScreen(chatId: chatId);
          },
        ),
        GoRoute(
          path: contacts,
          builder: (context, state) => const ContactsScreen(),
        ),
        GoRoute(
          path: payments,
          builder: (context, state) => const PaymentsScreen(),
        ),
        GoRoute(
          path: profile,
          builder: (context, state) => const ProfileScreen(),
        ),
        GoRoute(
          path: miniPrograms,
          builder: (context, state) => const MiniProgramsScreen(),
        ),
        GoRoute(
          path: miniProgramDetail,
          builder: (context, state) {
            final appId = state.pathParameters['appId'] ?? '';
            return MiniProgramContainer(appId: appId);
          },
        ),
        GoRoute(
          path: call,
          builder: (context, state) {
            final isVideo = state.uri.queryParameters['video'] == 'true';
            final isIncoming = state.uri.queryParameters['incoming'] == 'true';
            return CallScreen(isVideo: isVideo, isIncoming: isIncoming);
          },
        ),
        GoRoute(
          path: settings,
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    );
  }
}
