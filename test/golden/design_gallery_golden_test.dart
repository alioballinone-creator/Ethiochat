import 'package:ethiochat/core/design/ethio_theme.dart';
import 'package:ethiochat/core/design/gallery/design_gallery.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _loadFonts() async {
  final poppinsRegular = rootBundle.load('assets/fonts/Poppins-Regular.ttf');
  final poppinsMedium = rootBundle.load('assets/fonts/Poppins-Medium.ttf');
  final poppinsSemiBold = rootBundle.load('assets/fonts/Poppins-SemiBold.ttf');
  final poppinsBold = rootBundle.load('assets/fonts/Poppins-Bold.ttf');
  final noto = rootBundle.load('assets/fonts/NotoSansEthiopic.ttf');
  final inter = rootBundle.load('assets/fonts/Inter.ttf');

  final loader = FontLoader('Poppins')
    ..addFont(poppinsRegular)
    ..addFont(poppinsMedium)
    ..addFont(poppinsSemiBold)
    ..addFont(poppinsBold);
  await loader.load();

  final notoLoader = FontLoader('NotoSansEthiopic')..addFont(noto);
  await notoLoader.load();

  final interLoader = FontLoader('Inter')..addFont(inter);
  await interLoader.load();
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
  await tester.pumpAndSettle(const Duration(milliseconds: 500));
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadFonts();
  });

  testWidgets('DesignGallery golden light', (tester) async {
    await _pumpGallery(tester, Brightness.light);
    await expectLater(
      find.byType(DesignGallery),
      matchesGoldenFile('../goldens/design_gallery_light.png'),
    );
  });

  testWidgets('DesignGallery golden dark', (tester) async {
    await _pumpGallery(tester, Brightness.dark);
    await expectLater(
      find.byType(DesignGallery),
      matchesGoldenFile('../goldens/design_gallery_dark.png'),
    );
  });
}
