import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giao_dien/core/media/display_image.dart';

Future<ui.Image> decode(ImageProvider<Object> provider) async {
  final completer = Completer<ui.Image>();
  final stream = provider.resolve(ImageConfiguration.empty);
  late ImageStreamListener listener;
  listener = ImageStreamListener(
    (info, _) {
      completer.complete(info.image.clone());
      stream.removeListener(listener);
    },
    onError: (Object error, StackTrace? stack) {
      completer.completeError(error, stack);
      stream.removeListener(listener);
    },
  );
  stream.addListener(listener);
  return completer.future;
}

void main() {
  test('nearby display sizes share a bounded decode request', () {
    const source = AssetImage('assets/catalog/e4/pencil.jpg');
    final first =
        imageForDisplay(source, const Size(390, 260), 2) as ResizeImage;
    final second =
        imageForDisplay(source, const Size(392, 262), 2) as ResizeImage;
    expect(first.width, second.width);
    expect(first.height, second.height);
    final large =
        imageForDisplay(source, const Size(2000, 3000), 4) as ResizeImage;
    expect(large.width, 2048);
    expect(large.height, 2048);
    expect(large.allowUpscaling, isFalse);
  });

  testWidgets('large photos decode fewer pixels while preserving aspect ratio', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(
        const Rect.fromLTWH(0, 0, 4000, 3000),
        Paint()..color = Colors.blue,
      );
      final picture = recorder.endRecording();
      final original = await picture.toImage(4000, 3000);
      final bytes = await original.toByteData(format: ui.ImageByteFormat.png);
      final resized = await decode(
        imageForDisplay(
          MemoryImage(bytes!.buffer.asUint8List()),
          const Size(480, 360),
          2,
        ),
      );
      expect(resized.width, 960);
      expect(resized.height, 720);
      expect(resized.width / resized.height, original.width / original.height);
      final originalBytes = original.width * original.height * 4;
      final decodedBytes = resized.width * resized.height * 4;
      expect(decodedBytes, lessThan(originalBytes * .1));
      final output = File('build/qa-performance/image-decoding.json');
      await output.parent.create(recursive: true);
      await output.writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'source_width': original.width,
          'source_height': original.height,
          'decoded_width': resized.width,
          'decoded_height': resized.height,
          'original_rgba_bytes': originalBytes,
          'decoded_rgba_bytes': decodedBytes,
          'reduction_percent': (1 - decodedBytes / originalBytes) * 100,
          'scope':
              'synthetic 4000x3000 image displayed at 480x360 logical pixels, DPR 2',
        }),
      );
      original.dispose();
      resized.dispose();
      picture.dispose();
    });
  });

  testWidgets('small source images are never enlarged during decode', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final image = await decode(
        imageForDisplay(
          const AssetImage('assets/catalog/e4/pencil.jpg'),
          const Size(1200, 1200),
          2,
        ),
      );
      expect(image.width, 512);
      expect(image.height, 512);
      image.dispose();
    });
  });
}
