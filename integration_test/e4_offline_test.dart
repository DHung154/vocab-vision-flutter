import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:giao_dien/inference_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('E4 ONNX runs locally from a bundled image', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

    final source = await rootBundle.load('assets/catalog/e4/pencil.jpg');
    final directory = await Directory.systemTemp.createTemp('vocab-e4-');
    final image = File('${directory.path}${Platform.pathSeparator}pencil.jpg');
    await image.writeAsBytes(
      source.buffer.asUint8List(source.offsetInBytes, source.lengthInBytes),
      flush: true,
    );

    try {
      final result = await const InferenceService().predict(
        image,
        confidence: 0.10,
      );
      expect(result.modelId, 'e4');
      expect(result.modelLabel, contains('E4'));
      expect(result.imageWidth, greaterThan(0));
      expect(result.imageHeight, greaterThan(0));
      expect(result.latencyMs, greaterThan(0));
      expect(
        result.detections,
        isNotEmpty,
        reason: 'Bundled pencil fixture should produce at least one E4 box.',
      );
      for (final detection in result.detections) {
        expect(detection.classId, inInclusiveRange(0, 14));
        expect(detection.confidence, inInclusiveRange(0.10, 1.0));
        expect(detection.box, hasLength(4));
        expect(detection.box[2], greaterThanOrEqualTo(detection.box[0]));
        expect(detection.box[3], greaterThanOrEqualTo(detection.box[1]));
        expect(detection.box[0], greaterThanOrEqualTo(0));
        expect(detection.box[1], greaterThanOrEqualTo(0));
        expect(detection.box[2], lessThanOrEqualTo(result.imageWidth));
        expect(detection.box[3], lessThanOrEqualTo(result.imageHeight));
      }
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
