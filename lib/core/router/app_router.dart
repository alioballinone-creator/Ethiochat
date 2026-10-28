import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/presentation/screens/otp_verification_screen.dart';
import '../../features/auth/presentation/screens/phone_entry_screen.dart';
import '../../features/auth/presentation/screens/profile_setup_screen.dart';
import '../../features/auth/presentation/screens/welcome_screen.dart';
import '../../features/calls/presentation/screens/call_screen.dart';
import '../../features/chat/presentation/screens/chat_detail_screen.dart';
import '../../features/chat/presentation/screens/chat_info_screen.dart';
import '../../features/chat/presentation/screens/chat_list_screen.dart';
import '../../features/chat/presentation/screens/group_info_screen.dart';
import '../../features/chat/presentation/screens/new_chat_screen.dart';
import '../../features/chat/presentation/screens/new_group_screen.dart';
import '../../features/contacts/presentation/screens/contact_requests_screen.dart';
import '../../features/contacts/presentation/screens/contacts_screen.dart';
import '../../features/discover/presentation/screens/article_reader_screen.dart';
import '../../features/discover/presentation/screens/channel_detail_screen.dart';
import '../../features/discover/presentation/screens/channels_screen.dart';
import '../../features/discover/presentation/screens/discover_screen.dart';
import '../../features/discover/presentation/screens/mini_program_screen.dart';
import '../../features/discover/presentation/screens/nearby_screen.dart';
import '../../features/discover/presentation/screens/official_account_screen.dart';
import '../../features/discover/presentation/screens/official_accounts_screen.dart';
import '../../features/discover/presentation/screens/scan_screen.dart';
import '../../features/moments/presentation/screens/moments_feed_screen.dart';
import '../../features/onboarding/presentation/screens/tips_screen.dart';
import '../../features/profile/presentation/screens/me_screen.dart';
import '../../features/profile/presentation/screens/my_qr_screen.dart';
import '../../features/search/presentation/screens/search_screen.dart';
import '../../features/settings/presentation/screens/report_screen.dart';
import '../../features/settings/presentation/screens/settings_account_screen.dart';
import '../../features/settings/presentation/screens/settings_app_screens.dart';
import '../../features/settings/presentation/screens/settings_help_screen.dart';
import '../../features/settings/presentation/screens/settings_privacy_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/wallet/domain/entities/wallet_entry.dart';
import '../../features/wallet/presentation/screens/bills_screen.dart';
import '../../features/wallet/presentation/screens/receive_money_screen.dart';
import '../../features/wallet/presentation/screens/red_packet_screen.dart';
import '../../features/wallet/presentation/screens/send_money_screen.dart';
import '../../features/wallet/presentation/screens/top_up_screen.dart';
import '../../features/wallet/presentation/screens/transactions_screen.dart';
import '../../features/wallet/presentation/screens/wallet_pin_screen.dart';
import '../../features/wallet/presentation/screens/wallet_receipt_screen.dart';
import '../../features/wallet/presentation/screens/wallet_screen.dart';
import '../config/env.dart';
import '../config/feature_flags.dart';
import '../screens/splash_screen.dart';
import 'main_shell.dart';

class AppRouter {
  static const String splash = '/';
  static const String welcome = '/welcome';
  static const String phoneEntry = '/auth/phone';
  static const String otpVerification = '/auth/otp';
  static const String profileSetup = '/auth/profile';
  static const String chats = '/chats';
  static const String chatDetail = '/chats/:id';
  static const String chatInfo = '/chats/:id/info';
  static const String groupInfo = '/chats/:id/group';
  static const String newChat = '/new-chat';
  static const String newGroup = '/new-group';
  static const String search = '/search';
  static const String moments = '/discover/moments';
  static const String channels = '/discover/channels';
  static const String officialAccounts = '/discover/official';
  static const String scan = '/scan';
  static const String nearby = '/discover/nearby';
  static const String myQr = '/me/qr';
  static const String editProfile = '/me/profile';
  static const String contacts = '/contacts';
  static const String contactRequests = '/contacts/requests';
  static const String discover = '/discover';
  static const String me = '/me';
  static const String wallet = '/wallet';
  static const String call = '/call/:id';
  static const String settings = '/me/settings';

