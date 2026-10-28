import 'package:drift/native.dart';
import 'package:ethiochat/core/db/app_database.dart';
import 'package:ethiochat/core/design/ethio_theme.dart';
import 'package:ethiochat/core/providers/app_providers.dart';
import 'package:ethiochat/features/auth/presentation/screens/otp_verification_screen.dart';
import 'package:ethiochat/features/auth/presentation/screens/phone_entry_screen.dart';
import 'package:ethiochat/features/auth/presentation/screens/profile_setup_screen.dart';
import 'package:ethiochat/features/auth/presentation/screens/welcome_screen.dart';
import 'package:ethiochat/features/calls/presentation/screens/call_screen.dart';
import 'package:ethiochat/features/chat/presentation/screens/chat_detail_screen.dart';
import 'package:ethiochat/features/chat/presentation/screens/chat_info_screen.dart';
import 'package:ethiochat/features/chat/presentation/screens/chat_list_screen.dart';
import 'package:ethiochat/features/chat/presentation/screens/new_chat_screen.dart';
import 'package:ethiochat/features/chat/presentation/screens/new_group_screen.dart';
import 'package:ethiochat/features/chat/presentation/screens/group_info_screen.dart';
import 'package:ethiochat/features/contacts/presentation/screens/contact_requests_screen.dart';
import 'package:ethiochat/features/contacts/presentation/screens/contacts_screen.dart';
import 'package:ethiochat/features/discover/presentation/screens/article_reader_screen.dart';
import 'package:ethiochat/features/discover/presentation/screens/channel_detail_screen.dart';
import 'package:ethiochat/features/discover/presentation/screens/channels_screen.dart';
import 'package:ethiochat/features/discover/presentation/screens/discover_screen.dart';
import 'package:ethiochat/features/discover/presentation/screens/mini_program_screen.dart';
import 'package:ethiochat/features/discover/presentation/screens/nearby_screen.dart';
import 'package:ethiochat/features/discover/presentation/screens/official_account_screen.dart';
import 'package:ethiochat/features/discover/presentation/screens/official_accounts_screen.dart';
import 'package:ethiochat/features/discover/presentation/screens/scan_screen.dart';
import 'package:ethiochat/features/moments/presentation/screens/moments_feed_screen.dart';
import 'package:ethiochat/features/onboarding/presentation/screens/tips_screen.dart';
import 'package:ethiochat/features/profile/presentation/screens/me_screen.dart';
import 'package:ethiochat/features/profile/presentation/screens/my_qr_screen.dart';
import 'package:ethiochat/features/search/presentation/screens/search_screen.dart';
import 'package:ethiochat/features/settings/presentation/screens/settings_account_screen.dart';
import 'package:ethiochat/features/settings/presentation/screens/report_screen.dart';
import 'package:ethiochat/features/settings/presentation/screens/settings_app_screens.dart';
import 'package:ethiochat/features/settings/presentation/screens/settings_help_screen.dart';
import 'package:ethiochat/features/settings/presentation/screens/settings_privacy_screen.dart';
import 'package:ethiochat/features/settings/presentation/screens/settings_screen.dart';
import 'package:ethiochat/features/wallet/presentation/screens/bills_screen.dart';
import 'package:ethiochat/features/wallet/presentation/screens/receive_money_screen.dart';
import 'package:ethiochat/features/wallet/presentation/screens/red_packet_screen.dart';
import 'package:ethiochat/features/wallet/presentation/screens/send_money_screen.dart';
import 'package:ethiochat/features/wallet/presentation/screens/top_up_screen.dart';
import 'package:ethiochat/features/wallet/presentation/screens/transactions_screen.dart';
import 'package:ethiochat/features/wallet/presentation/screens/wallet_pin_screen.dart';
import 'package:ethiochat/features/wallet/presentation/screens/wallet_receipt_screen.dart';
import 'package:ethiochat/features/wallet/presentation/screens/wallet_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

typedef ScreenBuilder = Widget Function();

class _Screen {
  const _Screen(this.name, this.builder);

  final String name;
  final ScreenBuilder builder;
}

