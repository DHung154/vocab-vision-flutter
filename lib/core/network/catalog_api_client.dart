import 'dart:convert';
import 'dart:io';

import '../../catalog_data.dart';

/// Optional published-catalog client. The app has no hard-coded server URL:
/// pass `--dart-define=VOCAB_API_BASE_URL=https://...` for a configured
/// backend. Without it, the same Explore screen stays fully offline.
class CatalogApiClient {
  final String baseUrl;
  final HttpClient _client;

  CatalogApiClient(this.baseUrl, {HttpClient? client})
    : _client = client ?? HttpClient();

  Future<List<CatalogWord>> fetchWords({String query = ''}) async {
    final release = await fetchRelease(query: query);
    return release.words;
  }

  /// Downloads the currently published pack only after checking its manifest.
  /// The manifest is the mobile contract: a partial/empty words response is
  /// rejected so the previous SQLite release remains usable offline.
  Future<CatalogRelease> fetchPackRelease() async {
    final packs = await fetchPacks();
    if (packs.isEmpty) {
      throw const FormatException('Catalog API chưa có pack published');
    }
    final selected = packs.first;
    final manifest = await fetchPackManifest(selected.id);
    if (manifest.status != 'published' ||
        manifest.version != selected.version ||
        manifest.wordCount <= 0 ||
        manifest.wordCount != selected.wordCount) {
      throw const FormatException('Catalog pack manifest không khớp metadata');
    }
    final release = await fetchRelease();
    final ids = release.words.map((word) => word.id).toSet();
    if (release.version != manifest.version ||
        release.words.length != manifest.wordCount ||
        manifest.wordIds.any((id) => !ids.contains(id))) {
      throw const FormatException('Catalog pack tải xuống không đầy đủ');
    }
    final mediaUrls = manifest.media.map(_mediaUrl).whereType<String>().toSet();
    final missingMedia = release.words.where((word) {
      final imageUrl = word.imageUrl?.trim();
      if (imageUrl == null ||
          imageUrl.isEmpty ||
          imageUrl.startsWith('assets/')) {
        return false;
      }
      return !mediaUrls.contains(imageUrl);
    });
    if (missingMedia.isNotEmpty) {
      throw const FormatException('Catalog pack thiếu media trong manifest');
    }
    return release;
  }

  Future<CatalogRelease> fetchRelease({String query = ''}) async {
    final words = <CatalogWord>[];
    String version = 'unknown';
    String? cursor;
    do {
      final page = await _fetchPage(query: query, cursor: cursor);
      version = page.version;
      words.addAll(page.words);
      final next = page.nextCursor;
      if (next == null || next == cursor || words.length >= 10000) break;
      cursor = next;
    } while (true);
    return CatalogRelease(version: version, words: words);
  }

  Future<CatalogWord> fetchWord(String wordId) async {
    final uri = Uri.parse(
      baseUrl,
    ).resolve('/api/v1/catalog/words/${Uri.encodeComponent(wordId)}');
    final request = await _client
        .getUrl(uri)
        .timeout(const Duration(seconds: 8));
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    final httpResponse = await request.close().timeout(
      const Duration(seconds: 8),
    );
    final body = await httpResponse.transform(utf8.decoder).join();
    if (httpResponse.statusCode != HttpStatus.ok) {
      throw HttpException('Catalog API ${httpResponse.statusCode}', uri: uri);
    }
    final decoded = jsonDecode(body);
    if (decoded is! Map || decoded['word'] is! Map) {
      throw const FormatException('Catalog response thiếu word');
    }
    return _catalogWordFromJson(
      Map<String, dynamic>.from(decoded['word'] as Map),
    );
  }

  Future<List<CatalogPack>> fetchPacks() async {
    final uri = Uri.parse(baseUrl).resolve('/api/v1/catalog/packs');
    final request = await _client
        .getUrl(uri)
        .timeout(const Duration(seconds: 8));
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    final response = await request.close().timeout(const Duration(seconds: 8));
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('Catalog API ${response.statusCode}', uri: uri);
    }
    final decoded = jsonDecode(body);
    if (decoded is! Map || decoded['packs'] is! List) {
      throw const FormatException('Catalog response thiếu packs');
    }
    return (decoded['packs'] as List)
        .whereType<Map>()
        .map((item) => CatalogPack.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  Future<CatalogPackManifest> fetchPackManifest(String packId) async {
    final uri = Uri.parse(
      baseUrl,
    ).resolve('/api/v1/catalog/packs/${Uri.encodeComponent(packId)}/manifest');
    final request = await _client
        .getUrl(uri)
        .timeout(const Duration(seconds: 8));
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    final response = await request.close().timeout(const Duration(seconds: 8));
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('Catalog API ${response.statusCode}', uri: uri);
    }
    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      throw const FormatException('Catalog pack manifest không hợp lệ');
    }
    return CatalogPackManifest.fromJson(Map<String, dynamic>.from(decoded));
  }

  Future<_CatalogPage> _fetchPage({
    required String query,
    String? cursor,
  }) async {
    final queryParameters = <String, String>{
      if (query.trim().isNotEmpty) 'q': query.trim(),
      'limit': '1000',
    };
    if (cursor != null) queryParameters['cursor'] = cursor;
    final uri = Uri.parse(baseUrl)
        .resolve('/api/v1/catalog/words')
        .replace(queryParameters: queryParameters);
    final request = await _client
        .getUrl(uri)
        .timeout(const Duration(seconds: 8));
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    final response = await request.close().timeout(const Duration(seconds: 8));
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('Catalog API ${response.statusCode}', uri: uri);
    }
    final decoded = jsonDecode(body);
    if (decoded is! Map || decoded['words'] is! List) {
      throw const FormatException('Catalog response không hợp lệ');
    }
    final nextCursor = decoded['next_cursor'];
    return _CatalogPage(
      version: decoded['version'] is String
          ? decoded['version'] as String
          : 'unknown',
      words: (decoded['words'] as List)
          .map(
            (item) =>
                _catalogWordFromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(growable: false),
      nextCursor: nextCursor is String && nextCursor.isNotEmpty
          ? nextCursor
          : null,
    );
  }

  void close() => _client.close(force: true);
}

