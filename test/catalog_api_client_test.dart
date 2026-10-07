import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:giao_dien/core/network/catalog_api_client.dart';

void main() {
  test(
    'mobile catalog client reads published response from configured API',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close();
      });
      server.listen((request) {
        if (request.uri.path == '/api/v1/catalog/packs') {
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({
              'packs': [
                {
                  'id': 'release:test-1',
                  'version': 'test-1',
                  'name_vi': 'Gói kiểm thử',
                  'description_vi': 'Fixture',
                  'word_count': 2,
                  'bytes_total': 42,
                  'sha256': 'abc',
                  'status': 'published',
                },
              ],
            }),
          );
          unawaited(request.response.close());
          return;
        }
        if (request.uri.path.endsWith('/manifest')) {
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({
              'id': 'release:test-1',
              'version': 'test-1',
              'name_vi': 'Gói kiểm thử',
              'description_vi': 'Fixture',
              'word_count': 2,
              'bytes_total': 42,
              'sha256': 'abc',
              'status': 'published',
              'word_ids': ['pencil', 'ruler'],
              'sources': [],
              'media': [],
            }),
          );
          unawaited(request.response.close());
          return;
        }
        if (request.uri.path.endsWith('/pencil')) {
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({
              'version': 'test-1',
              'word': {
                'id': 'pencil',
                'english': 'Pencil',
                'vietnamese': 'Bút chì',
                'topic': 'Đồ dùng học tập',
                'part_of_speech': 'noun',
                'example_english': 'Use a pencil.',
                'example_vietnamese': 'Dùng bút chì.',
                'source': 'fixture',
              },
            }),
          );
          unawaited(request.response.close());
          return;
        }
        final secondPage = request.uri.queryParameters['cursor'] == '1';
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'version': 'test-1',
            'count': 1,
            'total': 2,
            'next_cursor': secondPage ? null : '1',
            'words': [
              secondPage
                  ? {
                      'id': 'ruler',
                      'english': 'Ruler',
                      'vietnamese': 'Thước kẻ',
                      'topic': 'Đồ dùng học tập',
                      'part_of_speech': 'noun',
                      'example_english': 'Use a ruler.',
                      'example_vietnamese': 'Dùng thước kẻ.',
                      'source': 'fixture',
                      'source_url': 'https://example.test/ruler',
                      'source_license': 'CC BY 4.0',
                      'source_attribution': 'Fixture dictionary',
                      'reviewed_by': 'fixture-review',
                      'image_url': 'https://example.test/ruler.jpg',
                      'image_license': 'CC BY 4.0',
                      'image_attribution': 'Fixture photographer',
                    }
                  : {
                      'id': 'pencil',
                      'english': 'Pencil',
                      'vietnamese': 'Bút chì',
                      'topic': 'Đồ dùng học tập',
                      'part_of_speech': 'noun',
                      'example_english': 'Use a pencil.',
                      'example_vietnamese': 'Dùng bút chì.',
                      'source': 'fixture',
                      'source_url': 'https://example.test/pencil',
                      'source_license': 'CC BY 4.0',
                      'source_attribution': 'Fixture dictionary',
                      'reviewed_by': 'fixture-review',
                    },
            ],
          }),
        );
        unawaited(request.response.close());
      });

      final client = CatalogApiClient('http://127.0.0.1:${server.port}');
      addTearDown(client.close);
      final release = await client.fetchRelease(query: 'pencil');
      final words = release.words;

      expect(release.version, 'test-1');
      expect(words, hasLength(2));
      expect(words.first.english, 'Pencil');
      expect(words.last.english, 'Ruler');
      expect(words.first.source, 'fixture');
      expect(words.first.sourceUrl, 'https://example.test/pencil');
      expect(words.first.sourceAttribution, 'Fixture dictionary');
      expect(words.first.imageLicense, isNull);
      final packs = await client.fetchPacks();
      expect(packs.single.wordCount, 2);
      final pack = await client.fetchPackManifest('release:test-1');
      expect(pack.wordIds, ['pencil', 'ruler']);
      expect(client.fetchPackRelease(), throwsA(isA<FormatException>()));
      final detail = await client.fetchWord('pencil');
      expect(detail.vietnamese, 'Bút chì');
    },
  );
}
