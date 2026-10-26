import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Loads the real brand fonts for every test so golden images and text layout
/// match the app. Fonts are read from disk because font assets declared under
/// `fonts:` in pubspec.yaml are not served by the test asset bundle.
Future<ByteData> _load(String path) async {
  final bytes = await File(path).readAsBytes();
  return ByteData.sublistView(bytes);
}

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  // A blinking caret schedules a frame forever, which would make
  // `pumpAndSettle` time out whenever a text field has focus.
  EditableText.debugDeterministicCursor = true;
  SharedPreferences.setMockInitialValues(<String, Object>{});

  final poppins = FontLoader('Poppins')
    ..addFont(_load('assets/fonts/Poppins-Regular.ttf'))
    ..addFont(_load('assets/fonts/Poppins-Medium.ttf'))
    ..addFont(_load('assets/fonts/Poppins-SemiBold.ttf'))
    ..addFont(_load('assets/fonts/Poppins-Bold.ttf'));
  await poppins.load();

  final noto = FontLoader('NotoSansEthiopic')
    ..addFont(_load('assets/fonts/NotoSansEthiopic.ttf'))
    ..addFont(_load('assets/fonts/NotoSansEthiopic-Bold.ttf'));
  await noto.load();

  await testMain();
}
