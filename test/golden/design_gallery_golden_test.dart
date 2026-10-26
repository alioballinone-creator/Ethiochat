import 'package:ethiochat/core/design/ethio_theme.dart';
import 'package:ethiochat/core/design/gallery/design_gallery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
