import 'package:flutter/services.dart';

/// Small Android Keystore bridge for opaque auth-session JSON.
///
/// Progress and catalog data remain in SQLite. Only access/refresh tokens are
/// routed through the native encrypted store on Android; desktop/widget
/// targets keep the existing local-store fallback so tests remain deterministic.
class SecureTokenStore {
  static const _channel = MethodChannel('vocab_vision/secure_storage');

  Future<String?> read(String key) async {
    final value = await _channel.invokeMethod<String>('read', {'key': key});
    return value;
  }

  Future<void> write(String key, String value) async {
    await _channel.invokeMethod<void>('write', {'key': key, 'value': value});
  }

  Future<void> delete(String key) async {
    await _channel.invokeMethod<void>('delete', {'key': key});
  }
}
