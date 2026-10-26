import 'package:drift/native.dart';
import 'package:ethiochat/core/db/app_database.dart';
import 'package:ethiochat/core/design/ethio_theme.dart';
import 'package:ethiochat/core/providers/app_providers.dart';
import 'package:ethiochat/core/router/app_router.dart';
import 'package:ethiochat/features/chats/data/repositories/chat_repository_impl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  late AppDatabase db;
  late GoRouter router;

  /// Advances a bounded amount of time. An indeterminate spinner or a blinking
  /// caret must fail the assertion below, not hang the whole test job.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> pumpApp(WidgetTester tester, {String at = '/chats'}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    // Seed before the first frame so tests never race the async demo seed.
    await ChatRepositoryImpl(db).seedDemoData();
    router = AppRouter.createRouter(initialLocation: at);
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: buildEthioTheme(Brightness.light),
          routerConfig: router,
        ),
      ),
    );
    await settle(tester);
  }

  testWidgets('bottom navigation reaches every main tab', (tester) async {
    await pumpApp(tester);

    // Chats is the start tab and is seeded from the local database.
    expect(find.text('Chats'), findsWidgets);
    final seeded = await ChatRepositoryImpl(db).watchSummaries().first;
    final visibleText = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data)
        .whereType<String>()
        .toList();
    expect(
      find.text('Abebe Kebede'),
      findsOneWidget,
      reason: 'stored=${seeded.map((s) => s.title).toList()} '
          'visible=$visibleText',
    );

    await tester.tap(find.text('Contacts'));
    await settle(tester);
    expect(find.text('Search contacts'), findsOneWidget);
    // The list is scrollable; the first alphabetical contact is visible.
    expect(find.text('Abebe Kebede'), findsOneWidget);

    await tester.tap(find.text('Discover'));
    await settle(tester);
    expect(find.text('Mini Programs'), findsOneWidget);
    expect(find.text('Moments'), findsOneWidget);

    await tester.tap(find.text('Me'));
    await settle(tester);
    expect(find.text('Ethio ID'), findsNothing);
    expect(find.textContaining('Ethio ID:'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await settle(tester);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);

    await tester.tap(find.text('Appearance'));
    await settle(tester);
    await tester.tap(find.text('Dark'));
    await settle(tester);
    expect(find.text('Dark'), findsOneWidget);

    router.go('/chats');
    await settle(tester);
    expect(find.text('Abebe Kebede'), findsOneWidget);
  });

  testWidgets('opens a seeded chat, sends a message and persists it',
      (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Abebe Kebede'));
    await settle(tester);

    expect(find.text('Message'), findsOneWidget);
    expect(find.text('See you tomorrow'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Hello from test');
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await settle(tester);

    expect(find.text('Hello from test'), findsOneWidget);

    final repo = ChatRepositoryImpl(db);
    final messages = await repo.watchMessages('1').first;
    expect(messages.last.body, 'Hello from test');
    expect(messages.last.senderId, 'me');

    // Header opens chat info; mute persists to the database.
    await tester.tap(find.text('Abebe Kebede').first);
    await settle(tester);
    expect(find.text('Chat info'), findsOneWidget);

    await tester.tap(find.text('Mute notifications'));
    await settle(tester);
    final conversation = await repo.watchConversation('1').first;
    expect(conversation?.mutedUntil, isNotNull);

    await tester.pageBack();
    await settle(tester);

    // Video call opens and the end button returns to the chat.
    await tester.tap(find.byTooltip('Video call'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Video call'), findsWidgets);
    await tester.tap(find.text('End'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Message'), findsOneWidget);
  });

  testWidgets('search finds a message stored in the database', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byTooltip('Search'));
    await settle(tester);
    expect(find.text('Search'), findsWidgets);

    await tester.enterText(find.byType(TextField).first, 'invoice');
    await tester.pump(const Duration(milliseconds: 400));
    await settle(tester);

    expect(find.textContaining('invoice'), findsWidgets);
    expect(find.text('Did you get the invoice?'), findsOneWidget);
  });

  testWidgets('new chat opens a direct conversation from a contact',
      (tester) async {
    await pumpApp(tester, at: '/new-chat');

    expect(find.text('New chat'), findsWidgets);
    await tester.tap(find.text('Hanna Girma'));
    await settle(tester);

    expect(find.text('Message'), findsOneWidget);
    expect(find.text('Hanna Girma'), findsWidgets);

    final repo = ChatRepositoryImpl(db);
    final summaries = await repo.watchSummaries().first;
    final hanna = summaries.where((s) => s.title == 'Hanna Girma');
    expect(hanna, hasLength(1));
  });

  testWidgets('new group creates a group chat and opens it', (tester) async {
    await pumpApp(tester, at: '/new-group');

    expect(find.text('New group'), findsWidgets);
    await tester.tap(find.text('Abebe Kebede'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, 'Football team');
    await tester.pump();
    await tester.tap(find.text('Create'));
    await settle(tester);

    expect(find.text('Football team'), findsWidgets);
    final repo = ChatRepositoryImpl(db);
    final summaries = await repo.watchSummaries().first;
    final group = summaries.firstWhere((s) => s.title == 'Football team');
    expect(group.type.name, 'group');
  });
}
