import 'package:ethiochat/core/design/gallery/design_gallery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('DesignGallery golden light', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        themeMode: ThemeMode.light,
        home: DesignGallery(),
      ),
    );
    await expectLater(
      find.byType(DesignGallery),
      matchesGoldenFile('design_gallery_light.png'),
    );
  });
}
