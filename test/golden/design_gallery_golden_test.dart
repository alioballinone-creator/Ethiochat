import 'dart:io';

import 'package:ethiochat/core/design/ethio_theme.dart';
import 'package:ethiochat/core/design/gallery/design_gallery.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _loadFonts() async {
  final fonts = <String, String>{
    'Poppins': 'assets/fonts/Poppins-Regular.ttf',
    'Poppins-Medium': 'assets/fonts/Poppins-Medium.ttf',
    'Poppins-SemiBold': 'assets/fonts/Poppins-SemiBold.ttf',
    'Poppins-Bold': 'assets/fonts/Poppins-Bold.ttf',
    'NotoSansEthiopic': 'assets/fonts/NotoSansEthiopic.ttf',
    'Inter': 'assets/fonts/Inter.ttf',
  };

  for (final entry in fonts.entries) {
    final loader = FontLoader(entry.key);
    final data = await rootBundle.load(entry.value);
    loader.addFont(Future.value(data));
    await loader.load();
  }
}

Future<void> _pumpGallery(WidgetTester tester, Brightness brightness) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildEthioTheme(brightness),
      home: const DesignGallery(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadFonts();
  });

  testWidgets('DesignGallery golden light', (tester) async {
    await _pumpGallery(tester, Brightness.light);
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
    await expectLater(
      find.byType(DesignGallery),
      matchesGoldenFile('../goldens/design_gallery_light.png'),
    );
  });

  testWidgets('DesignGallery golden dark', (tester) async {
    await _pumpGallery(tester, Brightness.dark);
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
    await expectLater(
      find.byType(DesignGallery),
      matchesGoldenFile('../goldens/design_gallery_dark.png'),
    );
  });
}
