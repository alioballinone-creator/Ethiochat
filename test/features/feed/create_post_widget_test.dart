import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ethio_chat/features/feed/presentation/screens/create_post_screen.dart';

void main() {
  testWidgets('create post shows live character counter and visibility choice',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CreatePostScreen()));
    await tester.pump();
    expect(find.byKey(const Key('create-post-char-counter')), findsOneWidget);
    expect(find.text('0/500'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'hello');
    await tester.pump();
    expect(find.text('5/500'), findsOneWidget);
    expect(find.byKey(const Key('create-post-visibility')), findsOneWidget);
    await tester.tap(find.byKey(const Key('create-post-visibility')));
    await tester.pumpAndSettle();
    expect(find.text('Public').hitTestable(), findsWidgets);
    expect(find.text('Followers').hitTestable(), findsOneWidget);
  });
}
