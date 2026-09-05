// ─────────────────────────────────────────────────────────────────────────────
// Service gọi API nhận diện — multipart POST, timeout, xử lý lỗi
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'app_config.dart';
import 'detection_model.dart';

/// Lỗi riêng cho quá trình nhận diện.
class InferenceException implements Exception {
  final String message;
  const InferenceException(this.message);

  @override
  String toString() => message;
}

/// Gửi ảnh multipart tới API và parse kết quả.
class InferenceService {
  const InferenceService();

  /// Gửi [imageFile] tới [inferenceUrl] và trả về [DetectionResult].
  ///
  /// Ném [InferenceException] với thông báo tiếng Việt cho mọi lỗi.
  Future<DetectionResult> predict(File imageFile) async {
    try {
      final uri = Uri.parse(inferenceUrl);
      final request = http.MultipartRequest('POST', uri)
        ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      final streamed = await request.send().timeout(
        const Duration(seconds: inferenceTimeoutSeconds),
      );

      final response = await http.Response.fromStream(streamed);

      if (response.statusCode != 200) {
        throw InferenceException(
          'Máy chủ trả về lỗi (mã ${response.statusCode}). '
          'Vui lòng thử lại sau.',
        );
      }

      final Map<String, dynamic> json;
      try {
        json = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        throw const InferenceException('Dữ liệu trả về không hợp lệ.');
      }

      try {
        return DetectionResult.fromJson(json);
      } on FormatException {
        throw const InferenceException('Dữ liệu trả về không hợp lệ.');
      }
    } on InferenceException {
      rethrow;
    } on TimeoutException {
      throw const InferenceException(
        'Hết thời gian chờ. Kiểm tra kết nối mạng và thử lại.',
      );
    } on SocketException {
      throw const InferenceException(
        'Không kết nối được máy nhận diện. '
        'Kiểm tra mạng WiFi và địa chỉ IP server.',
      );
    } catch (e) {
      throw InferenceException('Lỗi không xác định: $e');
    }
  }
}