class _CatalogPage {
  final String version;
  final List<CatalogWord> words;
  final String? nextCursor;

  const _CatalogPage({
    required this.version,
    required this.words,
    required this.nextCursor,
  });
}

class CatalogRelease {
  final String version;
  final List<CatalogWord> words;

  const CatalogRelease({required this.version, required this.words});
}

class CatalogPack {
  final String id;
  final String version;
  final String nameVi;
  final String descriptionVi;
  final int wordCount;
  final int bytesTotal;
  final String sha256;
  final String status;

  const CatalogPack({
    required this.id,
    required this.version,
    required this.nameVi,
    required this.descriptionVi,
    required this.wordCount,
    required this.bytesTotal,
    required this.sha256,
    required this.status,
  });

  factory CatalogPack.fromJson(Map<String, dynamic> json) => CatalogPack(
    id: json['id'] as String? ?? '',
    version: json['version'] as String? ?? '',
    nameVi: json['name_vi'] as String? ?? '',
    descriptionVi: json['description_vi'] as String? ?? '',
    wordCount: _intValue(json['word_count']),
    bytesTotal: _intValue(json['bytes_total']),
    sha256: json['sha256'] as String? ?? '',
    status: json['status'] as String? ?? 'unknown',
  );
}

class CatalogPackManifest extends CatalogPack {
  final List<String> wordIds;
  final List<Map<String, dynamic>> sources;
  final List<Map<String, dynamic>> media;

  const CatalogPackManifest({
    required super.id,
    required super.version,
    required super.nameVi,
    required super.descriptionVi,
    required super.wordCount,
    required super.bytesTotal,
    required super.sha256,
    required super.status,
    required this.wordIds,
    required this.sources,
    required this.media,
  });

  factory CatalogPackManifest.fromJson(Map<String, dynamic> json) =>
      CatalogPackManifest(
        id: json['id'] as String? ?? '',
        version: json['version'] as String? ?? '',
        nameVi: json['name_vi'] as String? ?? '',
        descriptionVi: json['description_vi'] as String? ?? '',
        wordCount: _intValue(json['word_count']),
        bytesTotal: _intValue(json['bytes_total']),
        sha256: json['sha256'] as String? ?? '',
        status: json['status'] as String? ?? 'unknown',
        wordIds: (json['word_ids'] as List? ?? const [])
            .whereType<String>()
            .toList(growable: false),
        sources: _mapList(json['sources']),
        media: _mapList(json['media']),
      );
}

int _intValue(Object? value) =>
    value is int ? value : int.tryParse('$value') ?? 0;

List<Map<String, dynamic>> _mapList(Object? value) => value is List
    ? value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false)
    : const <Map<String, dynamic>>[];

String? _mediaUrl(Map<String, dynamic> media) {
  final value = media['url'] ?? media['image_url'];
  return value is String && value.trim().isNotEmpty ? value.trim() : null;
}

CatalogWord _catalogWordFromJson(Map<String, dynamic> json) => CatalogWord(
  id: json['id'] as String,
  english: json['english'] as String,
  vietnamese: json['vietnamese'] as String,
  topic: json['topic'] as String,
  partOfSpeech: json['part_of_speech'] as String,
  exampleEnglish: json['example_english'] as String,
  exampleVietnamese: json['example_vietnamese'] as String,
  source: json['source'] as String? ?? 'remote catalog',
  sourceUrl: json['source_url'] as String?,
  sourceLicense: json['source_license'] as String?,
  sourceAttribution: json['source_attribution'] as String?,
  reviewedBy: json['reviewed_by'] as String?,
  reviewerType: json['reviewer_type'] as String?,
  reviewerId: json['reviewer_id'] as String?,
  reviewedAt: json['reviewed_at'] as String?,
  imageUrl: json['image_url'] as String?,
  imageLicense: json['image_license'] as String?,
  imageAttribution: json['image_attribution'] as String?,
);