  static const _signedOutRoutes = <String>{
    splash,
    welcome,
    phoneEntry,
    otpVerification,
  };

  static bool get _hasSession {
    if (!Env.hasSupabase) return false;
    return Supabase.instance.client.auth.currentSession != null;
  }

  static GoRouter createRouter({String initialLocation = splash}) {
    return GoRouter(
      initialLocation: initialLocation,
      redirect: (context, state) {
        // Credential-free debug builds remain usable for local UI development.
        // Release builds without Supabase never reach the router because the
        // app shell shows the configuration error screen instead.
        if (!Env.hasSupabase) return null;

        final signedIn = _hasSession;
        final location = state.matchedLocation;
        if (!signedIn) {
          return _signedOutRoutes.contains(location) ? null : welcome;
        }
        if (location == welcome ||
            location == phoneEntry ||
            location == otpVerification) {
          return chats;
        }
        return null;
      },
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
          path: '/onboarding/tips',
          builder: (context, state) => const TipsScreen(),
        ),
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              MainShell(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: chats,
                  builder: (context, state) {
                    final filter = int.tryParse(
                          state.uri.queryParameters['filter'] ?? '',
                        ) ??
                        0;
                    return ChatListScreen(initialFilter: filter);
                  },
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: contacts,
                  builder: (context, state) => const ContactsScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: discover,
                  builder: (context, state) => const DiscoverScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: me,
                  builder: (context, state) => const MeScreen(),
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: chatDetail,
          builder: (context, state) {
            final chatId = state.pathParameters['id'] ?? '';
            return ChatDetailScreen(chatId: chatId);
          },
          routes: [
            GoRoute(
              path: 'info',
              builder: (context, state) {
                final chatId = state.pathParameters['id'] ?? '';
                return ChatInfoScreen(chatId: chatId);
              },
            ),
            GoRoute(
              path: 'group',
              builder: (context, state) {
                final chatId = state.pathParameters['id'] ?? '';
                return GroupInfoScreen(chatId: chatId);
              },
            ),
          ],
        ),
        GoRoute(
          path: newChat,
          builder: (context, state) => const NewChatScreen(),
        ),
        GoRoute(
          path: newGroup,
          builder: (context, state) => const NewGroupScreen(),
        ),
        GoRoute(
          path: contactRequests,
          builder: (context, state) => const ContactRequestsScreen(),
        ),
        GoRoute(
          path: search,
          builder: (context, state) => const SearchScreen(),
        ),
        GoRoute(
          path: moments,
          builder: (context, state) => const MomentsFeedScreen(),
        ),
        GoRoute(
          path: channels,
          builder: (context, state) => const ChannelsScreen(),
          routes: [
            GoRoute(
              path: ':channelId',
              builder: (context, state) => ChannelDetailScreen(
                channelId: state.pathParameters['channelId'] ?? '',
              ),
            ),
          ],
        ),
        GoRoute(
          path: officialAccounts,
          builder: (context, state) => const OfficialAccountsScreen(),
          routes: [
            GoRoute(
              path: ':accountId',
              builder: (context, state) => OfficialAccountScreen(
                accountId: state.pathParameters['accountId'] ?? '',
              ),
              routes: [
                GoRoute(
                  path: 'article/:index',
                  builder: (context, state) => ArticleReaderScreen(
                    accountId: state.pathParameters['accountId'] ?? '',
                    articleIndex:
                        int.tryParse(state.pathParameters['index'] ?? '') ?? 0,
                  ),
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/discover/mini/:programId',
          builder: (context, state) => MiniProgramScreen(
            programId: state.pathParameters['programId'] ?? '',
          ),
        ),
        GoRoute(
          path: scan,
          builder: (context, state) => ScanScreen(
            forPayment: state.uri.queryParameters['pay'] == 'true',
          ),
        ),
        GoRoute(
          path: nearby,
          builder: (context, state) => const NearbyScreen(),
        ),
        GoRoute(
          path: editProfile,
          builder: (context, state) =>
              const ProfileSetupScreen(isEditing: true),
        ),
        GoRoute(
          path: myQr,
          builder: (context, state) => const MyQrScreen(),
        ),
        GoRoute(
          path: call,
          builder: (context, state) {
            final isVideo = state.uri.queryParameters['video'] == 'true';
            final isIncoming = state.uri.queryParameters['incoming'] == 'true';
            return CallScreen(
              isVideo: isVideo,
              isIncoming: isIncoming,
              chatId: state.pathParameters['id'] ?? '',
              callId: state.uri.queryParameters['callId'] ?? '',
            );
          },
        ),
        GoRoute(
          path: settings,
          builder: (context, state) => const SettingsScreen(),
          routes: [
            GoRoute(
              path: 'account',
              builder: (context, state) => const AccountSecurityScreen(),
            ),
            GoRoute(
              path: 'privacy',
              builder: (context, state) => const PrivacySettingsScreen(),
              routes: [
                GoRoute(
                  path: 'blocked',
                  builder: (context, state) => const BlockedUsersScreen(),
                ),
              ],
            ),
            GoRoute(
              path: 'notifications',
              builder: (context, state) => const NotificationSettingsScreen(),
            ),
            GoRoute(
              path: 'backup',
              builder: (context, state) => const ChatBackupScreen(),
            ),
            GoRoute(
              path: 'storage',
              builder: (context, state) => const StorageManagerScreen(),
            ),
            GoRoute(
              path: 'data-saver',
              builder: (context, state) => const DataSaverScreen(),
            ),
            GoRoute(
              path: 'help',
              builder: (context, state) => const HelpScreen(),
            ),
            GoRoute(
              path: 'about',
              builder: (context, state) => const AboutScreen(),
            ),
          ],
        ),
        GoRoute(
          path: '/report',
          builder: (context, state) => ReportScreen(
            targetName: state.uri.queryParameters['target'] ?? 'Account',
            targetId: state.uri.queryParameters['id'] ?? '',
            targetType: state.uri.queryParameters['type'] ?? 'account',
          ),
        ),
        if (FeatureFlags.wallet) ...[
          GoRoute(
            path: wallet,
            builder: (context, state) => const WalletScreen(),
          ),
          GoRoute(
            path: '/wallet/send',
            builder: (context, state) => const SendMoneyScreen(),
          ),
          GoRoute(
            path: '/wallet/receive',
            builder: (context, state) => const ReceiveMoneyScreen(),
          ),
          GoRoute(
            path: '/wallet/top-up',
            builder: (context, state) => const TopUpScreen(),
          ),
          GoRoute(
            path: '/wallet/bills',
            builder: (context, state) => const BillsScreen(),
          ),
          GoRoute(
            path: '/wallet/red-packet',
            builder: (context, state) => const RedPacketScreen(),
          ),
          GoRoute(
            path: '/wallet/transactions',
            builder: (context, state) => const TransactionsScreen(),
          ),
          GoRoute(
            path: '/wallet/pin',
            builder: (context, state) => WalletPinScreen(
              request:
                  state.extra is PinRequest ? state.extra! as PinRequest : null,
            ),
          ),
          GoRoute(
            path: '/wallet/receipt',
            builder: (context, state) => WalletReceiptScreen(
              receipt: state.extra is WalletReceipt
                  ? state.extra! as WalletReceipt
                  : null,
            ),
          ),
        ],
      ],
    );
  }
}
