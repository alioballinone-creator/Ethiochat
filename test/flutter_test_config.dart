import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  // Load fonts for golden tests
  final fontLoader = FontLoader('Poppins')
    ..addFont(rootBundle.load('assets/fonts/Poppins-Regular.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Poppins-Medium.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Poppins-SemiBold.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Poppins-Bold.ttf'));
  await fontLoader.load();
  
  final notoLoader = FontLoader('NotoSansEthiopic')
    ..addFont(rootBundle.load('assets/fonts/NotoSansEthiopic.ttf'))
    ..addFont(rootBundle.load('assets/fonts/NotoSansEthiopic-Bold.ttf'));
  await notoLoader.load();
  
  await testMain();
}
