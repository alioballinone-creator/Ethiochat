import 'package:drift/native.dart';
import 'package:ethiochat/core/db/app_database.dart';
import 'package:ethiochat/core/design/ethio_theme.dart';
import 'package:ethiochat/core/design/widgets/chat_list_tile.dart';
import 'package:ethiochat/core/design/widgets/ethio_bottom_nav.dart';
import 'package:ethiochat/core/providers/app_providers.dart';
import 'package:ethiochat/core/router/app_router.dart';
import 'package:ethiochat/features/chat/presentation/screens/chat_list_screen.dart';
import 'package:ethiochat/features/chats/application/chat_providers.dart';
import 'package:ethiochat/features/chats/data/repositories/chat_repository_impl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  late AppDatabase db;
  late GoRouter router;
  late ProviderContainer container;

  ThemeData testTheme() {
    final base = buildEthioTheme(Brightness.light);
    return base.copyWith(
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _NoTransitionsBuilder(),
          TargetPlatform.iOS: _NoTransitionsBuilder(),
          TargetPlatform.macOS: _NoTransitionsBuilder(),
          TargetPlatform.windows: _NoTransitionsBuilder(),
          TargetPlatform.linux: _NoTransitionsBuilder(),
          TargetPlatform.fuchsia: _NoTransitionsBuilder(),
        },
      ),
    );
  }

  /// Advances a bounded amount of time. An indeterminate spinner or a blinking
  /// caret must fail the assertion below, not hang the whole test job.
  Future<void> settle(WidgetTester tester) async {
    // Drift and the initial route animation both need alternating real time
    // (for async work) and frames (for the provider rebuild/transition).
    for (var round = 0; round < 3; round++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }
  }

  Future<void> disposeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
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
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        // The test seeds before the first frame so the UI never races seeding.
        demoSeedProvider.overrideWith((ref) => Future<void>.value()),
      ],
    );
    addTearDown(container.dispose);
    // Run before container.dispose/router.dispose/db.close in the LIFO
    // teardown order so stream cancellations are flushed while the DB is open.
    addTearDown(() => disposeApp(tester));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: testTheme(),
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
    final seeded = await db.select(db.conversations).get();
    await tester.pump();
    final listViews = find.byType(ListView);
    final chatList = listViews.last;
    final scrollable = tester.state<ScrollableState>(
      find.descendant(of: chatList, matching: find.byType(Scrollable)).first,
    );
    final tileRects =
        find.byType(ChatListTile, skipOffstage: false).evaluate().map((e) {
      final box = e.renderObject! as RenderBox;
      return '${box.localToGlobal(Offset.zero)} ${box.size}';
    }).toList();
    final screenContext = tester.element(find.byType(ChatListScreen));
    final mq = MediaQuery.of(screenContext);
    final column =
        find.ancestor(of: chatList, matching: find.byType(Column)).first;
    final columns = find
        .ancestor(of: chatList, matching: find.byType(Column))
        .evaluate()
        .map((e) {
      final box = e.renderObject! as RenderBox;
      return box.size.toString();
    }).toList();
    final nav = find.byType(EthioBottomNav);
    final safeArea = find
        .descendant(
          of: find.byType(ChatListScreen),
          matching: find.byType(SafeArea),
        )
        .first;
    final refresh = find.ancestor(
      of: chatList,
      matching: find.byType(RefreshIndicator),
    );
    debugPrint(
      'CHATLIST LAYOUT nav=${tester.getRect(nav)} '
      'scaffold=${tester.getRect(find.byType(Scaffold).first)} '
      'safeArea=${tester.getRect(safeArea)} columns=$columns '
      'filterRect=${tester.getRect(listViews.first)} '
      'CHATLIST TEST sameContainer='
      '${identical(ProviderScope.containerOf(screenContext), container)} '
      'tiles=${find.byType(ChatListTile).evaluate().length} '
      'tilesAll=${find.byType(ChatListTile, skipOffstage: false).evaluate().length} '
      'abebeAll=${find.text('Abebe Kebede', skipOffstage: false).evaluate().length} '
      'listViews=${listViews.evaluate().length} '
      'listViewsAll=${find.byType(ListView, skipOffstage: false).evaluate().length} '
      'spinners=${find.byType(CircularProgressIndicator).evaluate().length} '
      'size=${tester.getSize(find.byType(ChatListScreen))} '
      'mqSize=${mq.size} viewInsets=${mq.viewInsets} padding=${mq.padding} '
      'columnSize=${tester.getSize(column)} '
      'refreshSize=${refresh.evaluate().isEmpty ? 'none' : tester.getSize(refresh)} '
      'listRect=${tester.getRect(chatList)} '
      'pixels=${scrollable.position.pixels} '
      'max=${scrollable.position.maxScrollExtent} '
      'viewport=${scrollable.position.viewportDimension} '
      'tileRects=$tileRects',
    );
    final visibleText = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data)
        .whereType<String>()
        .toList();
    expect(
      find.text('Abebe Kebede'),
      findsOneWidget,
      reason: 'stored=${seeded.map((s) => s.title).toList()} '
          'visible=$visibleText '
          'seed=${container.read(demoSeedProvider)} '
          'summaries=${container.read(conversationSummariesProvider)}',
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
    await disposeApp(tester);
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

    final messages = await db.select(db.messages).get();
    final sent = messages.where((m) => m.conversationId == '1').toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    expect(sent.last.body, 'Hello from test');
    expect(sent.last.senderId, 'me');

    // Header opens chat info; mute persists to the database.
    await tester.tap(find.text('Abebe Kebede').first);
    await settle(tester);
    expect(find.text('Chat info'), findsOneWidget);

    await tester.tap(find.text('Mute notifications'));
    await settle(tester);
    final conversation = await (db.select(db.conversations)
          ..where((c) => c.id.equals('1')))
        .getSingle();
    expect(conversation.mutedUntil, isNotNull);

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
    await disposeApp(tester);
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
    await disposeApp(tester);
  });

  testWidgets('new chat opens a direct conversation from a contact',
      (tester) async {
    await pumpApp(tester, at: '/new-chat');

    expect(find.text('New chat'), findsWidgets);
    await tester.tap(find.text('Hanna Girma'));
    await settle(tester);

    expect(find.text('Message'), findsOneWidget);
    expect(find.text('Hanna Girma'), findsWidgets);

    final summaries = await db.select(db.conversations).get();
    final hanna = summaries.where((s) => s.title == 'Hanna Girma');
    expect(hanna, hasLength(1));
    await disposeApp(tester);
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
    final summaries = await db.select(db.conversations).get();
    final group = summaries.firstWhere((s) => s.title == 'Football team');
    expect(group.type, 'group');
    await disposeApp(tester);
  });
}

class _NoTransitionsBuilder extends PageTransitionsBuilder {
  const _NoTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) =>
      child;
}
