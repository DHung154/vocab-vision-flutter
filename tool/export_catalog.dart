import 'dart:convert';
import 'dart:io';

import 'package:giao_dien/catalog_data.dart';

void main() {
  final destination = File('build/catalog-media/catalog.json');
  destination.parent.createSync(recursive: true);
  destination.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert([
      for (final word in catalogWords)
        {
          'id': word.id,
          'english': word.english,
          'vietnamese': word.vietnamese,
          'topic': word.topic,
          'image': word.imageUrl,
        },
    ]),
  );
}
