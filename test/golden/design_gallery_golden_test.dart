import 'package:ethiochat/core/design/gallery/design_gallery.dart';
import 'package:ethiochat/core/design/ethio_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('DesignGallery golden light', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildEthioTheme(Brightness.light),
        home: const DesignGallery(),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(DesignGallery),
      matchesGoldenFile('../goldens/design_gallery_light.png'),
    );
  });
}
