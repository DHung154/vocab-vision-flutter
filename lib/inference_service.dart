import 'dart:io';

import 'package:flutter/services.dart';

import 'app_config.dart';
import 'detection_model.dart';
import 'research_results_data.dart';

class InferenceException implements Exception {
  final String message;
  const InferenceException(this.message);

  @override
  String toString() => message;
}

class InferenceService {
  static const _channel = MethodChannel('vocab_vision/e4');

  const InferenceService();

  Future<DetectionResult> predict(
    File imageFile, {
    String modelId = defaultDemoModelId,
    double confidence = 0.25,
  }) async {
    if (modelId != defaultDemoModelId) {
      throw const InferenceException('Bản offline chỉ chứa checkpoint E4.');
    }
    if (confidence <= 0 || confidence > 1) {
      throw const InferenceException(
        'Ngưỡng confidence phải nằm trong (0, 1].',
      );
    }
    if (!await imageFile.exists()) {
      throw const InferenceException('Không tìm thấy ảnh đã chọn.');
    }

    try {
      // Do not request a typed Map here: StandardMessageCodec may expose the
      // nested Kotlin maps as Map<Object?, Object?>. DetectionResult performs
      // the safe key validation/normalization at the boundary.
      final response = await _channel.invokeMethod<Object?>('predict', {
        'imagePath': imageFile.path,
        'confidence': confidence,
      });
      if (response == null) {
        throw const InferenceException('Android không trả kết quả E4.');
      }
      return DetectionResult.fromJson(response);
    } on InferenceException {
      rethrow;
    } on PlatformException catch (error) {
      throw InferenceException(
        error.message?.trim().isNotEmpty == true
            ? error.message!
            : 'Không thể chạy E4 offline (${error.code}).',
      );
    } catch (error) {
      throw InferenceException('Không thể chạy E4 offline: $error');
    }
  }

  Future<Map<String, dynamic>> fetchResearchResults() async =>
      researchResultsData;
}
