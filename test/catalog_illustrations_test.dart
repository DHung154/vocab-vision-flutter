import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giao_dien/catalog_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every starter word has bundled media with attribution', () {
    expect(catalogWords, hasLength(300));
    expect(catalogWords.every((word) => word.hasOfflineImage), isTrue);
    final newImages = catalogWords.where(
      (word) => word.imageUrl!.startsWith('assets/catalog/illustrations/'),
    );
    expect(newImages, hasLength(285));
    for (final word in newImages) {
      expect(word.imageLicense, 'CC BY-SA 4.0');
      expect(word.imageAttribution, isNotEmpty);
      // Attaching media must not create fictional publication/review metadata.
      expect(word.reviewedBy, isNull);
    }
  });

  test(
    'all illustrations are packaged, decodable and match the manifest',
    () async {
      final manifest =
          jsonDecode(
                await rootBundle.loadString(
                  'assets/catalog/illustrations/manifest.json',
                ),
              )
              as Map<String, dynamic>;
      final records = (manifest['images'] as List).cast<Map<String, dynamic>>();
      final ids = records.map((record) => record['id']).toSet();
      expect(ids, hasLength(285));
      final words = catalogWords.where(
        (word) => word.imageUrl!.startsWith('assets/catalog/illustrations/'),
      );
      expect(ids, words.map((word) => word.id).toSet());
      for (final word in words) {
        final bytes = await rootBundle.load(word.imageUrl!);
        final codec = await ui.instantiateImageCodec(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        );
        final frame = await codec.getNextFrame();
        expect(frame.image.width, 640, reason: word.id);
        expect(frame.image.height, 400, reason: word.id);
        frame.image.dispose();
        codec.dispose();
      }
    },
  );
}
