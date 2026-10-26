import 'package:go_router/go_router.dart';
import '../screens/splash_screen.dart';
import '../../features/auth/presentation/screens/welcome_screen.dart';
import '../../features/auth/presentation/screens/phone_entry_screen.dart';
import '../../features/auth/presentation/screens/otp_verification_screen.dart';
import '../../features/auth/presentation/screens/profile_setup_screen.dart';
import '../../features/chat/presentation/screens/chat_list_screen.dart';
import '../../features/chat/presentation/screens/chat_detail_screen.dart';
import '../../features/contacts/presentation/screens/contacts_screen.dart';
import '../../features/discover/presentation/screens/discover_screen.dart';
import '../../features/profile/presentation/screens/me_screen.dart';
import '../../features/wallet/presentation/screens/wallet_screen.dart';
import '../config/feature_flags.dart';
import '../../features/calls/presentation/screens/call_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';

class AppRouter {
  static const String splash = '/';
  static const String welcome = '/welcome';
  static const String phoneEntry = '/auth/phone';
  static const String otpVerification = '/auth/otp';
  static const String profileSetup = '/auth/profile';
  static const String chats = '/chats';
  static const String chatDetail = '/chats/:id';
  static const String contacts = '/contacts';
  static const String discover = '/discover';
  static const String me = '/me';
  static const String wallet = '/wallet';
  static const String call = '/call/:id';
  static const String settings = '/me/settings';

  static GoRouter createRouter() {
    return GoRouter(
      initialLocation: splash,
      routes: [
        GoRoute(
          path: splash,
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: welcome,
          builder: (context, state) => const WelcomeScreen(),
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
          path: chats,
          builder: (context, state) => const ChatListScreen(),
        ),
        GoRoute(
          path: chatDetail,
          builder: (context, state) {
            final chatId = state.pathParameters['id'] ?? '';
            return ChatDetailScreen(chatId: chatId);
          },
        ),
        GoRoute(
          path: contacts,
          builder: (context, state) => const ContactsScreen(),
        ),
        GoRoute(
          path: discover,
          builder: (context, state) => const DiscoverScreen(),
        ),
        GoRoute(
          path: me,
          builder: (context, state) => const MeScreen(),
        ),
        if (FeatureFlags.wallet)
          GoRoute(
            path: wallet,
            builder: (context, state) => const WalletScreen(),
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