final _screens = <_Screen>[
  _Screen('welcome', () => const WelcomeScreen()),
  _Screen('phone', () => const PhoneEntryScreen()),
  _Screen('otp', () => const OtpVerificationScreen(phone: '+251912345678')),
  _Screen('profile-setup', () => const ProfileSetupScreen()),
  _Screen('chats', () => const ChatListScreen()),
  _Screen('chat', () => const ChatDetailScreen(chatId: '1')),
  _Screen('chat-info', () => const ChatInfoScreen(chatId: '1')),
  _Screen('new-chat', () => const NewChatScreen()),
  _Screen('new-group', () => const NewGroupScreen()),
  _Screen('contacts', () => const ContactsScreen()),
  _Screen('discover', () => const DiscoverScreen()),
  _Screen('moments', () => const MomentsFeedScreen()),
  _Screen('me', () => const MeScreen()),
  _Screen('my-qr', () => const MyQrScreen()),
  _Screen('search', () => const SearchScreen()),
  _Screen('settings', () => const SettingsScreen()),
  _Screen('wallet', () => const WalletScreen()),
  _Screen('group-info', () => const GroupInfoScreen(chatId: '4')),
  _Screen('contact-requests', () => const ContactRequestsScreen()),
  _Screen('channels', () => const ChannelsScreen()),
  _Screen('channel-detail', () => const ChannelDetailScreen(channelId: '')),
  _Screen('official-accounts', () => const OfficialAccountsScreen()),
  _Screen('official-account', () => const OfficialAccountScreen(accountId: '')),
  _Screen(
    'article-reader',
    () => const ArticleReaderScreen(accountId: '', articleIndex: 0),
  ),
  _Screen('mini-program', () => const MiniProgramScreen(programId: '')),
  _Screen('nearby', () => const NearbyScreen()),
  _Screen('scan', () => const ScanScreen()),
  _Screen('tips', () => const TipsScreen()),
  _Screen('report', () => const ReportScreen(targetName: 'Abebe Kebede')),
  _Screen('account-security', () => const AccountSecurityScreen()),
  _Screen('notifications', () => const NotificationSettingsScreen()),
  _Screen('chat-backup', () => const ChatBackupScreen()),
  _Screen('help', () => const HelpScreen()),
  _Screen('about', () => const AboutScreen()),
  _Screen('privacy', () => const PrivacySettingsScreen()),
  _Screen('blocked-users', () => const BlockedUsersScreen()),
  _Screen('wallet-bills', () => const BillsScreen()),
  _Screen('wallet-receive', () => const ReceiveMoneyScreen()),
  _Screen('wallet-redpacket', () => const RedPacketScreen()),
  _Screen('wallet-send', () => const SendMoneyScreen()),
  _Screen('wallet-topup', () => const TopUpScreen()),
  _Screen('wallet-transactions', () => const TransactionsScreen()),
  _Screen('wallet-pin', () => const WalletPinScreen()),
  _Screen('wallet-receipt', () => const WalletReceiptScreen()),
  _Screen('call', () => const CallScreen(isVideo: false, isIncoming: true)),
];

Future<void> _pumpScreen(
  WidgetTester tester, {
  required Widget child,
  required Size size,
  required double textScale,
  required Brightness brightness,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildEthioTheme(brightness),
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
            ),
            child: child,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

void main() {
  const sizes = <String, Size>{
    '360x640': Size(360, 640),
    '412x915': Size(412, 915),
  };

  for (final entry in sizes.entries) {
    for (final scale in <double>[1, 2]) {
      for (final brightness in Brightness.values) {
        final mode = brightness == Brightness.light ? 'light' : 'dark';
        group('${entry.key} · ${scale}x · $mode', () {
          for (final screen in _screens) {
            testWidgets(
              '${screen.name} lays out without overflow',
              (tester) async {
                await _pumpScreen(
                  tester,
                  child: screen.builder(),
                  size: entry.value,
                  textScale: scale,
                  brightness: brightness,
                );

                expect(
                  tester.takeException(),
                  isNull,
                  reason:
                      '${screen.name} threw while laying out at ${entry.key}, '
                      'text scale ${scale}x, $mode',
                );

                // Dispose the screen so timers and controllers are released.
                // Drift schedules a zero-duration timer when a query stream is
                // cancelled; pump a few frames so it cannot outlive the test.
                await tester.pumpWidget(const SizedBox.shrink());
                await tester.pump(const Duration(milliseconds: 1));
                await tester.pump(const Duration(milliseconds: 1));
                expect(tester.takeException(), isNull);
              },
            );
          }
        });
      }
    }
  }
}
