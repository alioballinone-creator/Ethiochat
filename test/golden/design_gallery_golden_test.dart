import 'package:ethiochat/core/design/gallery/design_gallery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('DesignGallery golden light', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    
    await tester.pumpWidget(
      const MaterialApp(
        themeMode: ThemeMode.light,
        home: DesignGallery(),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(DesignGallery),
      matchesGoldenFile('../goldens/design_gallery_light.png'),
    );
  });
}
