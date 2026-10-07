import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../../catalog_data.dart';

typedef CatalogMediaProgress = void Function(int completed, int total);

class CatalogDownloadCancelled implements Exception {
  const CatalogDownloadCancelled();

  @override
  String toString() => 'Catalog download cancelled';
}

/// Downloads reviewed remote images before a catalog release is swapped into
/// SQLite. A failed image download aborts the release, so the last usable
/// offline catalog remains the active one.
class CatalogMediaCache {
  static const _maxImageBytes = 8 * 1024 * 1024;

  final HttpClient _client;
  final bool _ownsClient;
  final Directory? _configuredRoot;
  Directory? _root;

  CatalogMediaCache({HttpClient? client, Directory? root})
    : _client = client ?? HttpClient(),
      _ownsClient = client == null,
      _configuredRoot = root;

  Future<List<CatalogWord>> cacheRelease({
    required String version,
    required List<CatalogWord> words,
    CatalogMediaProgress? onProgress,
    bool Function()? isCancelled,
  }) async {
    final hasRemote = words.any((word) {
      final url = word.imageUrl?.trim();
      return url != null && url.isNotEmpty && !url.startsWith('assets/');
    });
    final remoteCount = words.where((word) {
      final url = word.imageUrl?.trim();
      return url != null && url.isNotEmpty && !url.startsWith('assets/');
    }).length;
    if (!hasRemote) {
      onProgress?.call(1, 1);
      return words;
    }

    final root = await _mediaRoot();
    final releaseRoot = Directory(
      path.join(root.path, 'release-${_safeSegment(version)}'),
    );
    await releaseRoot.create(recursive: true);
    final result = List<CatalogWord>.of(words);
    var completed = 0;
    onProgress?.call(0, remoteCount);
    for (var index = 0; index < words.length; index++) {
      final word = words[index];
      final imageUrl = word.imageUrl?.trim();
      if (imageUrl == null ||
          imageUrl.isEmpty ||
          imageUrl.startsWith('assets/')) {
        continue;
      }
      if (isCancelled?.call() == true) {
        throw const CatalogDownloadCancelled();
      }
      final url = imageUrl;
      final uri = Uri.tryParse(url);
      if (uri == null || !{'http', 'https'}.contains(uri.scheme)) {
        throw FormatException('Media URL không hỗ trợ: $url');
      }
      final fileName = '${Uri.encodeComponent(word.id)}.img';
      final finalPath = path.join(releaseRoot.path, fileName);
      final partial = File('$finalPath.part');
      try {
        final request = await _client
            .getUrl(uri)
            .timeout(const Duration(seconds: 8));
        final response = await request.close().timeout(
          const Duration(seconds: 8),
        );
        if (response.statusCode != HttpStatus.ok) {
          throw HttpException(
            'Không tải được media (${response.statusCode})',
            uri: uri,
          );
        }
        final mime = response.headers.contentType?.mimeType;
        if (mime != null && mime.isNotEmpty && !mime.startsWith('image/')) {
          throw FormatException('Media không phải ảnh: $url');
        }
        final bytes = <int>[];
        await for (final chunk in response) {
          if (isCancelled?.call() == true) {
            throw const CatalogDownloadCancelled();
          }
          if (bytes.length + chunk.length > _maxImageBytes) {
            throw FormatException('Media vượt quá 8 MB: $url');
          }
          bytes.addAll(chunk);
        }
        if (bytes.isEmpty) {
          throw FormatException('Media rỗng: $url');
        }
        await partial.writeAsBytes(bytes, flush: true);
        final existing = File(finalPath);
        if (await existing.exists()) await existing.delete();
        await partial.rename(finalPath);
        result[index] = word.copyWith(localImagePath: finalPath);
        completed++;
        onProgress?.call(completed, remoteCount);
      } catch (_) {
        if (await partial.exists()) await partial.delete();
        rethrow;
      }
    }
    return result;
  }

  Future<Directory> _mediaRoot() async {
    final existing = _root;
    if (existing != null) return existing;
    final root =
        _configuredRoot ??
        Directory(path.join(await getDatabasesPath(), 'vocab_catalog_media'));
    await root.create(recursive: true);
    return _root = root;
  }

  String _safeSegment(String value) {
    final safe = value.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return safe.isEmpty ? 'unknown' : safe;
  }

  void close() {
    if (_ownsClient) _client.close(force: true);
  }
}
